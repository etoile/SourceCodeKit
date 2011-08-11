#import "SourceCodeKit.h"
#import <Cocoa/Cocoa.h>
#import <EtoileFoundation/EtoileFoundation.h>

/**
 * Mapping from source file extensions to SCKSourceFile subclasses.
 */
static NSDictionary *fileClasses;

@interface SCKClangIndex : NSObject @end

@implementation SCKSourceCollection
@synthesize classes, bundles, globals, functions;
+ (void)initialize
{
	Class clang = NSClassFromString(@"SCKClangSourceFile");
	ASSIGN(fileClasses, D(clang, @"m",
	                      clang, @"cc",
	                      clang, @"c",
	                      clang, @"h",
	                      clang, @"cpp"));
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
	files = [NSCache new];
	bundles = [NSMutableDictionary new];
	classes = [NSMutableDictionary new];
	functions = [NSMutableDictionary new];
	globals = [NSMutableDictionary new];
	int count = objc_getClassList(NULL, 0);
	Class *classList = (__unsafe_unretained Class *)calloc(sizeof(Class), count);
	objc_getClassList(classList, count);
	for (int i=0 ; i<count ; i++)
	{
		STACK_SCOPED SCKClass *cls = [[SCKClass alloc] initWithClass: classList[i]];
		[classes setObject: cls forKey: cls.name];
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
- (SCKIndex*)indexForFileExtension: (NSString*)extension
{
	return [indexes objectForKey: extension];
}
- (SCKSourceFile*)sourceFileForPath: (NSString*)aPath
{
	SCKSourceFile *file = [files objectForKey: aPath];
	if (nil != file)
	{
		return file;
	}
	NSString *extension = [aPath pathExtension];
	file = [[fileClasses objectForKey: extension] fileUsingIndex: [indexes objectForKey: extension]];
	file.fileName = aPath;
	file.collection = self;
	[file reparse];
	if (nil == file)
	{
		NSLog(@"Failed to load %@", aPath);
	}
	return file;
}
@end
