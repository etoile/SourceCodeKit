#import <Foundation/NSObject.h>

@class NSCache, NSMutableDictionary, NSArray;
@class SCKIndex, SCKSourceFile;

/**
 * A source collection encapsulates a group of (potentially cross-referenced)
 * source code files.  
 */
@interface SCKSourceCollection : NSObject
{
	NSMutableDictionary *indexes;
	/** Files that have already been created. */
	NSMutableDictionary *files; //TODO: turn back into NSCache
	NSMutableDictionary *bundleClasses;
}
@property (nonatomic, readonly, retain) NSMutableDictionary *classes;
@property (nonatomic, readonly, retain) NSMutableDictionary *bundles;
@property (nonatomic, readonly, retain) NSMutableDictionary *functions;
@property (nonatomic, readonly, retain) NSMutableDictionary *globals;
@property (nonatomic, readonly, retain) NSMutableDictionary *properties;
@property (nonatomic, readonly, retain) NSMutableDictionary *macros;
@property (nonatomic, readonly, retain) NSMutableDictionary *enumerations;
@property (nonatomic, readonly, retain) NSMutableDictionary *enumerationValues;
/**
 * Generates a new source file object corresponding to the specified on-disk
 * file.  The returned object is not guaranteed to be unique - subsequent calls
 * with the same argument will return the same object.
 */
- (SCKSourceFile*)sourceFileForPath: (NSString*)aPath;
- (SCKIndex*)indexForFileExtension: (NSString*)extension;
@end
