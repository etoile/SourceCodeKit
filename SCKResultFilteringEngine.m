//
//  SCKResultFilteringEngine.m
//  SourceCodeKit
//
//  Created by Alex on 28/05/14.
//  Copyright (c) 2014 Étoilé. All rights reserved.
//

#import "SCKResultFilteringEngine.h"
#import <EtoileFoundation/EtoileFoundation.h>


@implementation SCKResultFilteringEngine

- (id)init
{
    SUPERINIT;
    cachedMethods = [[NSMutableDictionary alloc] init];
    return self;
}

- (void)cacheResults:(SCKCodeCompletionResult*)aSetOfResults forClassName:(NSString*)aClassName
{
    NSEnumerator *e = [cachedMethods keyEnumerator];
    NSString *key;
    
    while (key = [e nextObject])
    {
        if ([key isEqualToString:aClassName])
        {
            return;
        }
    }
    
    NSArray *results = aSetOfResults.completions;
    [cachedMethods setObject:[results mutableCopy] forKey:aClassName];
}
@end
