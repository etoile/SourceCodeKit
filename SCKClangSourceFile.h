#include <Foundation/Foundation.h>
#include "SCKSourceFile.h"
#include <clang-c/Index.h>

@class SCKClangIndex;
@class NSMutableArray;
@class NSMutableAttributedString;

/**
 * SCKSourceFile implementation that uses clang to perform handle
 * [Objective-]C[++] files.
 */
@interface SCKClangSourceFile : SCKSourceFile
{
	/** Compiler arguments */
	NSMutableArray *args;
	/** Index shared between code files */
	SCKClangIndex *idx;
	/** libclang translation unit handle. */
	CXTranslationUnit translationUnit;
	CXFile file;
}
@property (nonatomic, readonly) NSMutableDictionary *classes;
@property (nonatomic, readonly) NSMutableDictionary *functions;
@property (nonatomic, readonly) NSMutableDictionary *globals;
@property (nonatomic, readonly) NSMutableDictionary *enumerations;
@property (nonatomic, readonly) NSMutableDictionary *enumerationValues;
@property (nonatomic, readonly) NSMutableDictionary *macros;
@property (nonatomic, readonly) NSMutableDictionary *protocols;
@end
