#import "TestCommon.h"
#import "SCKClangSourceFile.h"
#import "SCKIntrospection.h"

@interface TestClangParsing : TestCommon
@end

@implementation TestClangParsing

- (void)testClass
{
	SCKClass *class = [[sourceCollection classes] objectForKey: @"A"];
	
	UKNotNil(class);
	UKStringsEqual(@"A", [class name]);
	// FIXME: UKStringsEqual(@"B", [[class superclass] name]);
	// FIXME: UKObjectsEqual([[sourceCollection classes] objectForKey: @"B"], [class superclass]);
	// FIXME: UKStringsEqual(@"Dummy Class Description", [[class documentation] string]);
}

@end
