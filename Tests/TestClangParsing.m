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

// Returns an array of parsed functions
- (NSArray *)parsedFunctionsForNames: (NSArray *)functionNames
{
	return [[sourceCollection functions]
			objectsForKeys: functionNames notFoundMarker: [NSNull null]];
}

// Returns an array of parsed globals
- (NSArray *)parsedGlobalsForNames: (NSArray *)globalNames
{
	return [[sourceCollection globals]
			objectsForKeys: globalNames notFoundMarker: [NSNull null]];
}

// Returns an array of parsed enumerations
- (NSArray *)parsedEnumerationsForNames: (NSArray *)enumerationNames
{
	return [[sourceCollection enumerationValues]
			objectsForKeys: enumerationNames notFoundMarker: [NSNull null]];
}

// Returns an array of parsed macros
- (NSArray *)parsedMacrosForNames: (NSArray *)macroNames
{
	return [[sourceCollection macros]
			objectsForKeys: macroNames notFoundMarker: [NSNull null]];
}

- (void)testClass
{
	SCKClass *classA = [[clangParsingForInterface classes] objectForKey: @"A"];
	
	UKNotNil(classA);
	UKStringsEqual(@"A", [classA name]);
    UKStringsEqual(@"NSObject", [[classA superclass] name]);
	
	SCKClass *classB = [[clangParsingForInterface classes] objectForKey: @"B"];
	
	UKObjectsEqual([[classB superclass] name], [classA name]);
	//FIXME:UKStringsEqual(@"Dummy Class Description", [[class documentation] string]);
}

- (void)testMethod
{
	[self parseSourceFilesIntoCollection: sourceCollection];
		
	SCKClass *classA = [[clangParsingForInterface classes] objectForKey: @"A"];
	NSMutableDictionary *methods = [classA methods];
	[methods removeObjectForKey: @".cxx_destruct"];
	NSSet *methodNames = S(@"text", @"setText:",
		@"wakeUpAtDate:", @"sleepLater:", @"sleepNow");
	
	UKObjectsEqual(methodNames, SA([methods allKeys]));
	UKObjectsEqual(SA([methods allKeys]), SA((id)[[[methods allValues] mappedCollection] name]));

	SCKMethod *sleepNow = [methods objectForKey: @"sleepNow"];
	SCKMethod *sleepLater = [methods objectForKey: @"sleepLater"];
    SCKClass *classB = [[clangParsingForInterface classes] objectForKey: @"B"];

	UKObjectsSame(classA, [sleepNow parent]);
	UKStringsEqual(@"v16@0:8", [sleepNow typeEncoding]);
	
	UKStringsEqual(@"AB.h", [[[sleepNow declaration] file] lastPathComponent]);
	UKTrue([[classA declaration] offset] < [[sleepNow declaration] offset]);
	UKTrue([[sleepLater declaration] offset] < [[sleepNow declaration] offset]);
	UKTrue([[classB declaration] offset] < [[sleepNow declaration] offset]);

	SCKClass *classAImplementation = [[clangParsingForImplementation classes] objectForKey: @"A"];
	NSMutableDictionary *methodsImplementation = [classAImplementation methods];
	SCKMethod *sleepNowImplementation = [methodsImplementation objectForKey: @"sleepNow"];
	SCKMethod *sleepLaterImplementation = [methodsImplementation objectForKey: @"sleepLater"];
	// FIXME: Doesn't return definition
#if 0
	UKStringsEqual(@"AB.m", [[[sleepNowImplementation definition] file] lastPathComponent]);
	UKTrue([[classA definition] offset] < [[sleepNowImplementation definition] offset]);
	UKTrue([[sleepLaterImplementation definition] offset] < [[sleepNowImplementation definition] offset]);
	UKTrue([[classB definition] offset] > [[sleepNowImplementation definition] offset]);
#endif

	UKFalse([sleepLater isClassMethod]);
	UKTrue([sleepNow isClassMethod]);
}

- (void)testIVar
{
	[self parseSourceFilesIntoCollection: sourceCollection];
	
	SCKClass *classC = [[clangParsingForInterface classes] objectForKey: @"C"];
	NSDictionary *ivars = [classC ivars];
	
	UKObjectsEqual(A(@"ivar1", @"ivar2", @"ivar3"), [[[ivars allValues] mappedCollection] name]);
	
	SCKIvar *ivar1 = [[ivars allValues] firstObject];
	SCKIvar *ivar2 = [[ivars allValues] objectAtIndex: 1];

	UKObjectsSame(classC, [ivar1 parent]);
	
	UKStringsEqual(@"@", [ivar1 typeEncoding]);
	
	UKStringsEqual(@"AB.h", [[[ivar1 declaration] file] lastPathComponent]);
	UKTrue([[classC declaration] offset] < [[ivar1 declaration] offset]);
	UKTrue([[ivar2 declaration] offset] > [[ivar1 declaration] offset]);
}

