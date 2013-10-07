#import <Foundation/NSObject.h>

@class NSString, NSDate;

@interface A : NSObject
{
	NSString *text;
}

@property (nonatomic, retain) NSString *text;

- (BOOL)wakeUpAtDate: (NSDate *)aDate;
- (void)sleepLater: (NSUInteger)seconds;
+ (void)sleepNow;

@end


@interface B : A
{

}

@property (nonatomic, retain) NSString *text1;
@property (nonatomic, retain) NSString *text2;
@property (nonatomic, retain) NSString *text3;


- (void)bip: (id)sender;

@end

@interface C
{
	NSString *ivar1;
	NSString *ivar2;
	NSString *ivar3;
}

- (void)hello;

@end
