#import "XeeClipboardSource.h"
//#import "XeeNSImage.h"
#import "XeeImage.h"

#import <XADMaster/CSMemoryHandle.h>
#import <XADMaster/CSMultiHandle.h>


@implementation XeeClipboardSource

+(BOOL)canInitWithPasteboard:(NSPasteboard *)pboard
{
//	return [NSBitmapImageRep canInitWithPasteboard:[NSPasteboard generalPasteboard]];

	if([[pboard types] containsObject:NSTIFFPboardType]) return YES;
	if([[pboard types] containsObject:NSPICTPboardType]) return YES;
	return NO;
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

		NSString *type=[pboard availableTypeFromArray:[NSArray arrayWithObjects:NSTIFFPboardType,NSPICTPboardType,nil]];
		NSData *data=[pboard dataForType:type];

		size=[data length];

		CSHandle *handle;
		if([type isEqual:NSPICTPboardType])
		{
			NSMutableData *head=[NSMutableData dataWithLength:512];
			handle=[CSMultiHandle multiHandleWithHandles:
				[CSMemoryHandle memoryHandleForReadingData:head],
				[CSMemoryHandle memoryHandleForReadingData:data],
			nil];
		}
		else handle=[CSMemoryHandle memoryHandleForReadingData:data];

/*NSLog(@"what");
[[[[handle copy] autorelease] remainingFileContents] writeToFile:@"/Users/dag/Desktop/test.pict" atomically:NO];
*/
		image=[[XeeImage imageForHandle:handle] retain];

		if(image) return self;
		else NSBeep();

/*		NSBitmapImageRep *rep=[NSBitmapImageRep imageRepWithPasteboard:pboard];
		if(rep)
		{
			image=[[XeeNSImage alloc] initWithNSBitmapImageRep:rep];
			if(image) return self;
		}*/
		[self release];
	}

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

-(void)start
{
	[image runLoader];
	[self triggerImageChangeAction:image];
}

-(int)numberOfImages { return 1; }

-(int)indexOfCurrentImage { return 0; }

-(NSString *)windowTitle { return NSLocalizedString(@"Clipboard contents",@"Window title when showing the contents of the clipboard"); }

-(NSString *)descriptiveNameOfCurrentImage { return NSLocalizedString(@"Clipboard contents",@"Window title when showing the contents of the clipboard"); }

-(uint64_t)sizeOfCurrentImage { return size; }

-(void)pickImageAtIndex:(int)index next:(int)next
{
	[self triggerImageChangeAction:image];
}


@end
