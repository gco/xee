#import "XeeImageSource.h"

@interface XeeClipboardSource:XeeImageSource
{
	XeeImage *image;
}

+(BOOL)canInitWithPasteboard:(NSPasteboard *)pboard;
+(BOOL)canInitWithGeneralPasteboard;

-(id)initWithPasteboard:(NSPasteboard *)pboard;
-(id)initWithGeneralPasteboard;
-(void)dealloc;

-(int)numberOfImages;
-(int)indexOfCurrentImage;
-(NSString *)descriptiveNameOfCurrentImage;

-(void)pickImageAtIndex:(int)index next:(int)next;

@end
