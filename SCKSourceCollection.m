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
{
	NSMutableDictionary *indexes;
	/** Files that have already been created. */
	NSMutableDictionary *files; //TODO: turn back into NSCache
	NSMutableDictionary *bundles;
	NSMutableDictionary *bundleClasses;
	NSMutableDictionary *classes;
	NSMutableDictionary *protocols;
	NSMutableDictionary *functions;
	NSMutableDictionary *globals;
}

@synthesize files, bundles, classes, protocols, globals, functions;

+ (void)initialize
{
	Class clang = NSClassFromString(@"SCKClangSourceFile");
	fileClasses = [D(clang, @"m",
	                clang, @"cc",
	                clang, @"c",
	                clang, @"h",
	                clang, @"cpp") copy];
}

- (NSMutableDictionary *)newIndexes
{
	NSMutableDictionary *newIndexes = [NSMutableDictionary new];
	
	// A single clang index instance for all of the clang-supported file types
	id index = [SCKClangIndex new];
	[newIndexes setObject: index forKey: @"h"];
	[newIndexes setObject: index forKey: @"m"];
	[newIndexes setObject: index forKey: @"c"];
	[newIndexes setObject: index forKey: @"cpp"];
	[newIndexes setObject: index forKey: @"cc"];

	return newIndexes;
}

- (void)clear
{
	indexes = [self newIndexes];
	files = [NSMutableDictionary new];
	bundles = [NSMutableDictionary new];
	bundleClasses = [NSMutableDictionary new];
	classes = [NSMutableDictionary new];
	protocols = [NSMutableDictionary new];
	globals = [NSMutableDictionary new];
	functions = [NSMutableDictionary new];
}

- (id)init
{
	SUPERINIT
	
	[self clear];

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

- (SCKClass*)classForName: (NSString*)aName
{
	SCKClass *class = [classes objectForKey: aName];
	
	if (nil != class)
	{
		return class;
	}

	class = [SCKClass new];
	[class setName: aName];
	[classes setObject: class forKey: aName];
	
	return class;
}

- (SCKProtocol*)protocolForName: (NSString*)aName
{
	SCKProtocol *protocol = [protocols objectForKey: aName];

	if (nil != protocol)
	{
		return protocol;
	}
	
	protocol = [SCKProtocol new];
	[protocol setName: aName];
	[protocols setObject: protocol forKey: aName];
	return protocol;
}

- (SCKFunction*)functionForName: (NSString*)aName
{
	SCKFunction *function = [functions objectForKey: aName];
	
	if (nil != function)
	{
		return function;
	}
	
	function = [SCKFunction new];
	[function setName: aName];
	[functions setObject: function forKey: aName];
	return function;
}

- (SCKGlobal*)globalForName: (NSString*)aName
{
	SCKGlobal *global = [globals objectForKey: aName];
	
	if (nil != global)
	{
		return global;
	}
	
	global = [SCKGlobal new];
	[global setName: aName];
	[globals setObject: global forKey: aName];
	return global;
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
