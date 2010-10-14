#import "IDESyntaxHighlighter.h"
#import <Cocoa/Cocoa.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import "IDETextTypes.h"

/**
 * Converts a clang source range into an NSRange within its enclosing file.
 */
// FIXME: This probably belongs somewhere else.
NSRange NSRangeFromCXSourceRange(CXSourceRange sr)
{
	unsigned start, end;
	CXSourceLocation s = clang_getRangeStart(sr);
	CXSourceLocation e = clang_getRangeEnd(sr);
	clang_getInstantiationLocation(s, 0, 0, 0, &start); 
	clang_getInstantiationLocation(e, 0, 0, 0, &end); 
	NSRange r = {start, end - start};
	return r;
}


@implementation IDESyntaxHighlighter
- (id)init
{
	SUPERINIT;
	index = clang_createIndex(1, 1);
	// Options required to compile GNUstep apps
	// FIXME: These should be read in from a plist or something equally
	// (approximately) sensible.
	args = [A(
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
		@"-fconstant-string-class=NSConstantString") mutableCopy];
	return self;
}
- (void)addIncludePath: (NSString*)includePath
{
	[args addObject: [NSString stringWithFormat: @"-I%@", includePath]];
}

- (void)dealloc
{
	if (NULL != translationUnit)
	{
		clang_disposeTranslationUnit(translationUnit);
	}
	clang_disposeIndex(index);
	[super dealloc];
}

- (void)reparse
{
	const char *fn = [fileName UTF8String];
	struct CXUnsavedFile unsaved = { 
		fn, [[source string] UTF8String], [source length] };
	if (NULL == translationUnit)
	{
		unsigned argc = [args count];
		const char *argv[argc];
		int i=0;
		for (NSString *arg in args)
		{
			argv[i++] = [arg UTF8String];
		}
		translationUnit = 
			//clang_createTranslationUnitFromSourceFile(index, fn, argc, argv, 1, &unsaved);
			clang_createTranslationUnitFromSourceFile(index, fn, argc, argv, 1, &unsaved);
		file = clang_getFile(translationUnit, fn);
		[self syntaxHighlightFile];
		[self convertSemanticToPresentationMarkup];
	}
	else
	{
		clang_reparseTranslationUnit(translationUnit, 1, &unsaved, 0);
	}
}
- (void)lexicalHighlightFile
{
	CXSourceLocation start = clang_getLocation(translationUnit, file, 0, 0);
	CXSourceLocation end = clang_getLocation(translationUnit, file, -1, -1);
	[self highlightRange: clang_getRange(start, end) syntax: NO];
}

- (void)highlightRange: (CXSourceRange)r syntax: (BOOL)highightSyntax;
{
	NSString *TokenTypes[] = {IDETextTokenTypePunctuation, IDETextTokenTypeKeyword,
		IDETextTokenTypeIdentifier, IDETextTokenTypeLiteral,
		IDETextTokenTypeComment};
	if (clang_equalLocations(clang_getRangeStart(r), clang_getRangeEnd(r)))
	{
		return;
	}
	CXToken *tokens;
	unsigned tokenCount;
	clang_tokenize(translationUnit, r , &tokens, &tokenCount);
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
						type = IDETextTypeReference;
						break;
					case CXCursor_MacroDefinition:
						type = IDETextTypeMacroDefinition;
						break;
					case CXCursor_MacroInstantiation:
						type = IDETextTypeMacroInstantiation;
						break;
					case CXCursor_FirstDecl...CXCursor_LastDecl:
						type = IDETextTypeDeclaration;
						break;
					case CXCursor_ObjCMessageExpr:
						type = IDETextTypeMessageSend;
						break;
					case CXCursor_DeclRefExpr:
						type = IDETextTypeDeclRef;
						break;
					case CXCursor_PreprocessingDirective:
						type = IDETextTypePreprocessorDirective;
						break;
					default:
						type = nil;
				}
				if (nil != type)
				{
					[source addAttribute: kIDETextSemanticType
								   value: type
								   range: range];
				}
			}
			[source addAttribute: kIDETextTokenType
			               value: TokenTypes[clang_getTokenKind(tokens[i])]
			               range: range];
		}
		clang_disposeTokens(translationUnit, tokens, tokenCount);
		free(cursors);
	}
}
- (void)convertSemanticToPresentationMarkup
{
	NSUInteger end = [source length];
	NSUInteger i = 0;
	NSRange r;
	NSDictionary *noAttributes = [NSDictionary dictionary];
	NSDictionary *comment = D([NSColor grayColor], NSForegroundColorAttributeName);
	NSDictionary *keyword = D([NSColor redColor], NSForegroundColorAttributeName);
	NSDictionary *literal = D([NSColor redColor], NSForegroundColorAttributeName);
	NSDictionary *tokenAttributes = D(
			comment, IDETextTokenTypeComment,
			noAttributes, IDETextTokenTypePunctuation,
			keyword, IDETextTokenTypeKeyword,
			literal, IDETextTokenTypeLiteral);

	NSDictionary *semanticAttributes = D(
			D([NSColor blueColor], NSForegroundColorAttributeName), IDETextTypeDeclRef,
			D([NSColor brownColor], NSForegroundColorAttributeName), IDETextTypeMessageSend,
			//D([NSColor greenColor], NSForegroundColorAttributeName), IDETextTypeDeclaration,
			D([NSColor magentaColor], NSForegroundColorAttributeName), IDETextTypeMacroInstantiation,
			D([NSColor magentaColor], NSForegroundColorAttributeName), IDETextTypeMacroDefinition,
			D([NSColor orangeColor], NSForegroundColorAttributeName), IDETextTypePreprocessorDirective,
			D([NSColor purpleColor], NSForegroundColorAttributeName), IDETextTypeReference);

	do
	{
		NSDictionary *attrs = [source attributesAtIndex: i
		                          longestEffectiveRange: &r
		                                        inRange: NSMakeRange(i, end-i)];
		NSString *token = [attrs objectForKey: kIDETextTokenType];
		NSString *semantic = [attrs objectForKey: kIDETextSemanticType];
		if (semantic == IDETextTypePreprocessorDirective)
		{
			attrs = [semanticAttributes objectForKey: semantic];
		}
		else if (token == nil || token != IDETextTokenTypeIdentifier)
		{
			attrs = [tokenAttributes objectForKey: token];
		}
		else 
		{
			NSString *semantic = [attrs objectForKey: kIDETextSemanticType];
			attrs = [semanticAttributes objectForKey: semantic];
			//NSLog(@"Applying semantic attributes: %@", semantic);
		}
		if (nil == attrs)
		{
			attrs = noAttributes;
		}
		[source setAttributes: attrs
		                range: r];
		i = r.location + r.length;
	} while (i < end);
}
- (void)syntaxHighlightFile
{
	CXSourceLocation start = clang_getLocation(translationUnit, file, 0, 0);
	CXSourceLocation end = clang_getLocation(translationUnit, file, -1, -1);
	[self highlightRange: clang_getRange(start, end) syntax: YES];
}
@end

