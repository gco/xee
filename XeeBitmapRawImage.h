#import "XeeBitmapImage.h"

@interface XeeBitmapRawImage:XeeBitmapImage
{
	CSHandle *handle;
	int bytesperfilerow,row;
	uint8 *buffer;
}

-(id)initWithHandle:(CSHandle *)fh width:(int)w height:(int)h;
-(id)initWithHandle:(CSHandle *)fh width:(int)w height:(int)h bytesPerRow:(int)bpr;
-(void)dealloc;

-(SEL)initLoader;
-(void)deallocLoader;
-(SEL)load;

@end
