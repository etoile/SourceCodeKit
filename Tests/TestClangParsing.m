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

- (SCKClangSourceFile*)parsedFileForName: (NSString*)aFileName
{
	NSArray *files = [[self parsingTestFiles] filteredCollectionWithBlock: ^ (id path)
	{
		return [[path lastPathComponent] isEqual: aFileName];
	}];
	return (id)[sourceCollection sourceFileForPath: [files firstObject]];
}

- (NSDictionary*)programComponentsFromFilesForKey: (NSString*)key
{
	NSMutableDictionary *components = [NSMutableDictionary new];
	for (SCKSourceFile *file in [[sourceCollection files] objectEnumerator])
	{
		[components addEntriesFromDictionary: [file valueForKey: key]];
	}
	return components;
}

- (SCKClass*)parsedClassForName: (NSString*)aClassName
{
	return [[sourceCollection classes] objectForKey: aClassName];
}

- (SCKProtocol*)parsedProtocolForName: (NSString*)aProtocolName
{
	return [[sourceCollection protocols] objectForKey: aProtocolName];
}

- (NSArray*)parsedFunctionsForNames: (NSArray*)functionNames
{
	return [[sourceCollection functions] objectsForKeys: functionNames notFoundMarker: [NSNull null]];
}

- (NSArray*)parsedGlobalsForNames: (NSArray*)globalNames
{
	return [[sourceCollection globals] objectsForKeys: globalNames notFoundMarker: [NSNull null]];
}

- (NSArray*)parsedEnumerationsForNames: (NSArray*)enumerationNames
{
	NSDictionary *enumValues = [self programComponentsFromFilesForKey: @"enumerationValues"];
	return [enumValues objectsForKeys: enumerationNames notFoundMarker: [NSNull null]];
}

- (NSArray*)parsedMacrosForNames: (NSArray*)macroNames
{
	NSDictionary *macros = [self programComponentsFromFilesForKey: @"macros"];
	return [macros objectsForKeys: macroNames notFoundMarker: [NSNull null]];
}

- (void)testClass
{
	SCKClass *classA = [self parsedClassForName: @"A"];
	SCKClass *classB = [self parsedClassForName: @"B"];
	NSMutableDictionary *adoptedProtocols = [classA adoptedProtocols];
	NSSet *adoptedProtocolNames = S(@"Protocol1", @"Protocol3", @"Protocol4", @"Protocol5");
	SCKFunction *function2 = [[self parsedFunctionsForNames: A(@"function2")] firstObject];

	UKNotNil(classA);
	UKStringsEqual(@"A", [classA name]);
	UKStringsEqual(@"NSObject", [[classA superclass] name]);
	UKObjectsEqual([[classB superclass] name], [classA name]);
	
	// Adopted protocol related tests
	UKObjectsEqual(adoptedProtocolNames, SA([adoptedProtocols allKeys]));
	UKObjectsEqual(SA([adoptedProtocols allKeys]), SA((id)[[[adoptedProtocols allValues] mappedCollection] name]));
	
	// FIXME:UKStringsEqual(@"Dummy Class Description", [[class documentation] string]);
	
	UKStringsEqual(@"AB.h", [[[classA declaration] file] lastPathComponent]);
	UKTrue([[function2 declaration] offset] < [[classA declaration] offset]);
	UKTrue([[classB declaration] offset] > [[classA declaration] offset]);
	
	UKStringsEqual(@"AB.m", [[[classA definition] file] lastPathComponent]);
	UKTrue([[function2 definition] offset] < [[classA definition] offset]);
	UKTrue([[classB definition] offset] > [[classA definition] offset]);
}

- (void)testProtocol
{
	SCKProtocol *protocol1 = [self parsedProtocolForName: @"Protocol1"];
	SCKProtocol *protocol2 = [self parsedProtocolForName: @"Protocol2"];
	SCKProtocol *protocol3 = [self parsedProtocolForName: @"Protocol3"];
	NSMutableDictionary *adoptedProtocols = [protocol3 adoptedProtocols];
	NSSet *adoptedProtocolNames = S(@"Protocol1");
	SCKFunction *function2 = [[self parsedFunctionsForNames: A(@"function2")] firstObject];
	
	UKNotNil(protocol1);
	UKNotNil(protocol2);
	UKNotNil(protocol3);

	// Adopted protocol related tests
	UKObjectsEqual(adoptedProtocolNames, SA([adoptedProtocols allKeys]));
	UKObjectsEqual(SA([adoptedProtocols allKeys]), SA((id)[[[adoptedProtocols allValues] mappedCollection] name]));


	UKFalse([protocol1 isForwardDeclaration]);
	UKTrue([protocol2 isForwardDeclaration]);
	UKFalse([protocol3 isForwardDeclaration]);

	UKObjectsEqual([protocol1 definition], [protocol1 declaration]);
	UKObjectsEqual([protocol3 definition], [protocol3 declaration]);
	UKNil([protocol2 declaration]);

	UKStringsEqual(@"AB.h", [[[protocol1 definition] file] lastPathComponent]);
	UKTrue([[function2 declaration] offset] < [[protocol1 definition] offset]);
	UKTrue([[protocol3 definition] offset] > [[protocol1 definition] offset]);
}

