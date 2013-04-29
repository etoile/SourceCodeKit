#import "TestCommon.h"
#import "SCKClangSourceFile.h"
#import "SCKIntrospection.h"

@interface TestClangParsing : TestCommon
@end

@implementation TestClangParsing

static SCKSourceCollection *sourceCollection = nil;

- (id)init
{
	SUPERINIT;
	/* Prevent reparsing the source files each time a test method is run */
	BOOL parsed = (sourceCollection != nil);
	if (parsed == NO)
	{
		sourceCollection = [SCKSourceCollection new];
		[self parseSourceFilesIntoCollection: sourceCollection];
	}
	return self;
}

- (SCKClass *)parsedClassForName: (NSString *)aClassName
{
	return [[sourceCollection classes] objectForKey: aClassName];
}

- (void)testClass
{
	SCKClass *class = [self parsedClassForName: @"A"];

	UKNotNil(class);
	UKStringsEqual(@"A", [class name]);
    //FIXME:UKStringsEqual(@"B", [[class superclass] name]);
	//FIXME:UKObjectsEqual([self parsedClassForName: @"B"], [class superclass]);
	//FIXME:UKStringsEqual(@"Dummy Class Description", [[class documentation] string]);
}

- (void)testMethod
{
    SCKClass *classA = [self parsedClassForName: @"A"];
    NSDictionary *methods = [classA methods];
	// FIXME: .cxx_destruct shouldn't be listed among the methods
	NSSet *methodNames = S(@".cxx_destruct", @"text", @"setText:",
		@"wakeUpAtDate:", @"sleepLater:", @"sleepNow");

	UKObjectsEqual(methodNames, SA([methods allKeys]));
	UKObjectsEqual(SA([methods allKeys]), SA((id)[[[methods allValues] mappedCollection] name]));

	SCKMethod *sleepNow = [methods objectForKey: @"sleepNow"];
	//SCKMethod *sleepLater = [methods objectForKey: @"sleepLater:"];
    //SCKClass *classB = [self parsedClassForName: @"B"];

	UKObjectsSame(classA, [sleepNow parent]);

	// FIXME: Make all the tests below pass
#if 0
	UKStringsEqual(@"AB.h", [[[sleepNow declaration] file] lastPathComponent]);
	UKTrue([[classA declaration] offset] < [[sleepNow declaration] offset]);
	UKTrue([[sleepLater declaration] offset] < [[sleepNow declaration] offset]);
	UKTrue([[classB declaration] offset] > [[sleepNow declaration] offset]);

	UKStringsEqual(@"AB.m", [[[sleepNow definition] file] lastPathComponent]);
	UKTrue([[classA definition] offset] < [[sleepNow definition] offset]);
	UKTrue([[sleepLater definition] offset] < [[sleepNow definition] offset]);
	UKTrue([[classB definition] offset] > [[sleepNow definition] offset]);

	UKFalse([sleepLater isClassMethod]);
	UKTrue([sleepNow isClassMethod]);
#endif
}

- (void)testIVar
{
    SCKClass *class = [self parsedClassForName: @"C"];
    NSArray *ivars = [class ivars];
	
	UKObjectsEqual(A(@"ivar1", @"ivar2", @"ivar3"), [[ivars mappedCollection] name]);
	
	SCKIvar *ivar1 = [ivars firstObject];

	UKObjectsSame(class, [ivar1 parent]);
}

- (void)testProperty
{
    SCKClass *class = [self parsedClassForName: @"B"];
    NSArray *properties = [class properties];

	UKObjectsEqual(A(@"text1", @"text2", @"text3"), [[properties mappedCollection] name]);

	SCKProperty *text1 = [properties firstObject];

	UKObjectsSame(class, [text1 parent]);
}

- (void)testMacro
{
	// TODO: Finish to implement
    //SCKClass *class = [self parsedClassForName: @"A"];
}

@end
