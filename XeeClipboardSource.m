#import "XeeClipboardSource.h"
#import "XeeNSImage.h"



@implementation XeeClipboardSource

+(BOOL)canInitWithPasteboard:(NSPasteboard *)pboard
{
	return [NSBitmapImageRep canInitWithPasteboard:[NSPasteboard generalPasteboard]];
}

+(BOOL)canInitWithGeneralPasteboard
{
	return [self canInitWithPasteboard:[NSPasteboard generalPasteboard]];
}

-(id)initWithPasteboard:(NSPasteboard *)pboard
{
	if(self=[super init])
	{
		image=nil;

		NSBitmapImageRep *rep=[NSBitmapImageRep imageRepWithPasteboard:pboard];
		if(rep)
		{
			image=[[XeeNSImage alloc] initWithNSBitmapImageRep:rep];
			if(rep) return self;
		}
	}

	[self release];
	return nil;
}

-(id)initWithGeneralPasteboard
{
	return [self initWithPasteboard:[NSPasteboard generalPasteboard]];
}

-(void)dealloc
{
	[image release];
	[super dealloc];
}

-(int)numberOfImages { return 1; }

-(int)indexOfCurrentImage { return 0; }

-(NSString *)descriptiveNameOfCurrentImage { return @"Clipboard contents"; }

-(BOOL)isNavigatable { return NO; }

-(void)pickImageAtIndex:(int)index next:(int)next { [self triggerImageChangeAction:image]; }


@end
