#import <EtoileFoundation/Macros.h>

@class NSString;

/**
 * The type of the token.  This key indicates the type that lexical analysis
 * records for this token.  
 */
EMIT_STRING(kIDETextTokenType);
/**
 * Token is punctuation.
 */
EMIT_STRING(IDETextTokenTypePunctuation);
/**
 * Token is a keyword.
 */
EMIT_STRING(IDETextTokenTypeKeyword);
/**
 * Token is an identifier.
 */
EMIT_STRING(IDETextTokenTypeIdentifier);
/**
 * Token is a literal value.
 */
EMIT_STRING(IDETextTokenTypeLiteral);
/**
 * Token is a comment.
 */
EMIT_STRING(IDETextTokenTypeComment);
/**
 * The type that semantic analysis records for this
 */
EMIT_STRING(kIDETextSemanticType);
/**
 * Reference to a type declared elsewhere.
 */
EMIT_STRING(IDETextTypeReference);
/**
 * Instantiation of a macro.
 */
EMIT_STRING(IDETextTypeMacroInstantiation);
/**
 * Definition of a macro.
 */
EMIT_STRING(IDETextTypeMacroDefinition);
/**
 * A declaration.
 */
EMIT_STRING(IDETextTypeDeclaration);
/**
 * A message send expression.
 */
EMIT_STRING(IDETextTypeMessageSend);
/**
 * A reference to a declaration.
 */
EMIT_STRING(IDETextTypeDeclRef);
/**
 * A preprocessor directive, such as #import or #include.
 */
EMIT_STRING(IDETextTypePreprocessorDirective);