// NOTE: libclang versions prior to 21 parse all protocol methods as required.
- (void)testMethodInProtocol
{
	SCKProtocol *protocol1 = [self parsedProtocolForName: @"Protocol1"];
	NSMutableDictionary *requiredMethods = [protocol1 requiredMethods];
	NSMutableDictionary *optionalMethods = [protocol1 optionalMethods];
#if CINDEX_VERSION >= 21
	NSSet *requiredMethodsNames = S(@"goodbye", @"hi", @"string", @"setString:");
	NSSet *optionalMethodsNames = S(@"date", @"farewell", @"setDate:");
#else
	NSSet *requiredMethodsNames = S(@"goodbye", @"hi", @"string", @"setString:",
		@"date", @"farewell", @"setDate:");
#endif
	
	UKObjectsEqual(requiredMethodsNames, SA([requiredMethods allKeys]));
	UKObjectsEqual(SA([requiredMethods allKeys]), SA((id)[[[requiredMethods allValues] mappedCollection] name]));

#if CINDEX_VERSION >= 21
	UKObjectsEqual(optionalMethodsNames, SA([optionalMethods allKeys]));
	UKObjectsEqual(SA([optionalMethods allKeys]), SA((id)[[[optionalMethods allValues] mappedCollection] name]));
#endif

	SCKMethod *hi = [requiredMethods objectForKey: @"hi"];
#if CINDEX_VERSION >= 21
	SCKMethod *farewell = [optionalMethods objectForKey: @"farewell"];
#else
	SCKMethod *farewell = [requiredMethods objectForKey: @"farewell"];
#endif
	SCKProtocol *protocol2 = [self parsedProtocolForName: @"Protocol2"];
	
	/* The numbers in the signature encoding are platform-dependent, but the other characters
	   remain valid accross platform */
	NSCharacterSet *charSet = [NSCharacterSet decimalDigitCharacterSet];
	NSString *farewellTypeEncoding = [[[farewell typeEncoding] componentsSeparatedByCharactersInSet: charSet] componentsJoinedByString: @""];
	
	UKObjectsSame(protocol1, [farewell parent]);
	UKStringsEqual(@"v@:", farewellTypeEncoding);
	
	UKFalse([hi isClassMethod]);
	UKTrue([farewell isClassMethod]);
	
	UKStringsEqual(@"AB.h", [[[farewell declaration] file] lastPathComponent]);
	UKTrue([[protocol1 declaration] offset] < [[farewell declaration] offset]);
	UKTrue([[hi declaration] offset] < [[farewell declaration] offset]);
	UKTrue([[farewell declaration] offset] > [[protocol2 declaration] offset]);
}

// NOTE: libclang versions prior to 21 parse all protocol properties as required.
- (void)testPropertyInProtocol
{
	SCKProtocol *protocol1 = [self parsedProtocolForName: @"Protocol1"];
	NSMutableArray *requiredProperties = [protocol1 requiredProperties];
	NSMutableArray *optionalProperties = [protocol1 optionalProperties];

#if CINDEX_VERSION >= 21
	UKObjectsEqual(A(@"string"), (id)[[requiredProperties mappedCollection] name]);
	UKObjectsEqual(A(@"date"), (id)[[optionalProperties mappedCollection] name]);
#else
	UKObjectsEqual(A(@"string", @"date"), (id)[[requiredProperties mappedCollection] name]);
#endif

	SCKProperty *string = [requiredProperties firstObject];
#if CINDEX_VERSION >= 21
	SCKProperty *date = [optionalProperties firstObject];
#else
	SCKProperty *date = [requiredProperties lastObject];
#endif

	UKObjectsSame(protocol1, [string parent]);
	UKStringsEqual(@"T@\"NSString\"", [string typeEncoding]);
	
	UKStringsEqual(@"AB.h", [[[string declaration] file] lastPathComponent]);
	UKTrue([[protocol1 declaration] offset] < [[string declaration] offset]);
	UKTrue([[date declaration] offset] > [[string declaration] offset]);
}

 // NOTE: libclang versions prior to 21 parses all protocol properties as required.
