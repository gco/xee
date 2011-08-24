#import "XeeImageSaver.h"



@implementation XeeImageSaver

-(id)initWithImage:(XeeImage *)img
{
	if(self=[super init])
	{
		image=[img retain];
		control=nil;
	}
	return self;
}

-(void)dealloc
{
	[image release];
	[control release];
	[super dealloc];
}

-(NSString *)format { return nil; }

-(NSString *)extension { return nil; }

-(BOOL)save:(NSString *)filename { return NO; }

-(XeeSLControl *)control { return control; }

-(void)setControl:(XeeSLControl *)cont { [control autorelease]; control=[cont retain]; }



+(BOOL)canSaveImage:(XeeImage *)img { return YES; }



static NSMutableArray *savers=nil;

+(void)initialize
{
	if(!savers) savers=[[NSMutableArray alloc] initWithCapacity:8];
}

+(NSArray *)saversForImage:(XeeImage *)image;
{
	NSMutableArray *instances=[NSMutableArray arrayWithCapacity:[savers count]];
	NSEnumerator *enumerator=[savers objectEnumerator];
	Class class;

	while(class=[enumerator nextObject])
	{
		if([class canSaveImage:image])
		[instances addObject:[[[class alloc] initWithImage:image] autorelease]];
	}

	return instances;
}

+(void)registerSaverClass:(Class)class
{
	[savers addObject:class];
}

@end
