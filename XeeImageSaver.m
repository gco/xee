#import "XeeImageSaver.h"
#import "XeeImage.h"
#import "XeeSimpleLayout.h"




@implementation XeeImageSaver

static NSMutableArray *saverclasses=nil;

+(BOOL)canSaveImage:(XeeImage *)img { return NO; }

+(NSArray *)saversForImage:(XeeImage *)img
{
	if(!saverclasses) return nil;

	NSMutableArray *savers=[NSMutableArray array];
	NSEnumerator *enumerator=[saverclasses objectEnumerator];
	Class saverclass;
	while(saverclass=[enumerator nextObject])
	{
		if([saverclass canSaveImage:img])
		{
			XeeImageSaver *saver=[[saverclass alloc] initWithImage:img];
			if(saver) [savers addObject:saver];
			[saver release];
		}
	}

	return savers;
}

+(void)registerSaverClass:(Class)saverclass
{
	if(!saverclasses) saverclasses=[[NSMutableArray array] retain];
	[saverclasses addObject:saverclass];
}



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

-(NSString *)extension  { return nil; }

-(BOOL)save:(NSString *)filename { return NO; }

-(XeeSLControl *)control { return control; }

-(void)setControl:(XeeSLControl *)newcontrol
{
	[control autorelease];
	control=[newcontrol retain];
}

@end
