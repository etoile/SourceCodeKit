#import <EtoileFoundation/Macros.h>

@class NSString;

/**
 * The type of the token.  This key indicates the type that lexical analysis
 * records for this token.  
 */
EMIT_STRING(kSCKTextTokenType);
/**
 * Token is punctuation.
 */
EMIT_STRING(SCKTextTokenTypePunctuation);
/**
 * Token is a keyword.
 */
EMIT_STRING(SCKTextTokenTypeKeyword);
/**
 * Token is an identifier.
 */
EMIT_STRING(SCKTextTokenTypeIdentifier);
/**
 * Token is a literal value.
 */
EMIT_STRING(SCKTextTokenTypeLiteral);
/**
 * Token is a comment.
 */
EMIT_STRING(SCKTextTokenTypeComment);
/**
 * The type that semantic analysis records for this
 */
EMIT_STRING(kSCKTextSemanticType);
/**
 * Reference to a type declared elsewhere.
 */
EMIT_STRING(SCKTextTypeReference);
/**
 * Instantiation of a macro.
 */
EMIT_STRING(SCKTextTypeMacroInstantiation);
/**
 * Definition of a macro.
 */
EMIT_STRING(SCKTextTypeMacroDefinition);
/**
 * A declaration.
 */
EMIT_STRING(SCKTextTypeDeclaration);
/**
 * A message send expression.
 */
EMIT_STRING(SCKTextTypeMessageSend);
/**
 * A reference to a declaration.
 */
EMIT_STRING(SCKTextTypeDeclRef);
/**
 * A preprocessor directive, such as #import or #include.
 */
EMIT_STRING(SCKTextTypePreprocessorDirective);
