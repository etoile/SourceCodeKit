//
//  SCKResultFilteringEngine.h
//  SourceCodeKit
//
//  Created by Alex on 28/05/14.
//  Copyright (c) 2014 Étoilé. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SCKCodeCompletionResult.h"


@interface SCKResultFilteringEngine : NSObject
{
    NSMutableDictionary *cachedMethods;
}

/**
 * This method caches all the methods of a clang code completed object.
 * Caching methods will avoid to call libclang for previous objects of
 * the same class previously code completed.
 * The "forClassName" argument can't be nil"
 */
- (void) cacheResults:(SCKCodeCompletionResult*)aSetOfResults forClassName:(NSString*)aClassName;

@end
