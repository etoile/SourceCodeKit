#import <Foundation/NSObject.h>

@class NSString, NSDate;

@interface A : NSObject
{
	NSString *text;
}

@property (nonatomic, retain) NSString *text;

- (BOOL)wakeUpAtDate: (NSDate *)aDate;
- (void)sleepWithDelay: (NSUInteger)seconds;
- (void)sleepNow;

@end


@interface B : A
{

}

- (void)bip: (id)sender;

@end
