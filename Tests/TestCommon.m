#import "TestCommon.h"

@implementation TestCommon

- (NSArray*)parsingTestFiles
{
	NSBundle *bundle = [NSBundle bundleForClass: [self class]];
	NSArray *testFiles = [bundle pathsForResourcesOfType: @"h" inDirectory: nil];
	testFiles = [testFiles arrayByAddingObjectsFromArray:
		[bundle pathsForResourcesOfType: @"m" inDirectory: nil]];
	ETAssert([testFiles count] >= 2);
	return testFiles;
}

- (void)parseSourceFilesIntoCollection: (SCKSourceCollection*)aSourceCollection
{
	for (NSString *path in [self parsingTestFiles])
	{
		[aSourceCollection sourceFileForPath: path];
	}
}
						
- (id)init
{
	SUPERINIT;
	sourceCollection = [SCKSourceCollection new];
	[self parseSourceFilesIntoCollection: sourceCollection];
	return self;
}

@end
