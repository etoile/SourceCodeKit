//
//  SCKClassTracker.m
//  SourceCodeKit
//
//  Created by Alex on 12/05/14.
//  Copyright (c) 2014 Étoilé. All rights reserved.
//

#import "SCKClassTracker.h"

@implementation SCKClassTracker

- (void) setClassName:(NSString *)aName
{
    className = aName;
}

- (NSString*) getClassName
{
    return className;
}

- (NSArray*) getCachedMethods
{
    return cachedMethods;
}

- (void) cacheCompletionResultMethods:(NSArray *)results
{
    cachedMethods = [results copy];
}
@end
