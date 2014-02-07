#import <Foundation/NSObject.h>

@class NSString, NSDate, NSButton;

@class B;
@class Z;

#define MACRO1 1
#define MACRO2(...)({return __VA_ARGS})

int function1(int arg1, int arg2);
char function2(char arg1);

extern NSDate *kGlobal1;
extern NSString *kGlobal2;

enum enum1 {value1, value2, value3};
enum enum2 {value4, value5, value6};


@protocol Protocol1 <NSObject>
@required
@property NSString *string;
- (void)hi;
- (void)goodbye;
@optional
@property NSDate *date;
+ (void)farewell;
@end

@protocol Protocol2;

@protocol Protocol3 <Protocol1, Protocol2>
@end


@interface A : NSObject
{
	NSString *text;
}

@property (nonatomic, retain) NSString *text;

- (BOOL)wakeUpAtDate: (NSDate *)aDate;
- (void)sleepLater: (NSUInteger)seconds;
+ (void)sleepNow;

@end

@interface A (AExtension)

@property NSString *propertyInsideCategory;

- (void)methodInCategory;

@end


@interface B : A
{

}

@property (nonatomic, retain) IBOutlet NSButton *button;
@property (nonatomic, retain) NSString *text2;
@property (nonatomic, retain) NSString *text3;

- (void)bip: (id)sender;

@end


@interface C : B
{
	NSString *ivar1;
	IBOutlet NSString *ivar2;
	NSString *ivar3;
}

- (void)hello;

@end
