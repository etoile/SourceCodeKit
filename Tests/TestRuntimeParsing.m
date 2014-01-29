#import "TestCommon.h"

@interface TestRuntimeParsing : TestCommon
@end

@implementation TestRuntimeParsing

- (SCKClass *)parsedClassForName: (NSString *)className
{
	SCKClass *class = [SCKClass new];
	return [class initWithClass: NSClassFromString(className)];
}

- (void)testClass
{
	SCKClass *classA = [self parsedClassForName: @"A"];
	
	UKNotNil(classA);
	UKStringsEqual(@"A", [classA name]);
}

- (void)testMethod
{
	SCKClass *classA = [self parsedClassForName: @"A"];
	NSMutableDictionary *methods = [classA methods];
	[methods removeObjectForKey: @".cxx_destruct"];
	NSSet *methodNames = S(@"text", @"setText:", @"wakeUpAtDate:",
						   @"sleepLater:", @"methodInCategory");
	
	UKObjectsEqual(methodNames, SA([methods allKeys]));
	UKObjectsEqual(SA([methods allKeys]), SA((id)[[[methods allValues] mappedCollection] name]));
	
	SCKMethod *sleepLater = [methods objectForKey: @"sleepLater:"];
	/* The numbers in the signature encoding are platform-dependent, but the other characters
	   remain valid accross platforms */
	NSCharacterSet *charset = [NSCharacterSet decimalDigitCharacterSet];
	NSString *sleepLaterTypeEncoding = [[[sleepLater typeEncoding]
		componentsSeparatedByCharactersInSet: charset] componentsJoinedByString: @""];
	
	UKObjectsEqual(classA, [sleepLater parent]);
	UKStringsEqual(@"v@:Q", sleepLaterTypeEncoding);
}

- (void)testProperty
{
	SCKClass *classB = [self parsedClassForName: @"B"];
	NSMutableArray *properties = [classB properties];
	
	UKObjectsEqual(A(@"button", @"text2", @"text3"), [[properties mappedCollection] name]);
	
	SCKProperty *button = [properties firstObject];

	UKObjectsEqual(classB, [button parent]);
	UKStringsEqual(@"T@\"NSButton\",&,N,Vbutton", [button typeEncoding]);
}

- (void)testIVar
{
	SCKClass *classC = [self parsedClassForName: @"C"];
	NSMutableArray *ivars = [classC  ivars];
	
	UKObjectsEqual(A(@"ivar1", @"ivar2", @"ivar3"), [[ivars mappedCollection] name]);
	
	SCKIvar *ivar1 = [ivars firstObject];
	
	UKObjectsEqual(classC, [ivar1 parent]);
	UKStringsEqual(@"@\"NSString\"", [ivar1 typeEncoding]);
}

@end
