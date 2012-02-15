#import "SCKSourceFile.h"
#import <Cocoa/Cocoa.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import "SCKTextTypes.h"
#include <time.h>


@implementation SCKSourceFile
@synthesize fileName, source, collection;
- (id)initUsingIndex: (SCKIndex*)anIndex
{
	return nil;
}
+ (SCKSourceFile*)fileUsingIndex: (SCKIndex*)anIndex
{
	return [[self alloc] initUsingIndex: (SCKIndex*)anIndex];
}
- (void)reparse {}
- (void)lexicalHighlightFile {}
- (void)syntaxHighlightFile {}
- (void)syntaxHighlightRange: (NSRange)r {}
- (void)addIncludePath: (NSString*)includePath {}
- (void)collectDiagnostics {}
- (SCKCodeCompletionResult*)completeAtLocation: (NSUInteger) location { return nil; }
@end

