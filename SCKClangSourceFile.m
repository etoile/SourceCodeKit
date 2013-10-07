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

- (id)initWithClangSourceLocation: (CXSourceLocation)l
{
	SUPERINIT;
	CXFile f;
	unsigned o;
	clang_getInstantiationLocation(l, &f, 0, 0, &o);
	offset = o;
	SCOPED_STR(fileName, clang_getFileName(f));
	file = [[NSString alloc] initWithUTF8String: fileName];
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

@synthesize classes, functions, globals, enumerations, enumerationValues, macros, protocols;

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

- (SCKClass*)classForName: (NSString*)className
{
	SCKClass *class = [classes objectForKey: className];

	if (Nil == class)
	{
		class = [SCKClass new];
		[class setName: className];
		[classes setObject: class forKey: className];
	}
	return class;
}

- (void)didParseClassNamed: (NSString*)aClassName
            superclassName: (NSString*)aSuperclassName
                atLocation: (SCKSourceLocation*)aLocation
{	
	SCKClass *class = [self classForName: aClassName];
	[class setSuperclass: [self classForName: aSuperclassName]];
}

- (void)setLocation: (SCKSourceLocation*)aLocation
          forMethod: (NSString*)methodName
		   withType: (NSString*)typeEncoding
            inClass: (NSString*)className
           category: (NSString*)categoryName
	  isClassMethod: (BOOL)isClassMethod
       isDefinition: (BOOL)isDefinition
{	
	SCKClass *cls = [classes objectForKey: className];
	if (nil == cls)
	{
		cls = [SCKClass new];
		cls.name = className;
		[classes setObject: cls forKey: className];
	}
	NSMutableDictionary *methods = cls.methods;
	if (nil != categoryName)
	{
		SCKCategory *cat = [cls.categories objectForKey: categoryName];
		if (nil == cat)
		{
			cat = [SCKCategory new];
			cat.name = categoryName;
			cat.parent = cls;
			[cls.categories setObject: cat forKey: categoryName];
		}
		methods = cat.methods;
	}
	SCKMethod *m = [methods objectForKey: methodName];
	if (nil == m)
	{
		m = [SCKMethod new];
		[m setName: methodName];
		[m setIsClassMethod: isClassMethod];
		[m setTypeEncoding: typeEncoding];
		[m setParent: cls];
		
		[[cls methods] addObject: m forKey: methodName];
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
- (void)setLocation: (SCKSourceLocation*)l
          forGlobal: (const char*)name
           withType: (const char*)type
         isFunction: (BOOL)isFunction
       isDefinition: (BOOL)isDefinition
{
	NSMutableDictionary *dict = isFunction ? functions : globals;
	NSString *symbol = [NSString stringWithUTF8String: name];

	SCKTypedProgramComponent *global = [dict objectForKey: symbol];
	STACK_SCOPED SCKTypedProgramComponent *g = nil;
	if (nil == global)
	{
		g = isFunction ? [SCKFunction new] : [SCKGlobal new];
		global = g;
		global.name = symbol;
		[global setTypeEncoding: [NSString stringWithUTF8String: type]];
	}
	if (isDefinition)
	{
		global.definition = l;
	}
	else
	{
		global.declaration = l;
	}

	//NSLog(@"Found %@ %@ (%@) %@ at %@", isFunction ? @"function" : @"global", global.name, [global typeEncoding], isDefinition ? @"defined" : @"declared", l);

	[dict setObject: global forKey: symbol];
}

#if CINDEX_VERSION < 21
#define CXObjCPropertyAttrKind int
#endif

- (void)setLocation: (SCKSourceLocation*)sourceLocation
        forProperty: (NSString*)propertyName
		 inProtocol: (NSString *)protocolName
           withType: (NSString*)typeOfProperty
         attributes: (CXObjCPropertyAttrKind)attributesOfProperty
         isIBOutlet: (BOOL)isIBOutlet
{
	SCKProtocol *protocol = [protocols objectForKey: protocolName];
	if (nil == protocol)
	{
		protocol = [SCKProtocol new];
		[protocol setName: protocolName];
		[protocols addObject: protocol forKey: protocolName];
	}
		
	SCKProperty *property = [[protocol requiredProperties] objectForKey: propertyName];
	if (nil == property)
	{
		property = [SCKProperty new];
		[property setName: propertyName];
		[property setParent: protocol];
		
		[[protocol requiredProperties] addObject: property forKey: propertyName];
	}

	[property setDefinition: sourceLocation];
	[property setDeclaration: sourceLocation];
}

- (void)setLocation: (SCKSourceLocation*)sourceLocation
        forProperty: (NSString*)propertyName
		   withType: (NSString *)typeEncoding
			inClass: (NSString *)className
         attributes: (CXObjCPropertyAttrKind)attributesOfProperty
         isIBOutlet: (BOOL)isIBOutlet
{
	SCKClass *class = [classes objectForKey: className];
	if (nil == class)
	{
		class = [SCKClass new];
		[class setName: className];
		[classes addObject: class forKey: className];
	}
	
	SCKProperty *property = [[class properties] objectForKey: propertyName];
	if (nil == property)
	{
		property = [SCKProperty new];
		[property setName: propertyName];
		[property setTypeEncoding: typeEncoding];
		[property setParent: class];
		
		[[class properties] addObject: property forKey: propertyName];
	}

	[property setDefinition: sourceLocation];
	[property setDeclaration: sourceLocation];
}


- (void)setLocation: (SCKSourceLocation*)sourceLocation
           forMacro: (NSString*)macroName
{
	SCKMacro *macro = [macros objectForKey: macroName];
	if (nil == macro)
	{
		macro = [SCKMacro new];
		[macro setName: macroName];
		[macros addObject: macro forKey: macroName];
	}
    
	[macro setDefinition: sourceLocation];
	[macro setDeclaration: sourceLocation];
}

- (void)setLocation: (SCKSourceLocation *)sourceLocation
		forProtocol: (NSString *)protocolName
	   isDifinition: (BOOL)isDefinition
{
	SCKProtocol *protocol = [protocols objectForKey: protocolName];
	if (nil == protocol)
	{
		protocol = [SCKProtocol new];
		[protocol setName: protocolName];
		
		[protocols addObject: protocol forKey: protocolName];
	}
	
	if (isDefinition)
	{
		[protocol setDefinition: sourceLocation];
	}
	else
	{
		[protocol setDeclaration: sourceLocation];
	}
}

- (void)setLocation: (SCKSourceLocation *)sourceLocation
		  forMethod: (NSString *)methodName
		 inProtocol: (NSString *)protocolName
	  isClassMethod: (BOOL)isClassMethod
	   isDefinition: (BOOL)isDefinition
{
	SCKProtocol *protocol = [protocols objectForKey: protocolName];
	if (nil == protocol)
	{
		protocol = [SCKProtocol new];
		[protocol setName: protocolName];
		[protocols addObject: protocol forKey: protocolName];
	}
	
	SCKMethod *method = [[protocol requiredMethods] objectForKey: methodName];
	if (nil == method)
	{
		method = [SCKMethod new];
		[method setName: methodName];
		[method setIsClassMethod: isClassMethod];
		[method setParent: protocol];
		
		[[protocol requiredMethods] addObject: method forKey: methodName];
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

- (void)setLocation: (SCKSourceLocation *)sourceLocation
			forIvar: (NSString *)ivarName
			inClass: (NSString *)className
   withTypeEncoding: (NSString *)type
{
	SCKClass *class = [classes objectForKey: className];
	if (nil == class)
	{
		class = [SCKClass new];
		[class setName: className];
		[classes addObject: class forKey: className];
	}
	
	SCKIvar *ivar = [[class ivars] objectForKey: ivarName];
	if (nil == ivar)
	{
		ivar = [SCKIvar new];
		[ivar setName: ivarName];
		[ivar setTypeEncoding: type];
		[ivar setParent: class];
		
		[[class ivars] addObject: ivar forKey: ivarName];
	}

	[ivar setDeclaration: sourceLocation];
}

- (void)setLocation: (SCKSourceLocation *)sourceLocation
		   forClass: (NSString *)className
	 withSuperClass: (NSString *)superClassName
{
	SCKClass *class = [self classForName: className];
	[class setSuperclass: [self classForName: superClassName]];
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

					clang_visitChildrenWithBlock(cursor,
						^ enum CXChildVisitResult (CXCursor classCursor, CXCursor parent)
						{
							switch (classCursor.kind)
							{
								case CXCursor_ObjCClassRef:
								{									
									SCOPED_STR(superClassName, clang_getCursorSpelling(classCursor));
									[self didParseClassNamed: [NSString stringWithUTF8String: className]
											  superclassName: [NSString stringWithUTF8String: superClassName]
												  atLocation: classLoc];
									
									break;
								}
								case CXCursor_ObjCSuperClassRef:
								{									
									NSString *superClassName = [NSString stringWithUTF8String: clang_getCString(clang_getCursorSpelling(classCursor))];
									SCKSourceLocation *sourceLocation = [[SCKSourceLocation alloc] initWithClangSourceLocation: clang_getCursorLocation(classCursor)];
									
									[self setLocation: sourceLocation
											 forClass: [NSString stringWithUTF8String: className]
									   withSuperClass: superClassName];
									
									break;
								}
								case CXCursor_ObjCInstanceMethodDecl:
								case CXCursor_ObjCClassMethodDecl:
								{									
									NSString *name = [NSString stringWithUTF8String: clang_getCString(clang_getCursorSpelling(classCursor))];
									NSString *type = [NSString stringWithUTF8String: clang_getCString(clang_getDeclObjCTypeEncoding(classCursor))];
									BOOL isClassMethod = (CXCursor_ObjCClassMethodDecl == classCursor.kind);
									SCKSourceLocation *sourceLocation = [[SCKSourceLocation alloc] initWithClangSourceLocation: clang_getCursorLocation(classCursor)];
									
									// FIXME: Retrieve method return type
									// FIXME: Retrieve method argument[s]

									[self setLocation: sourceLocation
											forMethod: name
											 withType: type
											  inClass: [NSString stringWithUTF8String: className]
											 category: nil
										isClassMethod: isClassMethod
										 isDefinition: clang_isCursorDefinition(classCursor)];
									
									break;
								}
								case CXCursor_ObjCIvarDecl:
								{									
									NSString *name = [NSString stringWithUTF8String: clang_getCString(clang_getCursorSpelling(classCursor))];
									NSString *type = [NSString stringWithUTF8String: clang_getCString(clang_getDeclObjCTypeEncoding(classCursor))];
									SCKSourceLocation *sourceLocation = [[SCKSourceLocation alloc] initWithClangSourceLocation: clang_getCursorLocation(classCursor)];
									
									[self setLocation: sourceLocation
											  forIvar: name
											  inClass: [NSString stringWithUTF8String: className]
									 withTypeEncoding: type];
									
									break;
								}
								case CXCursor_ObjCPropertyDecl:
								{
									SCOPED_STR(name, clang_getCursorSpelling(classCursor));
									SCOPED_STR(type, clang_getDeclObjCTypeEncoding(classCursor));
									CXObjCPropertyAttrKind attributes = 0;
#if CINDEX_VERSION >= 21
									attributes = clang_Cursor_getObjCPropertyAttributes(cursor, 0);
#endif
									BOOL isIBOutlet = (CXCursor_IBOutletAttr == classCursor.kind);
									SCKSourceLocation *sourceLocation = [[SCKSourceLocation alloc] initWithClangSourceLocation: clang_getCursorLocation(classCursor)];
									
									[self setLocation: sourceLocation
										  forProperty: [NSString stringWithUTF8String: name]
											 withType: [NSString stringWithUTF8String: type]
											  inClass: [NSString stringWithUTF8String: className]
										   attributes: attributes
										   isIBOutlet: isIBOutlet];
									break;
								}

								default:
									break;
							}
							return CXChildVisit_Continue;
						});
					break;
				}
				case CXCursor_ObjCImplementationDecl:
				{
					clang_visitChildrenWithBlock(clang_getTranslationUnitCursor(translationUnit),
						^ enum CXChildVisitResult (CXCursor classCursor, CXCursor parent)
						{							
							SCOPED_STR(className, clang_getCursorSpelling(parent));
							
							switch (classCursor.kind)
							{
								case CXCursor_ObjCInstanceMethodDecl:
								case CXCursor_ObjCClassMethodDecl:
								{
									NSString *name = [NSString stringWithUTF8String: clang_getCString(clang_getCursorSpelling(classCursor))];
									NSString *type = [NSString stringWithUTF8String: clang_getCString(clang_getDeclObjCTypeEncoding(classCursor))];
									BOOL isClassMethod = (CXCursor_ObjCClassMethodDecl == classCursor.kind);
									SCKSourceLocation *sourceLocation = [[SCKSourceLocation alloc] initWithClangSourceLocation: clang_getCursorLocation(classCursor)];
									
									// FIXME: Retrieve method return type
									// FIXME: Retrieve method argument[s]
									[self setLocation: sourceLocation
											forMethod: name
											 withType: type
											  inClass: [NSString stringWithUTF8String: className]
											 category: nil
										isClassMethod: isClassMethod
										 isDefinition: YES];
									
									break;
								}	
									
								default:
									break;
							}
							return CXChildVisit_Continue;
						});
					break;
				}
				case CXCursor_ObjCCategoryImplDecl:
				{
					clang_visitChildrenWithBlock(cursor,
						^ enum CXChildVisitResult (CXCursor categoryCursor, CXCursor parent)
					{						
						switch (categoryCursor.kind)
						{
							case CXCursor_ObjCInstanceMethodDecl:
							case CXCursor_ObjCClassMethodDecl:
							{
								NSString *methodName = [NSString stringWithUTF8String: clang_getCString(clang_getCursorSpelling(categoryCursor))];
								NSString *methodType = [NSString stringWithUTF8String: clang_getCString(clang_getDeclObjCTypeEncoding(categoryCursor))];
								NSString *categoryName = [NSString stringWithUTF8String: clang_getCString(clang_getCursorSpelling(parent))];
								NSString *className = classNameFromCategory(parent);
								BOOL isClassMethod = (CXCursor_ObjCClassMethodDecl == categoryCursor.kind);
								SCKSourceLocation *sourceLocation = [[SCKSourceLocation alloc] initWithClangSourceLocation: clang_getCursorLocation(categoryCursor)];
								
								// FIXME: Retrieve method return type
								// FIXME: Retrieve method argument[s]
								
								[self setLocation: sourceLocation
										forMethod: methodName
										 withType: methodType
										  inClass: className
										 category: categoryName
									isClassMethod: isClassMethod
									 isDefinition: clang_isCursorDefinition(categoryCursor)];
								
								break;
							}
								
							default:
								break;
						}
						return CXChildVisit_Continue;
					});
					break;
				}
				case CXCursor_FunctionDecl:
				case CXCursor_VarDecl:
				{
					if (clang_getCursorLinkage(cursor) == CXLinkage_External)
					{
						SCOPED_STR(name, clang_getCursorSpelling(cursor));
						SCOPED_STR(type, clang_getDeclObjCTypeEncoding(cursor));
						STACK_SCOPED SCKSourceLocation *l = [[SCKSourceLocation alloc] initWithClangSourceLocation: clang_getCursorLocation(cursor)];
						[self setLocation: l
						        forGlobal: name
						         withType: type
						       isFunction: (cursor.kind == CXCursor_FunctionDecl)
						     isDefinition: clang_isCursorDefinition(cursor)];
					}
					break;
				}
				case CXCursor_ObjCProtocolDecl:
				{
					NSString *protocolName = [NSString stringWithUTF8String:
						clang_getCString(clang_getCursorSpelling(cursor))];
					SCKSourceLocation *sourceLocation = [[SCKSourceLocation alloc] initWithClangSourceLocation: clang_getCursorLocation(cursor)];
					SCKProtocol *protocol = [protocols objectForKey: protocolName];
					
					if (clang_isCursorDefinition(clang_getCursorDefinition(cursor)))
					{
						if (nil == protocol)
						{
							[self setLocation: sourceLocation
								  forProtocol: protocolName
								 isDifinition: YES];
						}
						clang_visitChildrenWithBlock(cursor,
						^enum CXChildVisitResult(CXCursor protocolCursor, CXCursor parent)
						{
							NSString *name = [NSString stringWithUTF8String: clang_getCString(clang_getCursorSpelling(protocolCursor))];
							NSString *type = [NSString stringWithUTF8String: clang_getCString(clang_getDeclObjCTypeEncoding(protocolCursor))];
							SCKMethod *method = nil;
							SCKProperty *property = nil;
							
							// FIXME: It needs fixing when there's a proper API.
							switch (protocolCursor.kind)
							{
								case CXCursor_ObjCInstanceMethodDecl:
								case CXCursor_ObjCClassMethodDecl:
								{
									method = [SCKMethod new];
									[method setName: name];
									[method setTypeEncoding: type];
									BOOL isClassMethod = (CXCursor_ObjCClassMethodDecl == protocolCursor.kind);
									[method setIsClassMethod: isClassMethod];
									
									[self setLocation: sourceLocation
											forMethod: [method name]
										   inProtocol: protocolName
										isClassMethod: isClassMethod
										 isDefinition: clang_isCursorDefinition(protocolCursor)];
									
									[[protocol requiredMethods] setObject: method forKey:name];
									
									break;
								}
								case CXCursor_ObjCPropertyDecl:
								{
									SCOPED_STR(name, clang_getCursorSpelling(protocolCursor));
									SCOPED_STR(type, clang_getDeclObjCTypeEncoding(protocolCursor));
									CXObjCPropertyAttrKind attributes = 0;
#if CINDEX_VERSION >= 21
									attributes = clang_Cursor_getObjCPropertyAttributes(cursor, 0);
#endif
									BOOL isIBOutlet = (CXCursor_IBOutletAttr == protocolCursor.kind);
									SCKSourceLocation *sourceLocation = [[SCKSourceLocation alloc] initWithClangSourceLocation: clang_getCursorLocation(protocolCursor)];
									
									[self setLocation: sourceLocation
										  forProperty: [NSString stringWithUTF8String: name]
										   inProtocol: protocolName
											 withType: [NSString stringWithUTF8String: type]
										   attributes: attributes
										   isIBOutlet: isIBOutlet];
									break;
								}
								default:
									//ETAssertUnreachable();
									break;
							}
							
							return CXChildVisit_Recurse;
						});
					}
					else
					{
						if (nil == protocol)
						{
							[self setLocation: sourceLocation
								  forProtocol: protocolName
								 isDifinition: NO];
						}
					}
					
					break;
				}
				case CXCursor_MacroDefinition:
				{
					// FIXME: Retrieve documentation
					
					SCOPED_STR(macroName, clang_getCursorSpelling(cursor));

					SCKSourceLocation *sourceLocation = [[SCKSourceLocation alloc]
						initWithClangSourceLocation:clang_getCursorLocation(cursor)];

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
	classes = [NSMutableDictionary new];
	functions = [NSMutableDictionary new];
	globals = [NSMutableDictionary new];
	macros = [NSMutableDictionary new];
	enumerations = [NSMutableDictionary new];
	enumerationValues = [NSMutableDictionary new];
	protocols = [NSMutableDictionary new];
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
		[self reparse];
	}
}

- (void)dealloc
{
	if (NULL != translationUnit)
	{
		clang_disposeTranslationUnit(translationUnit);
	}
}

- (void)reparse
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
					unsavedCount,
					clang_defaultEditingTranslationUnitOptions());
					//CXTranslationUnit_Incomplete);
		file = clang_getFile(translationUnit, fn);
	}
	else
	{
		clock_t c1 = clock();
		//NSLog(@"Reparsing translation unit");
		if (0 != clang_reparseTranslationUnit(translationUnit, unsavedCount, unsaved, clang_defaultReparseOptions(translationUnit)))
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

