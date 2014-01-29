#import "SCKIntrospection.h"
#import "SCKClangSourceFile.h"
#import <EtoileFoundation/EtoileFoundation.h>
#include <objc/runtime.h>

@implementation SCKProgramComponent
@synthesize parent, declaration, definition, documentation, name;

- (BOOL)isForwardDeclaration
{
	return (declaration == nil);
}

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
	ivars = [NSMutableArray new];
	properties = [NSMutableArray new];
	return self;
}
- (id)initWithClass: (Class)cls
{
	if (nil == (self = [self init])) { return nil; }

	unsigned int count;

	Ivar *ivarList = class_copyIvarList(cls, &count);
	for (unsigned int i=0 ; i<count ; i++)
	{
		SCKIvar *ivar = [SCKIvar new];
		ivar.name = [NSString stringWithUTF8String: ivar_getName(ivarList[i])];
		[ivar setTypeEncoding: [NSString stringWithUTF8String: ivar_getTypeEncoding(ivarList[i])]];
		ivar.parent = self;
		[ivars addObject: ivar];
	}
	if (count>0)
	{
		free(ivarList);
	}

	Method *methodList = class_copyMethodList(cls, &count);
	for (unsigned int i=0 ; i<count ; i++)
	{
		SCKMethod *method = [SCKMethod new];
		method.name = [NSString stringWithUTF8String: sel_getName(method_getName(methodList[i]))];
		[method setTypeEncoding: [NSString stringWithUTF8String: method_getTypeEncoding(methodList[i])]];
		method.parent = self;
		[methods setObject: method forKey: method.name];
	}
	if (count>0)
	{
		free(methodList);
	}
    
	objc_property_t *propertyList = class_copyPropertyList(cls, &count);
	for (unsigned int i=0 ; i<count; i++)
	{
		SCKProperty *property = [SCKProperty new];
		[property setName: [NSString stringWithUTF8String: property_getName(propertyList[i])]];
		[property setTypeEncoding: [NSString stringWithUTF8String: property_getAttributes(propertyList[i])]];
		[property setParent: self];
		[properties addObject: property];
	}
	if (count>0)
	{
		free(propertyList);
	}
    
	self.name = [[NSString alloc] initWithUTF8String: class_getName(cls)];    
	return self;
}

- (SCKIvar*)ivarForName: (NSString*)name
{
	return [[ivars filteredCollectionWithBlock: ^ (SCKIvar *ivar) 
	{ 
		return [[ivar name] isEqualToString: name]; 
	}] firstObject];
}	

- (SCKProperty*)propertyForName: (NSString*)name
{
	return [[properties filteredCollectionWithBlock: ^ (SCKProperty *prop) 
	{ 
		return [[prop name] isEqualToString: name]; 
	}] firstObject];
}
	
@end

@implementation SCKProtocol
@synthesize requiredMethods, optionalMethods, requiredProperties, optionalProperties;

- (id)init
{
	SUPERINIT;
	optionalMethods = [NSMutableDictionary new];
	requiredMethods = [NSMutableDictionary new];
	optionalProperties = [NSMutableArray new];
	requiredProperties = [NSMutableArray new];
	return self;
}

- (SCKProperty*)requiredPropertyForName: (NSString*)name
{
	return [[requiredProperties filteredCollectionWithBlock: ^ (SCKProperty *prop) 
	{ 
		return [[prop name] isEqualToString: name]; 
	}] firstObject];
}

- (SCKProperty*)optionalPropertyForName: (NSString*)name
{
	return [[optionalProperties filteredCollectionWithBlock: ^ (SCKProperty *prop) 
	{ 
		return [[prop name] isEqualToString: name]; 
	}] firstObject];
}

@end

@implementation SCKCategory : SCKProgramComponent
@synthesize methods, properties;
- (id)init
{
	SUPERINIT;
	methods = [NSMutableDictionary new];
	properties = [NSMutableArray new];
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

- (SCKProperty*)propertyForName: (NSString*)name
{
	return [[properties filteredCollectionWithBlock: ^ (SCKProperty *prop) 
	{ 
		return [[prop name] isEqualToString: name]; 
	}] firstObject];
}

@end

@implementation SCKMethod
@synthesize isClassMethod;
- (NSString*)description
{
	return [NSString stringWithFormat: @"%c%@", isClassMethod ? '+' : '-', self.name];
}
@end

@implementation SCKTypedProgramComponent
@synthesize typeEncoding;
@end

@implementation SCKIvar @end
@implementation SCKFunction @end
@implementation SCKGlobal @end
@implementation SCKProperty
@synthesize attributes, isIBOutlet;
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
