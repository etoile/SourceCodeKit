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
	NSParameterAssert(aSourceCollection != nil);
	
	[aSourceCollection clear];
	
	for (NSString *path in [self parsingTestFiles])
	{
		[aSourceCollection sourceFileForPath: path];
	}
}
						
@end