- (void)testCategory
{
	SCKClass *classA = [self parsedClassForName: @"A"];
	SCKClass *classB = [self parsedClassForName: @"B"];
	NSMutableDictionary *categories = [classA categories];
	NSMutableDictionary *adoptedProtocols = [[[categories allValues] objectAtIndex: 0] adoptedProtocols];
	NSSet *adoptedProtocolNames = S(@"Protocol4", @"Protocol5");
	SCKCategory *aExtension = [categories objectForKey: @"AExtension"];
	
	UKNotNil(aExtension);
	UKStringsEqual(@"AExtension", [aExtension name]);
	UKStringsEqual(@"A", [[aExtension parent] name]);

	// Adopted protocol related tests
	UKObjectsEqual(adoptedProtocolNames, SA([adoptedProtocols allKeys]));
	UKObjectsEqual(SA([adoptedProtocols allKeys]), SA((id)[[[adoptedProtocols allValues] mappedCollection] name]));

	UKStringsEqual(@"AB.h", [[[aExtension declaration] file] lastPathComponent]);
	UKTrue([[classA declaration] offset] < [[aExtension declaration] offset]);
	UKTrue([[classB declaration] offset] > [[aExtension declaration] offset]);

	UKStringsEqual(@"AB.m", [[[aExtension definition] file] lastPathComponent]);
	UKTrue([[classA definition] offset] < [[aExtension definition] offset]);
	UKTrue([[classB definition] offset] > [[aExtension definition] offset]);
}

- (void)testMethodInCategory
{
	SCKClass *classA = [self parsedClassForName: @"A"];
	NSMutableDictionary *categories = [classA categories];
	SCKCategory *aExtension = [categories objectForKey: @"AExtension"];
	NSMutableDictionary *methods = [aExtension methods];
	NSSet *methodNames = S(@"propertyInsideCategory",
		@"setPropertyInsideCategory:", @"methodInCategory", @"haveHotChocolate", @"haveMilkshake");

	UKObjectsEqual(methodNames, SA([methods allKeys]));
	UKObjectsEqual(SA([methods allKeys]), SA((id)[[[methods allValues] mappedCollection] name]));
	
	SCKMethod *methodInCategory = [methods objectForKey: @"methodInCategory"];
	SCKClass *classB = [self parsedClassForName: @"B"];
	/* The numbers in the signature encoding are platform-dependent, but the other characters
	   remain valid accross platforms */
	NSCharacterSet *charset = [NSCharacterSet decimalDigitCharacterSet];
	NSString *methodInCategoryTypeEncoding = [[[methodInCategory typeEncoding]
		componentsSeparatedByCharactersInSet: charset] componentsJoinedByString: @""];

	UKObjectsSame(classA, [methodInCategory parent]);
	UKStringsEqual(@"v@:", methodInCategoryTypeEncoding);

	UKFalse([methodInCategory isClassMethod]);
	
	UKStringsEqual(@"AB.h", [[[methodInCategory declaration] file] lastPathComponent]);
	UKTrue([[aExtension declaration] offset] < [[methodInCategory declaration] offset]);
	UKTrue([[classB declaration] offset] > [[methodInCategory declaration] offset]);

	UKStringsEqual(@"AB.m", [[[methodInCategory definition] file] lastPathComponent]);
	UKTrue([[aExtension definition] offset] < [[methodInCategory definition] offset]);
	UKTrue([[classB definition] offset] > [[methodInCategory definition] offset]);
}

