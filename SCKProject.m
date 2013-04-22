#import "SCKProject.h"
#import "SCKSourceFile.h"
#import "SCKSourceCollection.h"

@implementation SCKProject
{
	NSURL *directoryURL;
	SCKSourceCollection *sourceCollection;
	NSMutableArray *fileURLs;
	id <SCKProjectContent> projectContent;
}

@synthesize directoryURL, fileURLs;

- (id) initWithDirectoryURL: (NSURL *)aURL 
           sourceCollection: (SCKSourceCollection *)aSourceCollection;
{
	NILARG_EXCEPTION_TEST(aSourceCollection);
	SUPERINIT;
	ASSIGN(directoryURL, aURL);
	ASSIGN(sourceCollection, aSourceCollection);
	fileURLs = [NSMutableArray new];
	projectContent = [SCKFileBrowsingProjectContent new];
	return self;
}

- (void)addFileURL: (NSURL *)aURL
{
	NILARG_EXCEPTION_TEST(aURL);
	if ([fileURLs containsObject: aURL])
		return;

	[fileURLs addObject: aURL];
}

- (void)removeFileURL: (NSURL *)aURL
{
	NILARG_EXCEPTION_TEST(aURL);
	[fileURLs removeObject: aURL];
}

- (NSArray *)files
{
	NSMutableArray *files = [NSMutableArray new];

	for (NSURL *url in fileURLs)
	{
		NSString *resolvedFilePath = (directoryURL == nil ? [url path] :
			[[directoryURL path] stringByAppendingPathComponent: [url relativePath]]);
		SCKFile *file = [sourceCollection sourceFileForPath: 
			[resolvedFilePath stringByStandardizingPath]];

		[files addObject: file];
	}
	return files;
}

- (NSArray *)programComponentsForKey: (NSString *)key
{
	// NOTE: We could write...
	//NSDictionary *componentsByName = [[[self files] mappedCollection] valueForKey: key];
	//return [[[componentsByName mappedCollection] allValues] flattenedCollection];

	NSMutableArray *components = [NSMutableArray new];
	for (SCKSourceFile *file in [[self files]])
	{
		[components addObjectsFromArray: [[file valueForKey: key] allValues]];
	}
	return components;
}

- (NSArray *)classes
{
	return [self programComponentsForKey: @"classes"];
}

- (NSArray *)functions
{
	return [self programComponentsForKey: @"functions"];
}

- (NSArray *)globals
{
	return [self programComponentsForKey: @"globals"];
}

- (void)setContentClass: (Class)aClass
{
	INVALIDARG_EXCEPTION_TEST([aClass conformsToProtocol: @protocol(SCKProjectContent)]);
	projectContent = [aClass new];
}

- (Class)contentClass
{
	return [projectContent class];
}

- (id)content
{
	return [projectContent content];
}

@end

@implementation SCKFileBrowsingProjectContent

- (id)content
{
	return [self files];
}

@end

@implementation SCKSymbolBrowsingProjectContent

- (id)content
{
	return A([self classes], [self functions], [self globals]);
}

@end
