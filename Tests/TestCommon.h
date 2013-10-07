#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import "SCKSourceCollection.h"
#import "SCKIntrospection.h"

#define SA(x) [NSSet setWithArray: x]

@interface TestCommon : NSObject <UKTest>
{

}

- (void)parseSourceFilesIntoCollection: (SCKSourceCollection*)aSourceCollection;

@end