- (void)testPropertyInCategory
{
	SCKClass *classA = [self parsedClassForName: @"A"];
	SCKCategory *aExtension = [[classA categories] objectForKey: @"AExtension"];
	NSMutableArray *properties = [aExtension properties];

	UKObjectsEqual(A(@"propertyInsideCategory"), (id)[[properties mappedCollection] name]);

	SCKProperty *propertyInsideCategory = [properties firstObject];
	SCKClass *classB = [self parsedClassForName: @"B"];

	UKObjectsSame(classA, [propertyInsideCategory parent]);
	UKStringsEqual(@"T@\"NSString\"", [propertyInsideCategory typeEncoding]);

	UKStringsEqual(@"AB.h", [[[propertyInsideCategory declaration] file] lastPathComponent]);
	UKTrue([[aExtension declaration] offset] < [[propertyInsideCategory declaration] offset]);
	UKTrue([[classB declaration] offset] > [[propertyInsideCategory declaration] offset]);

	UKStringsEqual(@"AB.m", [[[propertyInsideCategory definition] file] lastPathComponent]);
	UKTrue([[aExtension definition] offset] < [[propertyInsideCategory definition] offset]);
	UKTrue([[classB definition] offset] > [[propertyInsideCategory definition] offset]);
}

- (void)testMethod
{
	SCKClass *classA = [self parsedClassForName: @"A"];
	NSMutableDictionary *methods = [classA methods];
	NSSet *methodNames = S(@"text", @"setText:", @"wakeUpAtDate:",
		@"sleepLater:", @"sleepNow", @"propertyInsideCategory",
		@"setPropertyInsideCategory:", @"methodInCategory", @"haveHotChocolate", @"haveMilkshake");

	UKObjectsEqual(methodNames, SA([methods allKeys]));
	UKObjectsEqual(SA([methods allKeys]), SA((id)[[[methods allValues] mappedCollection] name]));

	SCKMethod *sleepNow = [methods objectForKey: @"sleepNow"];
	SCKMethod *sleepLater = [methods objectForKey: @"sleepLater:"];
	SCKClass *classB = [self parsedClassForName: @"B"];
	/* The numbers in the signature encoding are platform-dependent, but the other characters  
	   remain valid accross platforms */
	NSCharacterSet *charset = [NSCharacterSet decimalDigitCharacterSet];
	NSString *sleepNowTypeEncoding = [[[sleepNow typeEncoding] 
		componentsSeparatedByCharactersInSet: charset] componentsJoinedByString: @""];

	UKObjectsSame(classA, [sleepNow parent]);
	UKStringsEqual(@"v@:", sleepNowTypeEncoding);

	UKFalse([sleepLater isClassMethod]);
	UKTrue([sleepNow isClassMethod]);

	UKStringsEqual(@"AB.h", [[[sleepNow declaration] file] lastPathComponent]);
	UKTrue([[classA declaration] offset] < [[sleepNow declaration] offset]);
	UKTrue([[sleepLater declaration] offset] < [[sleepNow declaration] offset]);
	UKTrue([[classB declaration] offset] > [[sleepNow declaration] offset]);

	UKStringsEqual(@"AB.m", [[[sleepNow definition] file] lastPathComponent]);
	UKTrue([[classA definition] offset] < [[sleepNow definition] offset]);
	UKTrue([[sleepLater definition] offset] < [[sleepNow definition] offset]);
	UKTrue([[classB definition] offset] > [[sleepNow definition] offset]);
}

- (void)testIVar
{
	SCKClass *classC = [self parsedClassForName: @"C"];
	NSArray *ivars = [classC ivars];
	
	UKObjectsEqual(A(@"ivar1", @"ivar2", @"ivar3"), (id)[[ivars mappedCollection] name]);
	
	SCKIvar *ivar1 = [ivars firstObject];
	SCKIvar *ivar2 = [ivars objectAtIndex: 1];

	UKFalse([ivar1 isIBOutlet]);
	UKTrue([ivar2 isIBOutlet]);

	UKObjectsSame(classC, [ivar1 parent]);
	UKStringsEqual(@"@", [ivar1 typeEncoding]);
	
	UKStringsEqual(@"AB.h", [[[ivar1 declaration] file] lastPathComponent]);
	UKTrue([[classC declaration] offset] < [[ivar1 declaration] offset]);
	UKTrue([[ivar2 declaration] offset] > [[ivar1 declaration] offset]);
}

- (void)testProperty
{
	SCKClass *classB = [self parsedClassForName: @"B"];
	NSArray *properties = [classB properties];

	UKObjectsEqual(A(@"button", @"text2", @"text3"), (id)[[properties mappedCollection] name]);

	SCKProperty *button = [properties firstObject];
	SCKProperty *text2 = [properties lastObject];

	UKTrue([button isIBOutlet]);
	UKFalse([text2 isIBOutlet]);

	UKObjectsSame(classB, [button parent]);
	UKStringsEqual(@"T@\"NSButton\",&,N", [button typeEncoding]);
	
	UKStringsEqual(@"AB.h", [[[button declaration] file] lastPathComponent]);
	UKTrue([[classB declaration] offset] < [[button declaration] offset]);
	UKTrue([[text2 declaration] offset] > [[button declaration] offset]);

	// TODO: Parse property definition in @implementation (e.g. @synthesize or @dynamic)
}

