//
//  SCKClassTracker.h
//  SourceCodeKit
//
//  Created by Alex on 12/05/14.
//  Copyright (c) 2014 Étoilé. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * This class tracks code completed classes in a source file and caches the results
 * of the libclang code completion, avoiding to call libclang for previously 
 * code completed methods of the same class.
 */

@interface SCKClassTracker : NSObject
{
    NSString *className;
    NSArray *cachedMethods;
}

/**
 * Sets the name of a code completed class
 */

- (void) setClassName: (NSString*) aName;

/** 
 * Gets the name of a code competed class
 */

- (NSString*) getClassName;

/** 
 * Caches the results of a code completed class
 */

- (void) cacheCompletionResultMethods:(NSArray*)results;

/**
 * Returns the cachedMethods
 */

- (NSArray*) getCachedMethods;
@end
