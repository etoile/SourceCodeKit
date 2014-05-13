#import "SCKClangSourceFile.h"
#import "SourceCodeKit.h"
#import <Cocoa/Cocoa.h>
#import <EtoileFoundation/EtoileFoundation.h>
#include <time.h>

//#define NSLog(...)

/**
 * Converts a clang source range into an NSRange within its enclosing file.
 */
NSRange NSRangeFromCXSourceRange(CXSourceRange sr)
{
	unsigned start, end;
	CXSourceLocation s = clang_getRangeStart(sr);
	CXSourceLocation e = clang_getRangeEnd(sr);
	clang_getInstantiationLocation(s, 0, 0, 0, &start);
	clang_getInstantiationLocation(e, 0, 0, 0, &end);
	if (end < start)
	{
		NSRange r = {end, start-end};
		return r;
	}
	NSRange r = {start, end - start};
	return r;
}

static void freestring(CXString *str)
{
	clang_disposeString(*str);
}
#define SCOPED_STR(name, value)\
	__attribute__((unused))\
	__attribute__((cleanup(freestring))) CXString name ## str = value;\
	const char *name = clang_getCString(name ## str);

@implementation SCKSourceLocation

@synthesize file, offset;

- (id)initWithClangSourceLocation: (CXSourceLocation)sourceLocation
{
	return [self initWithClangSourceLocation: sourceLocation isMacro: NO];
}

- (id)initWithClangSourceLocation: (CXSourceLocation)sourceLocation isMacro: (bool)isMacro
{
	SUPERINIT;
	CXFile f;
	CXString fileName;
	
	if (!isMacro)
  	{
		clang_getExpansionLocation(sourceLocation, &f, 0, 0, &offset);
		fileName = clang_getFileName(f);
  	}
  	else
  	{	
		clang_getPresumedLocation(sourceLocation, &fileName, &offset, 0);
  	}

  	SCOPED_STR(fn, fileName);
  	file = [NSString stringWithUTF8String: fn];

  	return self;
}

- (NSString*)description
{
	return [NSString stringWithFormat: @"%@:%d", file, (int)offset];
}
@end

#ifdef GNUSTEP

/*
 * GNUstep has a few private methods in NSBundle that let you determine the
 * correct include path in a non-flattened filesystem setup. We need to expose
 * it here.
 */
@interface NSBundle (ExposeGNUstepInternals)
+ (NSString*)_gnustep_target_dir;
+ (NSString*)_library_combo;
@end

/**
 * Read the relevant environment variables and construct an array of -I
 * directives that the compiler should search for GNUstep headers.
 *
 * FIXME: This might not actually work with Windows style path-separators ('\').
 */
NSArray *GNUstepIncludeDirectories()
{
	NSDictionary *environment = [[NSProcessInfo processInfo] environment];
	NSString *pathList = [environment objectForKey: @"GNUSTEP_PATHLIST"];
	NSInteger length = [pathList length];
	if (0 == length)
	{
		return nil;
	}

	BOOL isFlattened = [[environment objectForKey: @"GNUSTEP_IS_FLATTENED"] boolValue];
	NSMutableArray *accumulator = [NSMutableArray array];
	NSScanner *scanner = [NSScanner scannerWithString: pathList];
	[scanner setCharactersToBeSkipped: [NSCharacterSet newlineCharacterSet]];
	NSCharacterSet *stopSet = [NSCharacterSet characterSetWithCharactersInString: @":\\"];
	NSMutableString *thisPath = [NSMutableString string];
	@autoreleasepool {
		while (NO == [scanner isAtEnd])
		{
			NSString *nextPart = nil;
			BOOL foundPath = [scanner scanUpToCharactersFromSet: stopSet
			                                           intoString: &nextPart];
			if (foundPath)
			{
				[thisPath appendString: nextPart];
			}
			NSInteger location = [scanner scanLocation];
			// If we encounter the escape char '\' we advance the scan location and
			// copy the two characters to the path list, but only if the escape char
			// is not the last character.
			if ((location < (length - 1))
			  && ((unichar)'\\' == [pathList characterAtIndex: (location)]))
			{
				NSString *twoChars = [pathList substringWithRange: NSMakeRange(location, 2)];
				[thisPath appendString: twoChars];
				[scanner setScanLocation: (location + 2)];
			}
			else
			{
				// The other only stop character is the proper delimiter ':', so we
				// know that the path is complete if we encounter everything but a
				// '\'. We thus add a copy to the accumulator and reset the string.
				[accumulator addObject: [thisPath copy]];
				[thisPath setString: @""];
				[scanner setScanLocation: (location + 1)];
			}
		}
	}

	// Fetch any remaining path (this might happen if a path ends with an
	// escape sequence)
	if (0 != [thisPath length])
	{
		[accumulator addObject: [thisPath copy]];
	}

	NSRange nullRange = NSMakeRange(0,0);
	[[accumulator map] stringByReplacingCharactersInRange: nullRange
	                                           withString: @"-I"];
	if (isFlattened)
	{
	   [[accumulator map] stringByAppendingPathComponent: @"Library/Headers"];
	}
	else
	{
		NSString *subDir = [@"Library/Headers" stringByAppendingPathComponent: [NSBundle _library_combo]];
		// These are the normal headers:
		[[accumulator map] stringByAppendingPathComponent: subDir];
		// And these are the architecture dependent ones
		[accumulator addObjectsFromArray: (NSArray*)[[accumulator mappedCollection] stringByAppendingPathComponent: [NSBundle _gnustep_target_dir]]];
	}
	return [accumulator copy];
}
#endif

@interface SCKClangIndex : NSObject
@property (readonly) CXIndex clangIndex;
//FIXME: We should have different default arguments for C, C++ and ObjC.
@property (nonatomic, copy) NSMutableArray *defaultArguments;
@end




@implementation SCKClangIndex
@synthesize clangIndex, defaultArguments;
- (id)init
{
	SUPERINIT;
	clang_toggleCrashRecovery(0);
	clangIndex = clang_createIndex(1, 1);

	/*
	 * NOTE: If BuildKit becomes usable, it might be sensible to store these
	 * defaults in the BuildKit configuration and let BuildKit generate the
	 * command line switches for us.
	 */
	NSString *plistPath = [[NSBundle bundleForClass: [SCKClangIndex class]]
	                                pathForResource: @"DefaultArguments"
	                                         ofType: @"plist"];

	NSData *plistData = [NSData dataWithContentsOfFile: plistPath];

	// Load the options required to compile GNUstep apps
	defaultArguments = [(NSArray*)[NSPropertyListSerialization propertyListFromData: plistData
	                                                               mutabilityOption: NSPropertyListImmutable
	                                                                         format: NULL
	                                                               errorDescription: NULL] mutableCopy];

#	ifdef GNUSTEP
	NSArray *gsIncludeDirs = GNUstepIncludeDirectories();
	if (nil != gsIncludeDirs)
	{
		[defaultArguments addObjectsFromArray: gsIncludeDirs];
	}
#	endif
	[defaultArguments addObject: @"-I/usr/lib/gcc/i686-linux-gnu/4.6/include-fixed/"];
	[defaultArguments addObject: @"-I/usr/lib/gcc/i686-linux-gnu/4.6/include/"];
	return self;
}
- (void)dealloc
{
	clang_disposeIndex(clangIndex);
}
@end
@interface SCKClangSourceFile ()
- (void)highlightRange: (CXSourceRange)r syntax: (BOOL)highightSyntax;
@end

@implementation SCKClangSourceFile

@synthesize functions, enumerations, enumerationValues, macros;

/*
static enum CXChildVisitResult findClass(CXCursor cursor, CXCursor parent, CXClientData client_data)
{
	if (CXCursor_ObjCClassRef == cursor.kind)
	{
		NSString **strPtr = (NSString**)client_data;
		SCOPED_STR(name, clang_getCursorSpelling(cursor));
		*strPtr = [NSString stringWithUTF8String: name];
		return CXChildVisit_Break;
	}
	return CXChildVisit_Continue;
}
*/

static NSString *classNameFromCategory(CXCursor category)
{
	__block NSString *className = nil;
	clang_visitChildrenWithBlock(category,
		^ enum CXChildVisitResult (CXCursor cursor, CXCursor parent)
		{
			if (CXCursor_ObjCClassRef == cursor.kind)
			{
				SCOPED_STR(name, clang_getCursorSpelling(cursor));
				className = [NSString stringWithUTF8String: name];
				return CXChildVisit_Break;
			}
			return CXChildVisit_Continue;
		} );
	return className;
}

static BOOL isIBOutletFromPropertyOrIvar(CXCursor cursor)
{
	__block BOOL isIBOutlet = NO;

	clang_visitChildrenWithBlock(cursor,
		^ enum CXChildVisitResult (CXCursor subcursor, CXCursor parent)
		{
			if (CXCursor_IBOutletAttr == subcursor.kind)
			{
				isIBOutlet = YES;
				return CXChildVisit_Break;
			}
			return CXChildVisit_Continue;
		});
	return isIBOutlet;
}

- (void) setLocation: (SCKSourceLocation*)aLocation
            forClass: (NSString*)aClassName
      withSuperclass: (NSString*)aSuperclassName
        isDefinition: (BOOL)isDefinition
isForwardDeclaration: (BOOL)isForwardDeclaration
{
	SCKClass *class = [[self collection] classForName: aClassName];

	if (isForwardDeclaration)
	{
		ETAssert(aSuperclassName == nil && isDefinition == NO);
		return;
	}

	// If we are parsing the definition, the superclass name is nil
	if (aSuperclassName != nil)
	{
		[class setSuperclass: [[self collection] classForName: aSuperclassName]];
	}

	if (isDefinition)
	{
		[class setDefinition: aLocation];
	}
	else
	{
		[class setDeclaration: aLocation];
	}
}

- (void)setLocation: (SCKSourceLocation*)aLocation
        forCategory: (NSString*)aCategoryName
       isDefinition: (BOOL)isDefinition
            ofClass: (NSString*)aClassName
{
	SCKClass *class = [[self collection] classForName: aClassName];
	SCKCategory *category = [[class categories] objectForKey: aCategoryName];

	if (nil == category)
	{
		category = [SCKCategory new];
		[category setName: aCategoryName];
		[category setParent: class];

		[[class categories] setObject: category forKey: aCategoryName];
	}

	if (isDefinition)
	{
		[category setDefinition: aLocation];
	}
	else
	{
		[category setDeclaration: aLocation];
	}
}

- (void)setLocation: (SCKSourceLocation*)aLocation
          forMethod: (NSString*)methodName
   withTypeEncoding: (NSString*)typeEncoding
      isClassMethod: (BOOL)isClassMethod
       isDefinition: (BOOL)isDefinition
            inClass: (NSString*)className
           category: (NSString*)categoryName
{
	SCKClass *cls = [[self collection] classForName: className];
	NSMutableDictionary *methods = cls.methods;
	SCKCategory *cat = nil;

	if (nil != categoryName)
	{
		cat = [cls.categories objectForKey: categoryName];
		ETAssert(cat != nil);

		methods = cat.methods;
	}

	SCKMethod *m = [methods objectForKey: methodName];

	if (nil == m)
	{
		m = [SCKMethod new];
		[m setName: methodName];
		[m setTypeEncoding: typeEncoding];
		[m setIsClassMethod: isClassMethod];
		[m setParent: cls];

		[[cat methods] setObject: m forKey: methodName];
		[[cls methods] setObject: m forKey: methodName];
	}

	if (isDefinition)
	{
		m.definition = aLocation;
	}
	else
	{
		m.declaration = aLocation;
	}
}

- (SCKFunction*)functionForName: (NSString*)aName
{
	SCKFunction *function = [functions objectForKey: aName];

	if (nil != function)
	{
		return function;
	}

	function = [SCKFunction new];
	[function setName: aName];
	[functions setObject: function forKey: aName];
	return function;
}

- (void)setLocation: (SCKSourceLocation*)l
        forFunction: (NSString*)name
   withTypeEncoding: (NSString*)type
           isStatic: (BOOL)isStatic
       isDefinition: (BOOL)isDefinition
{
	BOOL isIncludedFunction = (![[l file] isEqualToString: [self fileName]]);

	if (isIncludedFunction)
	{
		return;
	}

	id owner = (isStatic ? self : [self collection]);
	SCKFunction *function = [owner functionForName: name];

	[function setTypeEncoding: type];

	if (isDefinition)
	{
		function.definition = l;
	}
	else
	{
		function.declaration = l;
	}

	//NSLog(@"Found %@ function %@ (%@) %@ at %@", (isStatic ? @"static" : @"global"), [function name], [function typeEncoding], (isDefinition ? @"defined" : @"declared"), l);
}

- (void)setLocation: (SCKSourceLocation*)l
        forVariable: (NSString*)name
   withTypeEncoding: (NSString*)type
       isDefinition: (BOOL)isDefinition
{
	SCKGlobal *variable = [[self collection] globalForName: name];

	[variable setTypeEncoding: type];

	if (isDefinition)
	{
		variable.definition = l;
	}
	else
	{
		variable.declaration = l;
	}

	//NSLog(@"Found %@ variable %@ (%@) %@ at %@", (isStatic ? @"static" : @"global"), [variable name], [variable typeEncoding], (isDefinition ? @"defined" : @"declared"), l);
}

#if CINDEX_VERSION < 21
#define CXObjCPropertyAttrKind int
#endif

- (void)setLocation: (SCKSourceLocation*)sourceLocation
        forProperty: (NSString*)propertyName
   withTypeEncoding: (NSString*)typeEncoding
         attributes: (CXObjCPropertyAttrKind)propertyAttributes
         isIBOutlet: (BOOL)isIBOutlet
            inClass: (NSString *)className
{
	SCKClass *class = [[self collection] classForName: className];
	SCKProperty *property = [class propertyForName: propertyName];

	if (nil == property)
	{
		property = [SCKProperty new];
		[property setName: propertyName];
		[property setParent: class];

		[[class properties] addObject: property];
	}

	// TODO: Convert CXObjCPropertyAttrKind into a SCK equivalent enum
	[property setTypeEncoding: typeEncoding];
	[property setIsIBOutlet: isIBOutlet];
	[property setDeclaration: sourceLocation];
}

- (void)setLocation: (SCKSourceLocation*)sourceLocation
           forMacro: (NSString*)macroName
{
	SCKMacro *macro = [macros objectForKey: macroName];
  	BOOL isIncludedMacro = (![[sourceLocation file] isEqualToString: fileName]);

  	if (isIncludedMacro)
  	{
    		return;
  	}

	if (nil == macro)
	{
		macro = [SCKMacro new];
		[macro setName: macroName];
		[macros setObject: macro forKey: macroName];
	}

	[macro setDefinition: sourceLocation];
	[macro setDeclaration: sourceLocation];
}

- (void)setLocation: (SCKSourceLocation*)sourceLocation
            forIvar: (NSString*)ivarName
   withTypeEncoding: (NSString*)typeEncoding
         isIBOutlet: (BOOL)isIBOutlet
            inClass: (NSString*)className
{
	SCKClass *class = [[self collection] classForName: className];
	SCKIvar *ivar = [class ivarForName: ivarName];

	if (nil == ivar)
	{
		ivar = [SCKIvar new];
		[ivar setName: ivarName];
		[ivar setTypeEncoding: typeEncoding];
		[ivar setIsIBOutlet: isIBOutlet];
		[ivar setParent: class];

		[[class ivars] addObject: ivar];
	}

	[ivar setDeclaration: sourceLocation];
}

- (void) setLocation: (SCKSourceLocation*)sourceLocation
         forProtocol: (NSString*)protocolName
isForwardDeclaration: (BOOL)isForwardDeclaration
{
	SCKProtocol *protocol = [[self collection] protocolForName: protocolName];

	if (isForwardDeclaration)
	{
		return;
	}
	[protocol setDeclaration: sourceLocation];
	[protocol setDefinition: sourceLocation];
}

- (void)setLocation: (SCKSourceLocation*)sourceLocation
          forMethod: (NSString*)methodName
   withTypeEncoding: (NSString*)typeEncoding
      isClassMethod: (BOOL)isClassMethod
		 isRequired: (BOOL)isRequired
       isDefinition: (BOOL)isDefinition
         inProtocol: (NSString*)protocolName
{
	SCKProtocol *protocol = [[self collection] protocolForName: protocolName];
	SCKMethod *method = nil;

	if (isRequired)
	{
		method = [[protocol requiredMethods] objectForKey: methodName];
	}
	else
	{
		method = [[protocol optionalMethods] objectForKey: methodName];
	}

	if (nil == method)
	{
		method = [SCKMethod new];
		[method setName: methodName];
		[method setTypeEncoding: typeEncoding];
		[method setIsClassMethod: isClassMethod];
		[method setParent: protocol];

		if (isRequired)
		{
			[[protocol requiredMethods] setObject: method forKey: methodName];
		}
		else
		{
			[[protocol optionalMethods] setObject: method forKey: methodName];
		}
	}

	if (isDefinition)
	{
		[method setDefinition: sourceLocation];
	}
	else
	{
		[method setDeclaration: sourceLocation];
	}
}

- (void)setLocation: (SCKSourceLocation*)sourceLocation
        forProperty: (NSString*)propertyName
   withTypeEncoding: (NSString*)typeEncoding
         attributes: (CXObjCPropertyAttrKind)attributes
         isIBOutlet: (BOOL)isIBOutlet
		 isRequired: (BOOL)isRequired
         inProtocol: (NSString*)protocolName
{
	SCKProtocol *protocol = [[self collection] protocolForName: protocolName];
	SCKProperty *property = nil;

	if (isRequired)
	{
		property = [protocol requiredPropertyForName: propertyName];
	}
	else
	{
		property = [protocol optionalPropertyForName: propertyName];
	}

	if (nil == property)
	{
		property = [SCKProperty new];
		[property setName: propertyName];
		[property setTypeEncoding: typeEncoding];
		[property setParent: protocol];

		if (isRequired)
		{
			[[protocol requiredProperties] addObject: property];
		}
		else
		{
			[[protocol optionalProperties] addObject: property];
		}
	}

	[property setDeclaration: sourceLocation];
}

- (void)setLocation: (SCKSourceLocation*)sourceLocation
        forProperty: (NSString*)propertyName
   withTypeEncoding: (NSString*)typeEncoding
         attributes: (CXObjCPropertyAttrKind)attributes
       isDefinition: (BOOL)isDefinition
            inClass: (NSString*)className
           category: (NSString*)categoryName
{
	SCKClass *class = [[self collection] classForName: className];
	SCKCategory *category = nil;

	if (nil != categoryName)
	{
		category = [[class categories] objectForKey: categoryName];
		ETAssert(category != nil);
	}

	SCKProperty *property = [category propertyForName: propertyName];

	if (nil == property)
	{
		property = [SCKProperty new];
		[property setName: propertyName];
		[property setTypeEncoding: typeEncoding];
		[property setParent: class];

		[[category properties] addObject: property];
		[[class properties] addObject: property];
	}

	// @dynamic is assumed definition
	if (isDefinition)
	{
		[property setDefinition: sourceLocation];
	}
	else
	{
		[property setDeclaration: sourceLocation];
	}
}

- (void)rebuildIndex
{
	if (0 == translationUnit) { return; }
	clang_visitChildrenWithBlock(clang_getTranslationUnitCursor(translationUnit),
		^ enum CXChildVisitResult (CXCursor cursor, CXCursor parent)
		{
			switch(cursor.kind)
			{
				default:
				{
#if 0
					SCOPED_STR(name, clang_getCursorSpelling(cursor));
					SCOPED_STR(kind, clang_getCursorKindSpelling(clang_getCursorKind(cursor)));
					NSLog(@"Unhandled cursor type: %s (%s)", kind, name);
#endif
					break;
				}
				case CXCursor_ObjCInterfaceDecl:
				{
					SCKSourceLocation *classLoc = [[SCKSourceLocation alloc]
						initWithClangSourceLocation: clang_getCursorLocation(cursor)];
					SCOPED_STR(className, clang_getCursorSpelling(cursor));
					NSString __block *superclassName = nil;
					BOOL __block isForwardDeclaration = NO;

					clang_visitChildrenWithBlock(cursor,
						^ enum CXChildVisitResult (CXCursor classCursor, CXCursor parent)
					{
						switch (classCursor.kind)
						{
							case CXCursor_ObjCClassRef:
							{
								isForwardDeclaration = YES;
								break;
							}
							case CXCursor_ObjCSuperClassRef:
							{
								SCOPED_STR(name, clang_getCursorSpelling(classCursor));
								superclassName = [NSString stringWithUTF8String: name];
								break;
							}
							case CXCursor_ObjCIvarDecl:
							{
								SCOPED_STR(name, clang_getCursorSpelling(classCursor));
								SCOPED_STR(typeEncoding, clang_getDeclObjCTypeEncoding(classCursor));
								SCKSourceLocation *sourceLocation = [[SCKSourceLocation alloc]
									initWithClangSourceLocation: clang_getCursorLocation(classCursor)];

								[self setLocation: sourceLocation
								          forIvar: [NSString stringWithUTF8String: name]
								 withTypeEncoding: [NSString stringWithUTF8String: typeEncoding]
								       isIBOutlet: isIBOutletFromPropertyOrIvar(classCursor)
								          inClass: [NSString stringWithUTF8String: className]];
								break;
							}
							case CXCursor_ObjCPropertyDecl:
							{
								SCOPED_STR(name, clang_getCursorSpelling(classCursor));
								SCOPED_STR(type, clang_getDeclObjCTypeEncoding(classCursor));
								SCKSourceLocation *sourceLocation = [[SCKSourceLocation alloc]
									initWithClangSourceLocation: clang_getCursorLocation(classCursor)];
								CXObjCPropertyAttrKind attributes = 0;
#if CINDEX_VERSION >= 21
								attributes = clang_Cursor_getObjCPropertyAttributes(classCursor, 0);
#endif

								[self setLocation: sourceLocation
								      forProperty: [NSString stringWithUTF8String: name]
								 withTypeEncoding: [NSString stringWithUTF8String: type]
								       attributes: attributes
								       isIBOutlet: isIBOutletFromPropertyOrIvar(classCursor)
								          inClass: [NSString stringWithUTF8String: className]];
								break;
							}
							case CXCursor_ObjCInstanceMethodDecl:
							case CXCursor_ObjCClassMethodDecl:
							{
								SCOPED_STR(name, clang_getCursorSpelling(classCursor));
								SCOPED_STR(type, clang_getDeclObjCTypeEncoding(classCursor));
								SCKSourceLocation *sourceLocation = [[SCKSourceLocation alloc]
									initWithClangSourceLocation: clang_getCursorLocation(classCursor)];

								[self setLocation: sourceLocation
								        forMethod: [NSString stringWithUTF8String: name]
								 withTypeEncoding: [NSString stringWithUTF8String: type]
								    isClassMethod: (classCursor.kind == CXCursor_ObjCClassMethodDecl)
								     isDefinition: clang_isCursorDefinition(classCursor)
								          inClass: [NSString stringWithUTF8String: className]
								         category: nil];
								break;
							}
							default:
								break;
						}
						return CXChildVisit_Continue;
					});

					/* We must visit the class cursor children to know whether
					   CXCursor_ObjCInterfaceDecl refers to a @interface or
					   @class declaration, and also to get the superclass and
					   protocol references. */
					[self setLocation: classLoc
					         forClass: [NSString stringWithUTF8String: className]
					   withSuperclass: superclassName
					     isDefinition: clang_isCursorDefinition(cursor)
						isForwardDeclaration: isForwardDeclaration];
					break;
				}
				case CXCursor_ObjCImplementationDecl:
				{
					SCKSourceLocation *classLoc = [[SCKSourceLocation alloc]
						initWithClangSourceLocation: clang_getCursorLocation(cursor)];
					SCOPED_STR(className, clang_getCursorSpelling(cursor));

					[self setLocation: classLoc
					         forClass: [NSString stringWithUTF8String: className]
					   withSuperclass: nil
					     isDefinition: clang_isCursorDefinition(cursor)
						 isForwardDeclaration: NO];

					clang_visitChildrenWithBlock(cursor,
						^ enum CXChildVisitResult (CXCursor classCursor, CXCursor parent)
					{
						SCOPED_STR(kind, clang_getCursorKindSpelling(clang_getCursorKind(classCursor)));

						if (CXCursor_ObjCInstanceMethodDecl == classCursor.kind
						 || CXCursor_ObjCClassMethodDecl == classCursor.kind)
						{
							SCOPED_STR(methodName, clang_getCursorSpelling(classCursor));
							SCOPED_STR(type, clang_getDeclObjCTypeEncoding(classCursor));
							SCOPED_STR(className, clang_getCursorSpelling(parent));
							SCKSourceLocation *l = [[SCKSourceLocation alloc]
								initWithClangSourceLocation: clang_getCursorLocation(classCursor)];

							[self setLocation: l
							        forMethod: [NSString stringWithUTF8String: methodName]
							 withTypeEncoding: [NSString stringWithUTF8String: type]
							    isClassMethod: (classCursor.kind == CXCursor_ObjCClassMethodDecl)
							     isDefinition: clang_isCursorDefinition(classCursor)
							          inClass: [NSString stringWithUTF8String: className]
							         category: nil];
						}
						return CXChildVisit_Continue;
					});
					break;
				}
				case CXCursor_ObjCCategoryDecl:
				case CXCursor_ObjCCategoryImplDecl:
				{
					SCKSourceLocation *categoryLoc = [[SCKSourceLocation alloc]
						initWithClangSourceLocation: clang_getCursorLocation(cursor)];
					SCOPED_STR(categoryName, clang_getCursorSpelling(cursor));
					NSString *className = classNameFromCategory(cursor);

					[self setLocation: categoryLoc
					      forCategory: [NSString stringWithUTF8String: categoryName]
					     isDefinition: clang_isCursorDefinition(cursor)
					          ofClass: className];

					clang_visitChildrenWithBlock(cursor,
						^ enum CXChildVisitResult (CXCursor categoryCursor, CXCursor parent)
					{
						switch (categoryCursor.kind)
						{
							case CXCursor_ObjCInstanceMethodDecl:
							case CXCursor_ObjCClassMethodDecl:
							{
								SCKSourceLocation *sourceLocation = [[SCKSourceLocation alloc]
									initWithClangSourceLocation: clang_getCursorLocation(categoryCursor)];
								SCOPED_STR(name, clang_getCursorSpelling(categoryCursor));
								SCOPED_STR(type, clang_getDeclObjCTypeEncoding(categoryCursor));

								[self setLocation: sourceLocation
								        forMethod: [NSString stringWithUTF8String: name]
								 withTypeEncoding: [NSString stringWithUTF8String: type]
								    isClassMethod: (CXCursor_ObjCClassMethodDecl == categoryCursor.kind)
						    		     isDefinition: clang_isCursorDefinition(cursor)
								          inClass: className
							  	         category: [NSString stringWithUTF8String: categoryName]];

								break;
							}
							case CXCursor_ObjCDynamicDecl:
							case CXCursor_ObjCPropertyDecl:
							{
								SCKSourceLocation *sourceLocation = [[SCKSourceLocation alloc]
									initWithClangSourceLocation: clang_getCursorLocation(categoryCursor)];
								SCOPED_STR(name, clang_getCursorSpelling(categoryCursor));
								SCOPED_STR(type, clang_getDeclObjCTypeEncoding(categoryCursor));
								CXObjCPropertyAttrKind attributes = 0;
#if CINDEX_VERSION >= 21
								attributes = clang_Cursor_getObjCPropertyAttributes(categoryCursor, 0);
#endif
								[self setLocation: sourceLocation
								      forProperty: [NSString stringWithUTF8String: name]
								 withTypeEncoding: [NSString stringWithUTF8String: type]
								       attributes: attributes
								     isDefinition: clang_isCursorDefinition(cursor)
								          inClass: className
								         category: [NSString stringWithUTF8String: categoryName]];
								break;

							}
							default:
								break;
 						}
						return CXChildVisit_Continue;
					});
					break;
				}
				case CXCursor_ObjCProtocolDecl:
				{
					BOOL isForwardDecl = (clang_equalCursors(cursor, clang_getCursorDefinition(cursor)) == 0);
					SCOPED_STR(protocolName, clang_getCursorSpelling(cursor));
					SCKSourceLocation *sourceLocation = [[SCKSourceLocation alloc]
							initWithClangSourceLocation: clang_getCursorLocation(cursor)];

					// NOTE: We could use CXCursor_ObjCProtocolDecl to parse protocol
					// forward declarations as we do with CXCursor_ObjCClassDecl
					[self setLocation: sourceLocation
					      forProtocol: [NSString stringWithUTF8String: protocolName]
						isForwardDeclaration: (clang_isCursorDefinition(cursor) == NO)];

					clang_visitChildrenWithBlock(cursor,
						^enum CXChildVisitResult(CXCursor protocolCursor, CXCursor parent)
					{
						SCOPED_STR(name, clang_getCursorSpelling(protocolCursor));
						SCOPED_STR(type, clang_getDeclObjCTypeEncoding(protocolCursor));
						SCKSourceLocation *location = [[SCKSourceLocation alloc]
							initWithClangSourceLocation: clang_getCursorLocation(protocolCursor)];
						BOOL isRequired = YES;

						switch (protocolCursor.kind)
						{
							case CXCursor_ObjCPropertyDecl:
							{
								CXObjCPropertyAttrKind attributes = 0;
#if CINDEX_VERSION >= 21
								attributes = clang_Cursor_getObjCPropertyAttributes(protocolCursor, 0);
								isRequired = (clang_Cursor_isObjCOptional(protocolCursor) == 0);
#else
#warning Your libclang does not support checking for optional property declarations
#endif
								[self setLocation: location
								      forProperty: [NSString stringWithUTF8String: name]
								 withTypeEncoding: [NSString stringWithUTF8String: type]
								       attributes: attributes
								       isIBOutlet: (CXCursor_IBOutletAttr == protocolCursor.kind)
									   isRequired: isRequired
								       inProtocol: [NSString stringWithUTF8String: protocolName]];

								break;
							}
							case CXCursor_ObjCInstanceMethodDecl:
							case CXCursor_ObjCClassMethodDecl:
							{
#if CINDEX_VERSION >= 21
								isRequired = (clang_Cursor_isObjCOptional(protocolCursor) == 0);
#else
#warning Your libclang does not support checking for optional method declarations
#endif
								[self setLocation: location
								        forMethod: [NSString stringWithUTF8String: name]
								 withTypeEncoding: [NSString stringWithUTF8String: type]
								    isClassMethod: (CXCursor_ObjCClassMethodDecl == protocolCursor.kind)
									   isRequired: isRequired
								     isDefinition: clang_isCursorDefinition(protocolCursor)
								       inProtocol: [NSString stringWithUTF8String: protocolName]];

								break;
							}
							default:
								break;
						}
						return CXChildVisit_Recurse;
					});
					break;
				}
				case CXCursor_FunctionDecl:
				{
					SCOPED_STR(name, clang_getCursorSpelling(cursor));
					SCOPED_STR(type, clang_getDeclObjCTypeEncoding(cursor));
					STACK_SCOPED SCKSourceLocation *l = [[SCKSourceLocation alloc]
						initWithClangSourceLocation: clang_getCursorLocation(cursor)];
					enum CXLinkageKind linkage = clang_getCursorLinkage(cursor);
					ETAssert(linkage != CXLinkage_NoLinkage);

					if (linkage == CXLinkage_Invalid)
					{
						NSLog(@"WARNING: no linkage infos for function %s in %@", name, self);
						break;
					}

					[self setLocation: l
					      forFunction: [NSString stringWithUTF8String: name]
					 withTypeEncoding: [NSString stringWithUTF8String: type]
					         isStatic: (linkage == CXLinkage_Internal)
					     isDefinition: clang_isCursorDefinition(cursor)];
					break;
				}
				case CXCursor_VarDecl:
				{
					enum CXLinkageKind linkage = clang_getCursorLinkage(cursor);
					ETAssert(linkage != CXLinkage_NoLinkage);

					// TODO: Parse static variables
					if (linkage != CXLinkage_Internal && linkage != CXLinkage_Invalid)
					{
						SCOPED_STR(name, clang_getCursorSpelling(cursor));
						SCOPED_STR(type, clang_getDeclObjCTypeEncoding(cursor));
						STACK_SCOPED SCKSourceLocation *l = [[SCKSourceLocation alloc]
							initWithClangSourceLocation: clang_getCursorLocation(cursor)];

						[self setLocation: l
						      forVariable: [NSString stringWithUTF8String: name]
						 withTypeEncoding: [NSString stringWithUTF8String: type]
						     isDefinition: clang_isCursorDefinition(cursor)];
					}
					break;
				}
				case CXCursor_MacroDefinition:
				{
					SCOPED_STR(macroName, clang_getCursorSpelling(cursor));

					SCKSourceLocation *sourceLocation = [[SCKSourceLocation alloc]
						initWithClangSourceLocation:clang_getCursorLocation(cursor) isMacro: YES];

					[self setLocation: sourceLocation
					         forMacro: [NSString stringWithUTF8String: macroName]];
					break;
				}
				case CXCursor_EnumDecl:
				{
					SCOPED_STR(enumName, clang_getCursorSpelling(cursor));
					NSString *name = [NSString stringWithUTF8String: enumName];
					SCKEnumeration *e = [enumerations objectForKey: name];
					__block BOOL foundType;
					if (e == nil)
					{
						e = [SCKEnumeration new];
						foundType = NO;
						e.name = name;
						e.declaration = [[SCKSourceLocation alloc] initWithClangSourceLocation: clang_getCursorLocation(cursor)];
						[enumerations setObject: e forKey: name];
						[[self collection] addEnumeration: e];
					}
					else
					{
						foundType = e.typeEncoding != nil;
					}
					clang_visitChildrenWithBlock(cursor,
						^ enum CXChildVisitResult (CXCursor enumCursor, CXCursor parent)
					{
						if (enumCursor.kind == CXCursor_EnumConstantDecl)
						{
							if (!foundType)
							{
								SCOPED_STR(type, clang_getDeclObjCTypeEncoding(enumCursor));
								foundType = YES;
								e.typeEncoding = [NSString stringWithUTF8String: type];
							}
							SCOPED_STR(valName, clang_getCursorSpelling(enumCursor));
							NSString *vName = [NSString stringWithUTF8String: valName];
							SCKEnumerationValue *v = [e.values objectForKey: vName];
							if (nil == v)
							{
								v = [SCKEnumerationValue new];
								v.name = vName;
								v.declaration = [[SCKSourceLocation alloc] initWithClangSourceLocation: clang_getCursorLocation(enumCursor)];
								v.longLongValue = clang_getEnumConstantDeclValue(enumCursor);
								[e.values setObject: v forKey: vName];
							}
							SCKEnumerationValue *ev = [enumerationValues objectForKey: vName];
							if (ev)
							{
								if (ev.longLongValue != v.longLongValue)
								{
									[enumerationValues setObject: [NSMutableArray arrayWithObjects: v, ev, nil]
									                      forKey: vName];
								}
							}
							else
							{
								[enumerationValues setObject: v
								                      forKey: vName];
								[[self collection] addEnumerationValue: v];
							}
						}
						return CXChildVisit_Continue;
					});
					break;
				}
			}
			if (0)//(cursor.kind == CXCursor_ObjCInstanceMethodDecl)
			{
				const char *type = clang_getCString(clang_getDeclObjCTypeEncoding(cursor));
			NSLog(@"Found definition of %s %s in %s %s (%s)\n",
					clang_getCString(clang_getCursorKindSpelling(cursor.kind)), clang_getCString(clang_getCursorUSR(cursor)),
					clang_getCString(clang_getCursorKindSpelling(parent.kind)), clang_getCString(clang_getCursorUSR(parent)), type);
			}
			//return CXChildVisit_Recurse;
			return CXChildVisit_Continue;
		});
}
- (id)initUsingIndex: (SCKIndex*)anIndex
{
	idx = (SCKClangIndex*)anIndex;
	NSAssert([idx isKindOfClass: [SCKClangIndex class]],
			@"Initializing SCKClangSourceFile with incorrect kind of index");
	args = [idx.defaultArguments mutableCopy];
	functions = [NSMutableDictionary new];
	macros = [NSMutableDictionary new];
	enumerations = [NSMutableDictionary new];
	enumerationValues = [NSMutableDictionary new];
	return self;
}
- (void)addIncludePath: (NSString*)includePath
{
	[args addObject: [NSString stringWithFormat: @"-I%@", includePath]];
	// After we've added an include path, we may change how the file is parsed,
	// so parse it again, if required
	if (NULL != translationUnit)
	{
		clang_disposeTranslationUnit(translationUnit);
		translationUnit = NULL;
		[self reparseWithOption: SCKParsingOptionNone];
	}
}

- (void)dealloc
{
	if (NULL != translationUnit)
	{
		clang_disposeTranslationUnit(translationUnit);
	}
}

- (void)reparseWithOption: (short)parsingOption
{
	//NSLog(@" ---> Parsing %@", [fileName lastPathComponent]);

	const char *fn = [fileName UTF8String];
	struct CXUnsavedFile unsaved[] = {
		{fn, [[source string] UTF8String], [source length]},
		{NULL, NULL, 0}};
	int unsavedCount = (source == nil) ? 0 : 1;
	const char *mainFile = fn;
	if ([@"h" isEqualToString: [fileName pathExtension]])
	{
		unsaved[unsavedCount].Filename = "/tmp/foo.m";
		unsaved[unsavedCount].Contents = [[NSString stringWithFormat: @"#import \"%@\"\n", fileName] UTF8String];
		unsaved[unsavedCount].Length = strlen(unsaved[unsavedCount].Contents);
		mainFile = unsaved[unsavedCount].Filename;
		unsavedCount++;
	}
	file = NULL;
	if (NULL == translationUnit)
	{
		unsigned argc = (unsigned)[args count];
		const char *argv[argc];
		int i=0;
		for (NSString *arg in args)
		{
			argv[i++] = [arg UTF8String];
		}
		translationUnit =
			//clang_createTranslationUnitFromSourceFile(idx.clangIndex, fn, argc, argv, 0, unsaved);
			clang_parseTranslationUnit(idx.clangIndex, mainFile, argv, argc, unsaved,
					unsavedCount, parsingOption);
					//CXTranslationUnit_Incomplete);
		file = clang_getFile(translationUnit, fn);
	}
	else
	{
		clock_t c1 = clock();
		//NSLog(@"Reparsing translation unit");
		if (0 != clang_reparseTranslationUnit(translationUnit, unsavedCount, unsaved, parsingOption))
		{
			clang_disposeTranslationUnit(translationUnit);
			translationUnit = 0;
		}
		else
		{
			file = clang_getFile(translationUnit, fn);
		}
		clock_t c2 = clock();
		//NSLog(@"Reparsing took %f seconds.",((double)c2 - (double)c1) / (double)CLOCKS_PER_SEC);
	}
	[self rebuildIndex];
}

- (void)lexicalHighlightFile
{
	CXSourceLocation start = clang_getLocation(translationUnit, file, 1, 1);
	CXSourceLocation end = clang_getLocationForOffset(translationUnit, file, (unsigned int)[source length]);
	[self highlightRange: clang_getRange(start, end) syntax: NO];
}

- (void)highlightRange: (CXSourceRange)r syntax: (BOOL)highightSyntax;
{
	NSString *TokenTypes[] = {SCKTextTokenTypePunctuation, SCKTextTokenTypeKeyword,
		SCKTextTokenTypeIdentifier, SCKTextTokenTypeLiteral,
		SCKTextTokenTypeComment};
	if (clang_equalLocations(clang_getRangeStart(r), clang_getRangeEnd(r)))
	{
		NSLog(@"Range has no length!");
		return;
	}
	CXToken *tokens;
	unsigned tokenCount;
	clang_tokenize(translationUnit, r , &tokens, &tokenCount);
	//NSLog(@"Found %d tokens", tokenCount);
	if (tokenCount > 0)
	{
		CXCursor *cursors = NULL;
		if (highightSyntax)
		{
			cursors = calloc(sizeof(CXCursor), tokenCount);
			clang_annotateTokens(translationUnit, tokens, tokenCount, cursors);
		}
		for (unsigned i=0 ; i<tokenCount ; i++)
		{
			CXSourceRange sr = clang_getTokenExtent(translationUnit, tokens[i]);
			NSRange range = NSRangeFromCXSourceRange(sr);
			if (range.location > 0)
			{
				if ([[source string] characterAtIndex: range.location - 1] == '@')
				{
					range.location--;
					range.length++;
				}
			}
			if (highightSyntax)
			{
				id type;
				switch (cursors[i].kind)
				{
					case CXCursor_FirstRef... CXCursor_LastRef:
						type = SCKTextTypeReference;
						break;
					case CXCursor_MacroDefinition:
						type = SCKTextTypeMacroDefinition;
						break;
					case CXCursor_MacroInstantiation:
						type = SCKTextTypeMacroInstantiation;
						break;
					case CXCursor_FirstDecl...CXCursor_LastDecl:
						type = SCKTextTypeDeclaration;
						break;
					case CXCursor_ObjCMessageExpr:
						type = SCKTextTypeMessageSend;
						break;
					case CXCursor_DeclRefExpr:
						type = SCKTextTypeDeclRef;
						break;
					case CXCursor_PreprocessingDirective:
						type = SCKTextTypePreprocessorDirective;
						break;
					default:
						type = nil;
				}
				if (nil != type)
				{
					[source addAttribute: kSCKTextSemanticType
								   value: type
								   range: range];
				}
			}
			[source addAttribute: kSCKTextTokenType
			               value: TokenTypes[clang_getTokenKind(tokens[i])]
			               range: range];
		}
		clang_disposeTokens(translationUnit, tokens, tokenCount);
		free(cursors);
	}
}
- (void)syntaxHighlightRange: (NSRange)r
{
	CXSourceLocation start =
		clang_getLocationForOffset(translationUnit, file, (unsigned int)r.location);
	CXSourceLocation end = clang_getLocationForOffset(translationUnit, file,
		(unsigned int)(r.location + r.length));
	clock_t c1 = clock();
	[self highlightRange: clang_getRange(start, end) syntax: YES];
	clock_t c2 = clock();
	//NSLog(@"Highlighting took %f seconds.", ((double)c2 - (double)c1) / (double)CLOCKS_PER_SEC);
}
- (void)syntaxHighlightFile
{
	[self syntaxHighlightRange: NSMakeRange(0, [source length])];
}
- (void)collectDiagnostics
{
	// NSLog(@"Collecting diagnostics");
	unsigned diagnosticCount = clang_getNumDiagnostics(translationUnit);
	// unsigned opts = clang_defaultDiagnosticDisplayOptions();
	// NSLog(@"%d diagnostics found", diagnosticCount);
	for (unsigned i=0 ; i<diagnosticCount ; i++)
	{
		CXDiagnostic d = clang_getDiagnostic(translationUnit, i);
		unsigned s = clang_getDiagnosticSeverity(d);
		if (s > 0)
		{
			CXString str = clang_getDiagnosticSpelling(d);
			CXSourceLocation loc = clang_getDiagnosticLocation(d);
			unsigned rangeCount = clang_getDiagnosticNumRanges(d);
			// NSLog(@"%d ranges for diagnostic", rangeCount);
			if (rangeCount == 0) {
				//FIXME: probably somewhat redundant
				SCKSourceLocation* sloc = [[SCKSourceLocation alloc]
					 initWithClangSourceLocation: loc];
				NSDictionary *attr = D([NSNumber numberWithInt: (int)s], kSCKDiagnosticSeverity,
					 [NSString stringWithUTF8String: clang_getCString(str)], kSCKDiagnosticText);
				// NSRange r = NSRangeFromCXSourceRange(clang_getDiagnosticRange(d, 0));
				NSRange r = NSMakeRange(sloc->offset, 1);
				// NSLog(@"diagnostic: %@ %d, %d loc %d", attr, r.location, r.length, sloc->offset);
				[source addAttribute: kSCKDiagnostic
				               value: attr
				               range: r];
			}
			for (unsigned j=0 ; j<rangeCount ; j++)
			{
				NSRange r = NSRangeFromCXSourceRange(clang_getDiagnosticRange(d, j));
				NSDictionary *attr = D([NSNumber numberWithInt: (int)s], kSCKDiagnosticSeverity,
					 [NSString stringWithUTF8String: clang_getCString(str)], kSCKDiagnosticText);
				// NSLog(@"Added diagnostic %@ for range: %@", attr, NSStringFromRange(r));
				[source addAttribute: kSCKDiagnostic
				               value: attr
				               range: r];
			}
			clang_disposeString(str);
		}
	}
}
- (SCKCodeCompletionResult*)completeAtLocation: (NSUInteger)location
{
	SCKCodeCompletionResult *result = [SCKCodeCompletionResult new];

	struct CXUnsavedFile unsavedFile;
	unsavedFile.Filename = [fileName UTF8String];
	unsavedFile.Contents = [[source string] UTF8String];
	unsavedFile.Length = [[source string] length];

	CXSourceLocation l = clang_getLocationForOffset(translationUnit, file, (unsigned)location);
	unsigned line, column;
	clang_getInstantiationLocation(l, file, &line, &column, 0);
	clock_t c1 = clock();

	int options = CXCompletionContext_AnyType |
			CXCompletionContext_AnyValue |
			CXCompletionContext_ObjCInterface;

	CXCodeCompleteResults *cr = clang_codeCompleteAt(translationUnit, [fileName UTF8String], line, column, &unsavedFile, 1, options);
	clock_t c2 = clock();
	NSLog(@"Complete time: %f\n",
	((double)c2 - (double)c1) / (double)CLOCKS_PER_SEC);
	for (unsigned i=0 ; i<clang_codeCompleteGetNumDiagnostics(cr) ; i++)
	{
		CXDiagnostic d = clang_codeCompleteGetDiagnostic(cr, i);
		unsigned fixits = clang_getDiagnosticNumFixIts(d);
		printf("Found %d fixits\n", fixits);
		if (1 == fixits)
		{
			CXSourceRange r;
			CXString str = clang_getDiagnosticFixIt(d, 0, &r);
			result.fixitRange = NSRangeFromCXSourceRange(r);
			result.fixitText = [[NSString alloc] initWithUTF8String: clang_getCString(str)];
			clang_disposeString(str);
			break;
		}
		clang_disposeDiagnostic(d);
	}
	NSMutableArray *completions = [NSMutableArray new];
	clang_sortCodeCompletionResults(cr->Results, cr->NumResults);
	//NSLog(@"we have %d results", cr->NumResults);
	for (unsigned i=0 ; i<cr->NumResults ; i++)
	{
		CXCompletionString cs = cr->Results[i].CompletionString;
		NSMutableAttributedString *completion = [NSMutableAttributedString new];
		NSMutableString *s = [completion mutableString];
		unsigned chunks = clang_getNumCompletionChunks(cs);
		for (unsigned j=0 ; j<chunks ; j++)
		{
			switch (clang_getCompletionChunkKind(cs, j))
			{
				case CXCompletionChunk_Optional:
				case CXCompletionChunk_TypedText:
				case CXCompletionChunk_Text:
				{
					CXString str = clang_getCompletionChunkText(cs, j);
					[s appendFormat: @"%s", clang_getCString(str)];
					clang_disposeString(str);
					break;
				}
				case CXCompletionChunk_Placeholder:
				{
					CXString str = clang_getCompletionChunkText(cs, j);
					[s appendFormat: @"<# %s #>", clang_getCString(str)];
					clang_disposeString(str);
					break;
				}
				case CXCompletionChunk_Informative:
				{
					CXString str = clang_getCompletionChunkText(cs, j);
					[s appendFormat: @"/* %s */", clang_getCString(str)];
					clang_disposeString(str);
					break;
				}
				case CXCompletionChunk_CurrentParameter:
				case CXCompletionChunk_LeftParen:
					[s appendString: @"("]; break;
				case CXCompletionChunk_RightParen:
					[s appendString: @"("]; break;
				case CXCompletionChunk_LeftBracket:
					[s appendString: @"["]; break;
				case CXCompletionChunk_RightBracket:
					[s appendString: @"]"]; break;
				case CXCompletionChunk_LeftBrace:
					[s appendString: @"{"]; break;
				case CXCompletionChunk_RightBrace:
					[s appendString: @"}"]; break;
				case CXCompletionChunk_LeftAngle:
					[s appendString: @"<"]; break;
				case CXCompletionChunk_RightAngle:
					[s appendString: @">"]; break;
				case CXCompletionChunk_Comma:
					[s appendString: @","]; break;
				case CXCompletionChunk_ResultType:
					break;
				case CXCompletionChunk_Colon:
					[s appendString: @":"]; break;
				case CXCompletionChunk_SemiColon:
					[s appendString: @";"]; break;
				case CXCompletionChunk_Equal:
					[s appendString: @"="]; break;
				case CXCompletionChunk_HorizontalSpace:
					[s appendString: @" "]; break;
				case CXCompletionChunk_VerticalSpace:
					[s appendString: @"\n"]; break;
			}
		}
		[completions addObject: completion];
	}
	result.completions = completions;
	clang_disposeCodeCompleteResults(cr);
	return result;
}
@end
