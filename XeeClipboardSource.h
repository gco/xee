#import "XeeImageSource.h"

@interface XeeClipboardSource:XeeImageSource
{
	XeeImage *image;
	uint64_t size;
}

+(BOOL)canInitWithPasteboard:(NSPasteboard *)pboard;
+(BOOL)canInitWithGeneralPasteboard;

-(id)initWithPasteboard:(NSPasteboard *)pboard;
-(id)initWithGeneralPasteboard;
-(void)dealloc;

-(int)numberOfImages;
-(int)indexOfCurrentImage;
-(NSString *)windowTitle;
-(NSString *)descriptiveNameOfCurrentImage;
-(uint64_t)sizeOfCurrentImage;

-(void)pickImageAtIndex:(int)index next:(int)next;

@end