- (void)testProperty
{
	[self parseSourceFilesIntoCollection: sourceCollection];
	
	SCKClass *class = [[clangParsingForInterface classes] objectForKey: @"B"];
	NSDictionary *properties = [class properties];

	// FIXME: This test fails on GNUstep but not Mac OS X.
	UKObjectsEqual(A(@"button", @"text2", @"text3"), [[[properties allValues] mappedCollection] name]);

	SCKProperty *button = [[properties allValues] firstObject];
	SCKProperty *text2 = [[properties allValues] objectAtIndex: 1];
	
	UKObjectsSame(class, [button parent]);
	UKStringsEqual(@"T@\"NSButton\",&,N", [button typeEncoding]);
	
	UKStringsEqual(@"AB.h", [[[button declaration] file] lastPathComponent]);
	UKTrue([[class declaration] offset] < [[button declaration] offset]);
	UKTrue([[text2 declaration] offset] > [[button declaration] offset]);
}

- (void)testProtocol
{
	[self parseSourceFilesIntoCollection: sourceCollection];
	
	// Protocol Definition
	SCKProtocol *protocol1 = [[clangParsingForInterface protocols] objectForKey: @"Protocol1"];
	
	UKNotNil(protocol1);
	UKStringsEqual(@"AB.h", [[[protocol1 definition] file] lastPathComponent]);
	
	// Protocol Declaration
	SCKProtocol *protocol2 = [[clangParsingForInterface protocols] objectForKey: @"Protocol2"];
	
	UKNotNil(protocol2);
	UKStringsEqual(@"AB.h", [[[protocol2 declaration] file] lastPathComponent]);
}

- (void)testMacro
{
	// FIXME: SCK indexing problem
#if 0
	NSMutableDictionary *parsedMacros = [clangParsingForInterface macros];
	
	UKObjectsEqual(A(@"MACRO1", @"MACRO2"), [[[parsedMacros allValues] mappedCollection] name]);
	
	SCKMacro *macro1 = [[parsedMacros allValues] firstObject];
	UKNotNil(macro1);
	UKStringsEqual(@"AB.h", [[[macro1 declaration] file] lastPathComponent]);
#endif
}

- (void)testEnumeration
{
	[self parseSourceFilesIntoCollection: sourceCollection];
	
	NSArray *parsedEnumerationValues = [[clangParsingForInterface enumerationValues] objectsForKeys: A(@"value1", @"value2", @"value3") notFoundMarker: [NSNull null]];
	
	UKObjectsEqual(A(@"value1", @"value2", @"value3"),
				   [[parsedEnumerationValues mappedCollection] name]);
	
	SCKEnumeration *enumValue1 = [parsedEnumerationValues firstObject];
	SCKEnumeration *enumValue2 = [parsedEnumerationValues objectAtIndex: 1];
	
	UKStringsEqual(@"AB.h", [[[enumValue1 declaration] file] lastPathComponent]);
	UKTrue([[enumValue2 declaration] offset] > [[enumValue1 declaration] offset]);
}

- (void)testFunction
{
	[self parseSourceFilesIntoCollection: sourceCollection];
	
	NSArray *parsedFunctions = [[clangParsingForInterface functions]
								objectsForKeys: A(@"function1", @"function2") notFoundMarker: [NSNull null]];
		
	UKObjectsEqual(A(@"function1", @"function2"), [[parsedFunctions mappedCollection] name]);
	
	SCKFunction *function1Declaration = [parsedFunctions firstObject];
	SCKFunction *function2Declaration = [parsedFunctions objectAtIndex: 1];
	UKStringsEqual(@"AB.h", [[[function1Declaration declaration] file] lastPathComponent]);
	UKTrue([[function2Declaration declaration] offset] > [[function1Declaration declaration] offset]);
	
	NSArray *parsedFunctionDefinition = [[clangParsingForImplementation functions]
										 objectsForKeys: A(@"function1", @"function2") notFoundMarker: [NSNull null]];
	SCKFunction *function1Definition = [parsedFunctionDefinition firstObject];
	UKStringsEqual(@"AB.m", [[[function1Definition definition] file] lastPathComponent]);
}

- (void)testGlobal
{
	[self parseSourceFilesIntoCollection: sourceCollection];
	
	NSArray *parsedGlobals = [[clangParsingForInterface globals]
							  objectsForKeys: A(@"kGlobal1", @"kGlobal2") notFoundMarker: [NSNull null]];
		
	UKObjectsEqual(A(@"kGlobal1", @"kGlobal2"), [[parsedGlobals mappedCollection] name]);

	SCKGlobal *kGlobal1 = [parsedGlobals firstObject];
	SCKGlobal *kGlobal2 = [parsedGlobals objectAtIndex: 1];
	UKStringsEqual(@"AB.h", [[[kGlobal1 declaration] file] lastPathComponent]);
	UKTrue([[kGlobal2 declaration] offset] > [[kGlobal1 declaration] offset]);
}

@end
