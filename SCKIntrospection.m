#import "SCKIntrospection.h"
#import "SCKClangSourceFile.h"
#import <EtoileFoundation/EtoileFoundation.h>
#include <objc/runtime.h>

@implementation SCKProgramComponent
@synthesize parent, declaration, definition, documentation, name;
- (NSString*)description
{
	return name;
}
@end

@implementation SCKBundle
@synthesize classes, functions;
- (id)init
{
	SUPERINIT;
	classes = [NSMutableArray new];
	functions = [NSMutableArray new];
	return self;
}
- (NSString*)description
{
	NSMutableString *str = [self.name mutableCopy];
	for (id function in functions)
	{
		[str appendFormat: @"\n\t%@", function];
	}
	for (id class in classes)
	{
		[str appendFormat: @"\n\t%@", class];
	}
	return str;
}
@end

@implementation SCKClass
@synthesize subclasses, superclass, categories, methods, ivars, properties;
- (NSString*)description
{
	NSMutableString *str = [self.name mutableCopy];
	for (id ivar in ivars)
	{
		[str appendFormat: @"\n\t\t%@", ivar];
	}
	for (id method in methods)
	{
		[str appendFormat: @"\n\t\t%@", method];
	}
	for (id property in properties)
	{
		[str appendFormat: @"\n\t\t%@", property];
	}

	return str;
}
- (id)init
{
	SUPERINIT;
	subclasses = [NSMutableArray new];
	categories = [NSMutableDictionary new];
	methods = [NSMutableDictionary new];
	ivars = [NSMutableDictionary new];
	properties = [NSMutableDictionary new];
	return self;
}
- (id)initWithClass: (Class)cls
{
	if (nil == (self = [self init])) { return nil; }

	unsigned int count;

	Ivar *ivarList = class_copyIvarList(cls, &count);
	for (unsigned int i=0 ; i<count ; i++)
	{
		NSString *name = [NSString stringWithUTF8String: ivar_getName(ivarList[i])];
		SCKIvar *ivar = [ivars objectForKey: name];
		if (nil == ivar)
		{
			ivar = [SCKIvar new];
			[ivar setName: name];
			[ivar setTypeEncoding: [NSString stringWithUTF8String: ivar_getTypeEncoding(ivarList[i])]];
			[ivar setOffset: ivar_getOffset(ivarList[i])];
			[ivar setParent: self];
			
			[ivars setObject: ivar forKey: name];
		}
	}
	if (count>0)
	{
		free(ivarList);
	}

	// FIXME: Doesn't return class methods.
	Method *methodList = class_copyMethodList(cls, &count);
	for (unsigned int i=0 ; i<count ; i++)
	{
		NSString *name = [NSString stringWithUTF8String: sel_getName(method_getName(methodList[i]))];
		SCKMethod *method = [methods objectForKey: name];
		if (nil == method)
		{
			method = [SCKMethod new];
			[method setName: name];
			[method setTypeEncoding: [NSString stringWithUTF8String:
									  method_getTypeEncoding(methodList[i])]];
			[method setReturnType: [NSString stringWithUTF8String: method_copyReturnType(methodList[i])]];
			
			[[method arguments] setValue: [NSString stringWithUTF8String: method_copyArgumentType(methodList[i], 0)] forKey: [method name]];
			
			[method setParent: self];
			
			[methods setObject: method forKey: name];
		}
	}
	if (count>0)
	{
		free(methodList);
	}
    
	objc_property_t *propertyList = class_copyPropertyList(cls, &count);
	for (unsigned int i=0 ; i<count; i++)
    {
		NSString *name = [NSString stringWithUTF8String: property_getName(propertyList[i])];
		SCKProperty *property = [properties objectForKey: name];
		if (nil == property)
		{
			property = [SCKProperty new];
			[property setName: name];
			[property setAttributes: [NSString stringWithUTF8String:
									  property_getAttributes(propertyList[i])]];
			[property setParent: self];
			
			[properties setObject: property forKey: name];
		}
    }
	if (count>0)
    {
        free(propertyList);
    }
    
	self.name = [[NSString alloc] initWithUTF8String: class_getName(cls)];    
	return self;
}
@end

@implementation SCKCategory : SCKProgramComponent
@synthesize methods, properties;
- (id)init
{
	SUPERINIT;
	methods = [NSMutableDictionary new];
	return self;
}
- (NSString*)description
{
	NSMutableString *str = [NSMutableString stringWithFormat: @"%@ (%@)", self.parent.name, self.name];
	for (id method in methods)
	{
		[str appendFormat: @"\n\t%@", method];
	}
	return str;
}
@end

@implementation SCKMethod
@synthesize isClassMethod, returnType;
- (NSString*)description
{
	return [NSString stringWithFormat: @"%c%@", isClassMethod ? '+' : '-', self.name];
}
@end

@implementation SCKTypedProgramComponent
@synthesize typeEncoding;
@end

@implementation SCKIvar
@synthesize offset;
@end
@implementation SCKFunction @end
@implementation SCKGlobal @end
@implementation SCKProperty
@synthesize attributes;
@end
@implementation SCKMacro @end
@implementation SCKEnumeration
@synthesize values;
@end
@implementation SCKEnumerationValue
@synthesize longLongValue, enumerationName;
- (NSString*)description
{
	return [NSString stringWithFormat: @"%@ (%lld)", self.name, longLongValue];
}
@end

@implementation SCKProtocol
@synthesize requiredMethods, optionalMethods, requiredProperties, optionalProperties;
@end