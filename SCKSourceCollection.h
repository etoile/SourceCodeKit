#import <Foundation/NSObject.h>

@class NSCache, NSDictionary, NSMutableDictionary, NSArray;
@class SCKIndex, SCKSourceFile, SCKClass, SCKProtocol, SCKFunction, SCKGlobal;

/**
 * A source collection encapsulates a group of (potentially cross-referenced)
 * source code files.  
 */
@interface SCKSourceCollection : NSObject

@property (nonatomic, readonly) NSDictionary *files;
@property (nonatomic, readonly) NSDictionary *bundles;
@property (nonatomic, readonly) NSDictionary *classes;
@property (nonatomic, readonly) NSDictionary *protocols;
@property (nonatomic, readonly) NSDictionary *functions;
@property (nonatomic, readonly) NSDictionary *globals;

/**
 * Returns an existing class if one was already parsed under the same name in 
 * some other files, otherwise returns a new one.
 *
 * If a new SCKClass object is returned, subsequent uses will return the same 
 * instance until -clear is called.
 */
- (SCKClass*)classForName: (NSString*)aName;
/**
 * Returns an existing protocol if one was already parsed under the same name in 
 * some other files, otherwise returns a new one.
 *
 * If a new SCKProtocol object is returned, subsequent uses will return the same 
 * instance until -clear is called.
 */
- (SCKProtocol*)protocolForName: (NSString*)aName;
/**
 * Returns an existing global function if one was already parsed under the same 
 * name in some other files, otherwise returns a new one.
 *
 * If a new SCKFunction object is returned, subsequent uses will return the same 
 * instance until -clear is called.
 *
 * C static functions are available per file through -[SCKClangSourceFile functions].
 */
- (SCKFunction*)functionForName: (NSString*)aName;
/**
 * Returns an existing global variable if one was already parsed under the same 
 * name in some other files, otherwise returns a new one.
 *
 * If a new SCKGlobal object is returned, subsequent uses will return the same 
 * instance until -clear is called.
 */
- (SCKGlobal*)globalForName: (NSString*)aName;

/**
 * Generates a new source file object corresponding to the specified on-disk
 * file.  The returned object is not guaranteed to be unique - subsequent calls
 * with the same argument will return the same object.
 */
- (SCKSourceFile*)sourceFileForPath: (NSString*)aPath;
- (SCKIndex*)indexForFileExtension: (NSString*)extension;
/* 
 * Discards all the current parsing results.
 *
 * All source files and bundles previously parsed are discarded and clang indexes 
 * are recreated.
 *
 * Initially a SCKSourceCollection contains parsing results built by leveraging 
 * reflection at runtime. Objective-C constructs still available at runtime (e.g. 
 * classes but not categories) are collected from the bundles loaded in memory.
 *
 * To parse source files without combining Clang parsing results and Runtime 
 * parsing results together, you can call -clear on a new SCKSourceCollection 
 * (before calling -sourceFileForPath: for the first time).
 */
- (void)clear;

@end
