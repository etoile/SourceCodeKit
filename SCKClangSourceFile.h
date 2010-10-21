#include <Foundation/NSObject.h>
#include <Foundation/NSGeometry.h>
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
@end
