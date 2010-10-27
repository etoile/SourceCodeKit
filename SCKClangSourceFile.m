#import "SCKClangSourceFile.h"
#import <Cocoa/Cocoa.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import "SCKTextTypes.h"
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
@end
@interface SCKClangSourceFile ()
- (void)highlightRange: (CXSourceRange)r syntax: (BOOL)highightSyntax;
@end

@implementation SCKClangSourceFile
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

