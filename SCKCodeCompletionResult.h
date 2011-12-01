#import <Foundation/Foundation.h>

@interface SCKCodeCompletionResult : NSObject
@property (nonatomic, retain) NSString *fixitText;
@property (nonatomic) NSRange fixitRange;
@property (nonatomic, retain) NSArray *completions;
@end
