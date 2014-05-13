#include <Foundation/NSObject.h>
#include <Foundation/NSGeometry.h>
#include <Foundation/NSRange.h>

@class SCKIndex;
@class NSMutableArray;
@class NSMutableAttributedString;
@class SCKSourceCollection;
@class SCKCodeCompletionResult;

/**
 * The SCKSyntaxHighlighter class is responsible for performing lexical and
 * syntax highlighting on a single source file.  Highlighting involves three steps:
 *
 * 1) Lexical markup.
 * 2) Syntax markup.
 * 3) Presentation markup.
 *
 * Lexical highlighting is faster than full syntax highlighting, so it can be
 * used more frequently in an editor.  For example, you might run the lexical
 * highlighter after every key press but defer the syntax highlighter until
 * after a whitespace character had been entered.
 *
 * The third step is optional.  If you are not using AppKit, then you can
 * ignore it and handle the presentation yourself.  This is useful, for
 * example, when generating semantic HTML from a source file.
 */
@interface SCKSourceFile : NSObject
{
	NSMutableAttributedString *source;
	NSString *fileName;
}
/**
 * Text storage object representing the source file.
 */
@property (retain, nonatomic) NSMutableAttributedString *source;
/**
 * Name of this source file.
 */
@property (retain, nonatomic) NSString *fileName;
/**
 * The source collection containing this file.
 */
@property (nonatomic, unsafe_unretained) SCKSourceCollection *collection;
+ (SCKSourceFile*)fileUsingIndex: (SCKIndex*)anIndex;
/**
 * Parses the contents of the file.  Must be called before reapplying
 * highlighting after the file has changed.
 */
- (void)reparseWithOption: (short)parsingOption;
/**
 * Performs lexical highlighting on the entire file.
 */
- (void)lexicalHighlightFile;
/**
 * Perform syntax highlighting on the whole file.
 */
- (void)syntaxHighlightFile;
/**
 * Performs syntax highlighting on the specified range.
 */
- (void)syntaxHighlightRange: (NSRange)r;
/**
 * Adds an include path to search when performing syntax highlighting.
 */
- (void)addIncludePath: (NSString*)includePath;
/**
 * Checks for errors and adds kSCKDiagnostic attributes to ranges in the source
 * attributed string which contain them.
 */
- (void)collectDiagnostics;
/**
 * Returns completion result at the location
 */
- (SCKCodeCompletionResult*)completeAtLocation: (NSUInteger) location;
@end

@interface SCKSourceLocation : NSObject
{
	@public
	NSString *file;
	NSUInteger offset;
}
@property (retain, nonatomic) NSString *file;
@property (readonly, nonatomic) NSUInteger offset;
@end
