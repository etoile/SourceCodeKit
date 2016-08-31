/**
	Copyright (c) 2013 Quentin Mathe

	License:  MIT  (see COPYING)
 */

#import "AB.h"


int function1(int arg1, int arg2)
{
	return arg1 + arg2;
}

char function2(char arg1)
{
	return 'm';
}

static void function3(NSObject *arg1)
{
	return;
}

NSDate *kGlobal1 = nil;
NSString *kGlobal2 = @"Whatever";


@implementation A
@synthesize text;

- (BOOL)wakeUpAtDate: (NSDate *)aDate
{
	return YES;
}

- (void)sleepLater: (NSUInteger)seconds
{
	
}

+ (void)sleepNow
{
	
}

@end

@implementation A (AExtension)

@dynamic propertyInsideCategory;

- (void)methodInCategory
{
	
}

@end


@implementation B
@synthesize button, text2, text3;

- (void)bip: (id)sender
{
	
}

@end


@implementation C

- (void)hello
{
    
}

@end
