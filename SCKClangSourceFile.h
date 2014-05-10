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
	NSMutableDictionary *functions;
	NSMutableDictionary *enumerations;
	NSMutableDictionary *enumerationValues;
	NSMutableDictionary *macros;
	NSMutableDictionary *variables;
}

@property (nonatomic, readonly) NSDictionary *functions;
@property (nonatomic, readonly) NSDictionary *enumerations;
@property (nonatomic, readonly) NSDictionary *enumerationValues;
@property (nonatomic, readonly) NSDictionary *macros;
@property (nonatomic, readonly) NSDictionary *variables;

@end
