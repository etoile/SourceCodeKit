#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class SCKSourceCollection;

/**
 * SCKProject represents an IDE project that tracks several source files usually 
 * put together in a directory.
 *
 * In addition, SCKProject provides access to the program components declared 
 * in the project files. See -classes, -functions and -globals.
 *
 * Custom presentation in the IDE source list (or similar UI) are supported by 
 * setting a custom project content class, that implements the collection 
 * protocols on the behalf of SCKProject instance. The collection returned by
 * -content depends on the class set with -setContentClass:.
 */
@interface SCKProject : NSObject //<ETCollection, ETCollectionMutation>

/**
 * <init />
 * Initializes and returns a new project based on the directory URL (to resolve 
 * relative paths) and the provided source collection to retrieve the SCKFile 
 * objects.
 *
 * A source collection can be shared between several projects (it caches SCKFile 
 * objects).
 *
 * When aSourceCollection is nil, raises a NSInvalidArgumentException.
 */
- (id) initWithDirectoryURL: (NSURL *)aURL 
           sourceCollection: (SCKSourceCollection *)aSourceCollection;

/**
 * The project directory URL used to resolve relative paths (such as -fileURLs).
 */
@property (nonatomic, readonly) NSURL *directoryURL;
/** 
 * Returns the URLs of the files that belong to the project.
 */
@property (nonatomic, readonly) NSURL *fileURLs;

/**
 * Adds the file that corresponds to the URL to the project.
 *
 * When the URL is nil, raises a NSInvalidArgumentException.
 */
- (void)addFileURL: (NSURL *)aURL;
/**
 * Removes the file that corresponds to the URL from the project.
 *
 * When the URL is nil, raises a NSInvalidArgumentException.
 */
- (void)removeFileURL: (NSURL *)aURL;

/**
 * The files that belong to the project.
 *
 * The returned array contains SCKFile objects.
 */ 
@property (nonatomic, readonly) NSArray *files;
/**
 * All the classes declared in the files that belong to the project.
 *
 * The returned array contains SCKClass objects.
 */ 
@property (nonatomic, readonly) NSArray *classes;
/**
 * All the functions declared in the files that belong to the project.
 *
 * The returned array contains SCKFunction objects.
 */ 
@property (nonatomic, readonly) NSArray *functions;
/**
 * All the global variables declared in the files that belong to the project.
 *
 * The returned array contains SCKGlobal objects.
 */ 
@property (nonatomic, readonly) NSArray *globals;

/**
 * The content class that controls the current content exposed through the 
 * collection protocols.
 *
 * The content class must conform to SCKProjectContent protocol.
 */ 
@property (nonatomic) Class contentClass;

@end


/**
 * Protocol to which SCKProject content class must conform to. 
 * See -[SCKProject setContentClass:].
 */
@protocol SCKProjectContent
- (id)content;
@end

/**
 * Content class to present the project files.
 */
@interface SCKFileBrowsingProjectContent : NSObject <SCKProjectContent>
@end

/**
 * Content class to present the project program components grouped into classes, 
 * functions and globals.
 */
@interface SCKSymbolBrowsingProjectContent : NSObject <SCKProjectContent>
@end
