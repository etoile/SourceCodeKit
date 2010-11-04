#import "SCKClangSourceFile.h"
#import "SourceCodeKit.h"
#import <Cocoa/Cocoa.h>
#import <EtoileFoundation/EtoileFoundation.h>
#include <time.h>

//#define NSLog(...)

/**
 * Converts a clang source range into an NSRange within its enclosing file.
 */
NSRange NSRangeFromCXSourceRange(CXSourceRange sr)
{
	unsigned start, end;
	CXSourceLocation s = clang_getRangeStart(sr);
	CXSourceLocation e = clang_getRangeEnd(sr);
	clang_getInstantiationLocation(s, 0, 0, 0, &start); 
	clang_getInstantiationLocation(e, 0, 0, 0, &end); 
	if (end < start)
	{
		NSRange r = {end, start-end};
		return r;
	}
	NSRange r = {start, end - start};
	return r;
}

static void freestring(CXString *str)
{
	clang_disposeString(*str);
}
#define SCOPED_STR(name, value)\
	__attribute__((unused))\
	__attribute__((cleanup(freestring))) CXString name ## str = value;\
	const char *name = clang_getCString(name ## str);


@interface SCKSourceLocation : NSObject
{
	@public
	NSString *file;
	NSUInteger offset;
}
@end
@implementation SCKSourceLocation
- (id)initWithClangSourceLocation: (CXSourceLocation)l
{
	SUPERINIT;
	CXFile f;
	clang_getInstantiationLocation(l, &f, 0, 0, &offset); 
	SCOPED_STR(fileName, clang_getFileName(f));
	file = [[NSString alloc] initWithUTF8String: fileName];
	return self;
}
- (NSString*)description
{
	return [NSString stringWithFormat: @"%@:%d", file, (int)offset];
}
- (void)dealloc
{
	[file release];
	[super dealloc];
}
@end


@interface SCKClangIndex : NSObject
@property (readonly) CXIndex clangIndex;
//FIXME: We should have different default arguments for C, C++ and ObjC.
@property (retain, nonatomic) NSMutableArray *defaultArguments;
@end

@implementation SCKClangIndex
- (id)init
{
	SUPERINIT;
	clangIndex = clang_createIndex(1, 1);
	// Options required to compile GNUstep apps
	// FIXME: These should be read in from a plist or something equally
	// (approximately) sensible.
	defaultArguments = [A(
		@"-DGNUSTEP",
		@"-DGNUSTEP_BASE_LIBRARY=1",
		@"-DGNU_GUI_LIBRARY=1",
		@"-DGNU_RUNTIME=1",
		@"-D_NATIVE_OBJC_EXCEPTIONS",
		@"-DGSWARN",
		@"-DGSDIAGNOSE",
		@"-fno-strict-aliasing",
		@"-fobjc-nonfragile-abi",
		@"-fexceptions",
		@"-Wall",
		@"-fgnu-runtime",
		@"-fblocks",
		@"-fconstant-string-class=NSConstantString") mutableCopy];
	return self;
}
- (void)dealloc
{
	clang_disposeIndex(clangIndex);
	[defaultArguments release];
	[super dealloc];
}
@end
@interface SCKClangSourceFile ()
- (void)highlightRange: (CXSourceRange)r syntax: (BOOL)highightSyntax;
@end

@implementation SCKClangSourceFile

static enum CXChildVisitResult findClass(CXCursor cursor, CXCursor parent, CXClientData client_data)
{
	if (CXCursor_ObjCClassRef == cursor.kind)
	{
		NSString **strPtr = (NSString**)client_data;
		SCOPED_STR(name, clang_getCursorSpelling(cursor));
		*strPtr = [NSString stringWithUTF8String: name];
		return CXChildVisit_Break;
	}
	return CXChildVisit_Continue;
}

static NSString *classNameFromCategory(CXCursor category)
{
	__block NSString *className = nil;
	clang_visitChildrenWithBlock(category, 
		^ enum CXChildVisitResult (CXCursor cursor, CXCursor parent)
		{
			if (CXCursor_ObjCClassRef == cursor.kind)
			{
				SCOPED_STR(name, clang_getCursorSpelling(cursor));
				className = [NSString stringWithUTF8String: name];
				return CXChildVisit_Break;
			}
			return CXChildVisit_Continue;
		} );
	return className;
}

- (void)setLocation: (SCKSourceLocation*)aLocation
          forMethod: (NSString*)methodName
            inClass: (NSString*)className
           category: (NSString*)categoryName
       isDefinition: (BOOL)isDefinition
{
	SCKSourceCollection *collection = self.collection;
	SCKClass *cls = [collection.classes objectForKey: className];
	if (nil == cls)
	{
		cls = [SCKClass new];
		cls.name = className;
		[collection.classes setObject: cls forKey: className];
		[cls release];
	}
	NSMutableDictionary *methods = cls.methods;
	if (nil != categoryName)
	{
		SCKCategory *cat = [cls.categories objectForKey: categoryName];
		if (nil == cat)
		{
			cat = [SCKCategory new];
			cat.name = categoryName;
			cat.parent = cls;
			[cls.categories setObject: cat forKey: categoryName];
			[cat release];
		}
		methods = cat.methods;
	}
	SCKMethod *m = [methods objectForKey: methodName];
	if (isDefinition)
	{
		m.definition = aLocation;
	}
	else
	{
		m.declaration = aLocation;
	}
}

- (void)rebuildIndex
{
	clang_visitChildrenWithBlock(clang_getTranslationUnitCursor(translationUnit), 
		^ enum CXChildVisitResult (CXCursor cursor, CXCursor parent)
		{
			switch(cursor.kind)
			{
				default: break;
				case CXCursor_ObjCInstanceMethodDecl:
				{
					if (CXCursor_ObjCImplementationDecl == parent.kind)
					{
						SCOPED_STR(methodName, clang_getCursorSpelling(cursor));
						SCOPED_STR(className, clang_getCursorSpelling(parent));
						//clang_visitChildren((parent), findClass, NULL);
						SCKSourceLocation *l = [[SCKSourceLocation alloc] 
							initWithClangSourceLocation: clang_getCursorLocation(cursor)];
						[self setLocation: l
						        forMethod: [NSString stringWithUTF8String: methodName]
						          inClass: [NSString stringWithUTF8String: className]
						         category: nil
						     isDefinition: clang_isCursorDefinition(cursor)];
						[l release];
					}
					else if (CXCursor_ObjCCategoryImplDecl == parent.kind)
					{
						SCOPED_STR(methodName, clang_getCursorSpelling(cursor));
						SCOPED_STR(categoryName, clang_getCursorSpelling(parent));
						NSString *className = classNameFromCategory(parent);
						SCKSourceLocation *l = [[SCKSourceLocation alloc] initWithClangSourceLocation: clang_getCursorLocation(cursor)];
						[self setLocation: l
						        forMethod: [NSString stringWithUTF8String: methodName]
						          inClass: className
						         category: [NSString stringWithUTF8String: categoryName]
						     isDefinition: clang_isCursorDefinition(cursor)];
						[l release];
					}
				}
			}
			if (0) //(cursor.kind == CXCursor_ObjCInstanceMethodDecl)
			{
			NSLog(@"Found definition of %s %s in %s %s\n", 
					clang_getCString(clang_getCursorKindSpelling(cursor.kind)), clang_getCString(clang_getCursorUSR(cursor)),
					clang_getCString(clang_getCursorKindSpelling(parent.kind)), clang_getCString(clang_getCursorUSR(parent)));
			}
			return CXChildVisit_Recurse;
		});
}
- (id)initUsingIndex: (SCKIndex*)anIndex
{
	idx = (SCKClangIndex*)anIndex;
	NSAssert([idx isKindOfClass: [SCKClangIndex class]], 
			@"Initializing SCKClangSourceFile with incorrect kind of index");
	args = [idx.defaultArguments mutableCopy];
	return self;
}
- (void)addIncludePath: (NSString*)includePath
{
	[args addObject: [NSString stringWithFormat: @"-I%@", includePath]];
	// After we've added an include path, we may change how the file is parsed,
	// so parse it again, if required
	if (NULL != translationUnit)
	{
		clang_disposeTranslationUnit(translationUnit);
		[self reparse];
	}
}

- (void)dealloc
{
	if (NULL != translationUnit)
	{
		clang_disposeTranslationUnit(translationUnit);
	}
	[super dealloc];
}

- (void)reparse
{
	const char *fn = [fileName UTF8String];
	struct CXUnsavedFile unsaved = { 
		fn, [[source string] UTF8String], [source length] };
	//NSLog(@"File is %d chars long", [source length]);
	file = NULL;
	if (NULL == translationUnit)
	{
		//NSLog(@"Creating translation unit from file");
		unsigned argc = [args count];
		const char *argv[argc];
		int i=0;
		for (NSString *arg in args)
		{
			argv[i++] = [arg UTF8String];
		}
		translationUnit = 
			clang_createTranslationUnitFromSourceFile(idx.clangIndex, fn, argc, argv, 1, &unsaved);
			//clang_parseTranslationUnit(index, fn, argv, argc, &unsaved, 1, CXTranslationUnit_PrecompiledPreamble | CXTranslationUnit_CacheCompletionResults | CXTranslationUnit_DetailedPreprocessingRecord);
		file = clang_getFile(translationUnit, fn);
	}
	else
	{
		clock_t c1 = clock();
		//NSLog(@"Reparsing translation unit");
		if (0 != clang_reparseTranslationUnit(translationUnit, 1, &unsaved, clang_defaultReparseOptions(translationUnit)))
		{
			clang_disposeTranslationUnit(translationUnit);
			translationUnit = 0;
		}
		else
		{
			file = clang_getFile(translationUnit, fn);
		}
		clock_t c2 = clock();
		//NSLog(@"Reparsing took %f seconds.  .",
			//((double)c2 - (double)c1) / (double)CLOCKS_PER_SEC);
	}
	[self rebuildIndex];
}
- (void)lexicalHighlightFile
{
	CXSourceLocation start = clang_getLocation(translationUnit, file, 1, 1);
	CXSourceLocation end = clang_getLocationForOffset(translationUnit, file, [source length]);
	[self highlightRange: clang_getRange(start, end) syntax: NO];
}

- (void)highlightRange: (CXSourceRange)r syntax: (BOOL)highightSyntax;
{
	NSString *TokenTypes[] = {SCKTextTokenTypePunctuation, SCKTextTokenTypeKeyword,
		SCKTextTokenTypeIdentifier, SCKTextTokenTypeLiteral,
		SCKTextTokenTypeComment};
	if (clang_equalLocations(clang_getRangeStart(r), clang_getRangeEnd(r)))
	{
		NSLog(@"Range has no length!");
		return;
	}
	CXToken *tokens;
	unsigned tokenCount;
	clang_tokenize(translationUnit, r , &tokens, &tokenCount);
	//NSLog(@"Found %d tokens", tokenCount);
	if (tokenCount > 0)
	{
		CXCursor *cursors = NULL;
		if (highightSyntax)
		{
			cursors = calloc(sizeof(CXCursor), tokenCount);
			clang_annotateTokens(translationUnit, tokens, tokenCount, cursors);
		}
		for (unsigned i=0 ; i<tokenCount ; i++)
		{
			CXSourceRange sr = clang_getTokenExtent(translationUnit, tokens[i]);
			NSRange range = NSRangeFromCXSourceRange(sr);
			if (range.location > 0)
			{
				if ([[source string] characterAtIndex: range.location - 1] == '@')
				{
					range.location--;
					range.length++;
				}
			}
			if (highightSyntax)
			{
				id type;
				switch (cursors[i].kind)
				{
					case CXCursor_FirstRef... CXCursor_LastRef:
						type = SCKTextTypeReference;
						break;
					case CXCursor_MacroDefinition:
						type = SCKTextTypeMacroDefinition;
						break;
					case CXCursor_MacroInstantiation:
						type = SCKTextTypeMacroInstantiation;
						break;
					case CXCursor_FirstDecl...CXCursor_LastDecl:
						type = SCKTextTypeDeclaration;
						break;
					case CXCursor_ObjCMessageExpr:
						type = SCKTextTypeMessageSend;
						break;
					case CXCursor_DeclRefExpr:
						type = SCKTextTypeDeclRef;
						break;
					case CXCursor_PreprocessingDirective:
						type = SCKTextTypePreprocessorDirective;
						break;
					default:
						type = nil;
				}
				if (nil != type)
				{
					[source addAttribute: kSCKTextSemanticType
								   value: type
								   range: range];
				}
			}
			[source addAttribute: kSCKTextTokenType
			               value: TokenTypes[clang_getTokenKind(tokens[i])]
			               range: range];
		}
		clang_disposeTokens(translationUnit, tokens, tokenCount);
		free(cursors);
	}
}
- (void)syntaxHighlightRange: (NSRange)r
{
	CXSourceLocation start = clang_getLocationForOffset(translationUnit, file, r.location);
	CXSourceLocation end = clang_getLocationForOffset(translationUnit, file, r.location + r.length);
	clock_t c1 = clock();
	[self highlightRange: clang_getRange(start, end) syntax: YES];
	clock_t c2 = clock();
	//NSLog(@"Highlighting took %f seconds.  .",
		//((double)c2 - (double)c1) / (double)CLOCKS_PER_SEC);
}
- (void)syntaxHighlightFile
{
	[self syntaxHighlightRange: NSMakeRange(0, [source length])];
}
- (void)collectDiagnostics
{
	//NSLog(@"Collecting diagnostics");
	unsigned diagnosticCount = clang_getNumDiagnostics(translationUnit);
	unsigned opts = clang_defaultDiagnosticDisplayOptions();
	//NSLog(@"%d diagnostics found", diagnosticCount);
	for (unsigned i=0 ; i<diagnosticCount ; i++)
	{
		CXDiagnostic d = clang_getDiagnostic(translationUnit, i);
		unsigned s = clang_getDiagnosticSeverity(d);
		if (s > 0)
		{
			CXString str = clang_getDiagnosticSpelling(d);
			CXSourceLocation loc = clang_getDiagnosticLocation(d);
			unsigned rangeCount = clang_getDiagnosticNumRanges(d);
			//NSLog(@"%d ranges for diagnostic", rangeCount);
			for (unsigned j=0 ; j<rangeCount ; j++)
			{
				NSRange r = NSRangeFromCXSourceRange(clang_getDiagnosticRange(d, j));
				NSDictionary *attr = D([NSNumber numberWithInt: (int)s], kSCKDiagnosticSeverity,
					 [NSString stringWithUTF8String: clang_getCString(str)], kSCKDiagnosticText);
				//NSLog(@"Added diagnostic %@ for range: %@", attr, NSStringFromRange(r));
				[source addAttribute: kSCKDiagnostic
				               value: attr
				               range: r];
			}
			clang_disposeString(str);
		}
	}
}
@end