- (void)testMacro
{
	// FIXME: Finish macro support in SCK
#if 0
	NSArray *parsedMacros = [self parsedMacrosForNames: A(@"MACRO1", @"MACRO2")];
	
	UKObjectsEqual(A(@"MACRO1", @"MACRO2"), [[parsedMacros mappedCollection] name]);
	
	SCKMacro *macro1 = [parsedMacros firstObject];
	
	UKNotNil(macro1);
	UKStringsEqual(@"AB.h", [[[macro1 declaration] file] lastPathComponent]);
#endif
}

- (void)testEnumeration
{
	NSArray *parsedEnumValues = [self parsedEnumerationsForNames: A(@"value1", @"value2", @"value3")];
	
	UKObjectsEqual(A(@"value1", @"value2", @"value3"), [[parsedEnumValues mappedCollection] name]);
	
	SCKEnumeration *enumValue1 = [parsedEnumValues firstObject];
	SCKEnumeration *enumValue2 = [parsedEnumValues objectAtIndex: 1];
	SCKEnumeration *enumValue3 = [parsedEnumValues objectAtIndex: 2];
	
	UKStringsEqual(@"AB.h", [[[enumValue1 declaration] file] lastPathComponent]);
	UKTrue([[enumValue2 declaration] offset] > [[enumValue1 declaration] offset]);
	UKTrue([[enumValue2 declaration] offset] < [[enumValue3 declaration] offset]);
}

- (void)testFunction
{
	NSArray *parsedFunctions = [self parsedFunctionsForNames: A(@"function1", @"function2")];
	
	UKObjectsEqual(A(@"function1", @"function2"), [[parsedFunctions mappedCollection] name]);
	
	SCKFunction *function1 = [parsedFunctions firstObject];
	SCKFunction *function2 = [parsedFunctions objectAtIndex: 1];
	SCKGlobal *firstGlobal = [[self parsedGlobalsForNames: A(@"kGlobal1")] firstObject];
	SCKClass *classA = [self parsedClassForName: @"A"];
	
	UKStringsEqual(@"AB.h", [[[function1 declaration] file] lastPathComponent]);
	UKTrue([[function2 declaration] offset] > [[function1 declaration] offset]);
	UKTrue([[function2 declaration] offset] < [[firstGlobal declaration] offset]);

	UKStringsEqual(@"AB.m", [[[function1 definition] file] lastPathComponent]);
	UKTrue([[function2 definition] offset] > [[function1 definition] offset]);
	UKTrue([[function2 definition] offset] < [[classA definition] offset]);
}

- (void)testStaticFunction
{
	SCKClangSourceFile *sourceFile = [self parsedFileForName: @"AB.m"];

	UKIntsEqual(1, [[sourceFile functions] count]);
	
	SCKFunction *function3 = [[sourceFile functions] objectForKey: @"function3"];

	UKNotNil(function3);
	UKStringsEqual(@"function3", [function3 name]);
}

- (void)testGlobal
{
	NSArray *parsedGlobals = [self parsedGlobalsForNames: A(@"kGlobal1", @"kGlobal2")];
	
	UKObjectsEqual(A(@"kGlobal1", @"kGlobal2"), [[parsedGlobals mappedCollection] name]);
	
	SCKGlobal *kGlobal1 = [parsedGlobals firstObject];
	SCKGlobal *kGlobal2 = [parsedGlobals objectAtIndex: 1];
	SCKFunction *function2 = [[self parsedFunctionsForNames: A(@"function2")] firstObject];

	UKStringsEqual(@"AB.h", [[[kGlobal1 declaration] file] lastPathComponent]);
	UKTrue([[function2 declaration] offset] < [[kGlobal1 declaration] offset]);
	UKTrue([[kGlobal2 declaration] offset] > [[kGlobal1 declaration] offset]);

	UKStringsEqual(@"AB.m", [[[kGlobal1 definition] file] lastPathComponent]);
	UKTrue([[function2 definition] offset] < [[kGlobal1 definition] offset]);
	UKTrue([[kGlobal2 definition] offset] > [[kGlobal1 definition] offset]);
}

@end
