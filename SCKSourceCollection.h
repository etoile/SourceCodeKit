#import <Foundation/NSObject.h>

@class NSCache;
@class NSMutableDictionary;
@class SCKIndex;
@class SCKSourceFile;

/**
 * A source collection encapsulates a group of (potentially cross-referenced)
 * source code files.  
 */
@interface SCKSourceCollection : NSObject
{
	NSMutableDictionary *indexes;
	/** Files that have already been created. */
	NSCache *files;
}
@property (nonatomic, readonly, retain) SCKIndex *index;
@property (nonatomic, readonly) NSMutableDictionary *classes;
@property (nonatomic, readonly) NSMutableDictionary *bundles;
/**
 * Generates a new source file object corresponding to the specified on-disk
 * file.  The returned object is not guaranteed to be unique - subsequent calls
 * with the same argument will return the same object.
 */
- (SCKSourceFile*)sourceFileForPath: (NSString*)aPath;
- (SCKIndex*)indexForFileExtension: (NSString*)extension;
@end
