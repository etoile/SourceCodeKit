#import "SCKSourceFile.h"
#import <Cocoa/Cocoa.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import "SCKTextTypes.h"
#include <time.h>


@implementation SCKSourceFile
- (id)initUsingIndex: (SCKIndex*)anIndex
{
	[self release];
	return nil;
}
+ (SCKSourceFile*)fileUsingIndex: (SCKIndex*)anIndex
{
	return [[[self alloc] initUsingIndex: (SCKIndex*)anIndex] autorelease];
}
- (void)reparse {}
- (void)lexicalHighlightFile {}
- (void)syntaxHighlightFile {}
- (void)syntaxHighlightRange: (NSRange)r {}
- (void)addIncludePath: (NSString*)includePath {}
@end

