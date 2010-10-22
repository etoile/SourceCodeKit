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
/**
 * Something is wrong with the text for this range.  The value for this
 * attribute is a dictionary describing exactly what.
 */
EMIT_STRING(kSCKDiagnostic);
/**
 * The severity of the diagnostic.  An NSNumber from 1 (hint) to 5 (fatal
 * error).
 */
EMIT_STRING(kSCKDiagnosticSeverity);
/**
 * A human-readable string giving the text of the diagnostic, suitable for
 * display.
 */
EMIT_STRING(kSCKDiagnosticText);
