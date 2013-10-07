#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import "SCKSourceCollection.h"
#import "SCKIntrospection.h"
#import "SourceCodeKit/SourceCodeKit.h"

#define SA(x) [NSSet setWithArray: x]

@interface TestCommon : NSObject <UKTest>
{
	SCKClangSourceFile *clangParsingForInterface;
	SCKClangSourceFile *clangParsingForImplementation;
}

- (void)parseSourceFilesIntoCollection: (SCKSourceCollection*)aSourceCollection;

@end
