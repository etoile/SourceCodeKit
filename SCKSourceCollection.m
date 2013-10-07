#import "SourceCodeKit.h"
#import <Cocoa/Cocoa.h>
#import <EtoileFoundation/EtoileFoundation.h>
#include <objc/runtime.h>

/**
 * Mapping from source file extensions to SCKSourceFile subclasses.
 */
static NSDictionary *fileClasses;

@interface SCKClangIndex : NSObject @end

@implementation SCKSourceCollection
@synthesize bundles;
+ (void)initialize
{
	Class clang = NSClassFromString(@"SCKClangSourceFile");
	fileClasses = D(clang, @"m",
	                clang, @"cc",
	                clang, @"c",
	                clang, @"h",
	                clang, @"cpp");
}
- (id)init
{
	SUPERINIT
	indexes = [NSMutableDictionary new];
	// A single clang index instance for all of the clang-supported file types
	id index = [SCKClangIndex new];
	[indexes setObject: index forKey: @"m"];
	[indexes setObject: index forKey: @"c"];
	[indexes setObject: index forKey: @"h"];
	[indexes setObject: index forKey: @"cpp"];
	[indexes setObject: index forKey: @"cc"];
	files = [NSMutableDictionary new];
	bundles = [NSMutableDictionary new];
	bundleClasses = [NSMutableDictionary new];
	int count = objc_getClassList(NULL, 0);
	Class *classList = (__unsafe_unretained Class *)calloc(sizeof(Class), count);
	objc_getClassList(classList, count);
	for (int i=0 ; i<count ; i++)
	{
		STACK_SCOPED SCKClass *cls = [[SCKClass alloc] initWithClass: classList[i]];
		[bundleClasses setObject: cls forKey: [cls name]];
		NSBundle *b = [NSBundle bundleForClass: classList[i]];
		if (nil == b)
		{
			continue;
		}
		SCKBundle *bundle = [bundles objectForKey: [b bundlePath]];
		if (nil  == bundle)
		{
			bundle = [SCKBundle new];
			bundle.name = [b bundlePath];
			[bundles setObject: bundle forKey: [b bundlePath]];
		}
		[bundle.classes addObject: cls];
	}
	free(classList);
	return self;
}

- (NSMutableDictionary*)programComponentsFromFilesForKey: (NSString*)key
{
	NSMutableDictionary *components = [NSMutableDictionary new];
	for (SCKSourceFile *file in [files objectEnumerator])
	{
		[components addEntriesFromDictionary: [file valueForKey: key]];
	}
	return components;
}

- (NSDictionary*)classes
{
	NSMutableDictionary* classes = [self programComponentsFromFilesForKey: @"classes"];
	[classes addEntriesFromDictionary: bundleClasses];
	return classes;
}

- (NSDictionary*)functions
{
	return [self programComponentsFromFilesForKey: @"functions"];
}

- (NSDictionary*)enumerationValues
{
	return [self programComponentsFromFilesForKey: @"enumerationValues"];
}

- (NSDictionary*)enumerations
{
	return [self programComponentsFromFilesForKey: @"enumerations"];
}

- (NSDictionary*)globals
{
	return [self programComponentsFromFilesForKey: @"globals"];
}

- (NSDictionary*)macros
{
	return [self programComponentsFromFilesForKey: @"macros"];
}

- (SCKIndex*)indexForFileExtension: (NSString*)extension
{
	return [indexes objectForKey: extension];
}
- (SCKSourceFile*)sourceFileForPath: (NSString*)aPath
{
	NSString *path = [aPath stringByStandardizingIntoAbsolutePath];

	SCKSourceFile *file = [files objectForKey: path];
	if (nil != file)
	{
		return file;
	}

	NSString *extension = [path pathExtension];
	file = [[fileClasses objectForKey: extension] fileUsingIndex: [indexes objectForKey: extension]];
	file.fileName = path;
	file.collection = self;
	[file reparse];
	if (nil != file)
	{
		[files setObject: file forKey: path];
	}
	else
	{
		NSLog(@"Failed to load %@", path);
	}
	return file;
}
@end
