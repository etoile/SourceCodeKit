#import "SourceCodeKit.h"
#import <EtoileFoundation/EtoileFoundation.h>

@implementation SCKProgramComponent
@synthesize parent;
- (void)dealloc
{
	[name release];
	[declaration release];
	[definition release];
	[documentation release];
	[super dealloc];
}
- (NSString*)description
{
	return name;
}
@end

@implementation SCKBundle
- (void)dealloc
{
	[classes release];
	[functions release];
	[super dealloc];
}
- (id)init
{
	SUPERINIT;
	classes = [NSMutableArray new];
	functions = [NSMutableArray new];
	return self;
}
- (NSString*)description
{
	NSMutableString *str = [[name mutableCopy] autorelease];
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
- (void)dealloc
{
	[subclasses release];
	[categories release];
	[methods release];
	[ivars release];
	[super dealloc];
}
- (NSString*)description
{
	NSMutableString *str = [[name mutableCopy] autorelease];
	for (id ivar in ivars)
	{
		[str appendFormat: @"\n\t\t%@", ivar];
	}
	for (id method in methods)
	{
		[str appendFormat: @"\n\t\t%@", method];
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
	return self;
}
- (id)initWithClass: (Class)cls
{
	if (nil == (self = [self init])) { return nil; }

	unsigned int count;

	Ivar *ivarList = class_copyIvarList(cls, &count);
	for (unsigned int i=0 ; i<count ; i++)
	{
		STACK_SCOPED SCKIvar *ivar = [SCKIvar new];
		ivar.name = [NSString stringWithUTF8String: ivar_getName(ivarList[i])];
		ivar.type = [NSString stringWithUTF8String: ivar_getTypeEncoding(ivarList[i])];
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
		STACK_SCOPED SCKMethod *method = [SCKIvar new];
		method.name = [NSString stringWithUTF8String: sel_getName(method_getName(methodList[i]))];
		method.type = [NSString stringWithUTF8String: method_getTypeEncoding(methodList[i])];
		method.parent = self;
		[methods setObject: method forKey: method.name];
	}
	if (count>0)
	{
		free(methodList);
	}
	name = [[NSString alloc] initWithUTF8String: class_getName(cls)];
	return self;
}
@end

@implementation SCKCategory : SCKProgramComponent
- (id)init
{
	SUPERINIT;
	methods = [NSMutableDictionary new];
	return self;
}
- (void)dealloc
{
	[methods release];
	[super dealloc];
}
- (NSString*)description
{
	NSMutableString *str = [NSMutableString stringWithFormat: @"%@ (%@)", parent.name, name];
	for (id method in methods)
	{
		[str appendFormat: @"\n\t%@", method];
	}
	return str;
}
@end

@implementation SCKMethod
- (void)dealloc
{
	[type release];
	[super dealloc];
}
- (NSString*)description
{
	return [NSString stringWithFormat: @"%c%@", isClassMethod ? '+' : '-', name];
}
@end

@implementation SCKIvar
- (void)dealloc
{
	[type release];
	[super dealloc];
}
@end

@implementation SCKFunction @end
