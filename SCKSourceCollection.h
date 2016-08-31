/**
	Copyright (c) 2010-2012 David Chisnall
	Copyright (c) 2012 Nicolas Roard
	Copyright (c) 2012-2014 Quentin Mathe

	License:  MIT  (see COPYING)
 */

#import <Foundation/NSObject.h>

@class NSCache, NSDictionary, NSMutableDictionary, NSArray;
@class SCKIndex, SCKSourceFile, SCKClass, SCKProtocol, SCKFunction, SCKGlobal;
@class SCKEnumeration, SCKEnumerationValue;

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
 * The parsed enumerations in the source files.
 *
 * Unlike other symbol dictionaries, the scope of an enumeration is per file 
 * (there is no global namespace for enumeration names), for conveniency we 
 * provide this dictionary that contains all parsed enumerations merged 
 * together. 
 * 
 * If two enumeration names collide, the one that is returned in the 
 * dictionary is undefined. For this case, -[SCKClangSourceFile enumerations] 
 * must be used to retrieve the correct enumeration.
 */
@property (nonatomic, readonly) NSDictionary *enumerations;
/**
 * The parsed enumeration values in the source files.
 *
 * Unlike other symbol dictionaries, the scope of an enumeration value is per 
 * file (there is no global namespace for enumeration value names), for 
 * conveniency we provide this dictionary that contains all parsed enumeration 
 * values merged together.
 * 
 * If two enumeration value names collide, the one that is returned in the 
 * dictionary is undefined. For this case, -[SCKClangSourceFile enumerationValues] 
 * must be used to retrieve the correct enumeration.
 */
@property (nonatomic, readonly) NSDictionary *enumerationValues;

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
 * Adds a parsed enumeration to -enumerations.
 */
- (void)addEnumeration: (SCKEnumeration *)anEnum;
/**
 * Adds a parsed enumeration value to -enumerationValues.
 */
- (void)addEnumerationValue: (SCKEnumerationValue *)anEnumValue;

/**
 * Indicates whether -sourceFileForPath: should ignore symbols from included 
 * headers, or collect them as global symbols.
 *
 * If NO, methods such as -functionForName: return included symbols.
 *
 * By default, returns NO.
 */
@property (nonatomic, assign) BOOL ignoresIncludedSymbols;
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
