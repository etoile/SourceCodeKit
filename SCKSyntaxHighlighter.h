#include <Foundation/NSObject.h>
#include <Foundation/NSGeometry.h>

@class NSMutableDictionary;
@class NSMutableAttributedString;

/**
 * The SCKSyntaxHighlighter class is responsible for mapping from the semantic
 * attributes defined by an SCKSourceFile subclass to (configurable)
 * presentation attributes.
 */
@interface SCKSyntaxHighlighter : NSObject
/**
 * Attributes to be applied to token types.
 */
@property (nonatomic, retain) NSMutableDictionary *tokenAttributes;
/**
 * Attributes to be applied to semantic types.
 */
@property (nonatomic, retain) NSMutableDictionary *semanticAttributes;
/**
 * Transforms a source string, replacing the semantic attributes with
 * presentation attributes.
 */
- (void)transformString: (NSMutableAttributedString*)source;
@end
