#import "XeeBitmapImage.h"

@interface XeeBitmapRawImage:XeeBitmapImage
{
	int bytesperfilerow;
	uint8_t zero,one;
	uint8_t *buffer;
}

-(id)initWithHandle:(CSHandle *)fh width:(int)w height:(int)h;
-(id)initWithHandle:(CSHandle *)fh width:(int)w height:(int)h bytesPerRow:(int)bpr;
-(void)dealloc;

-(void)setZeroPoint:(float)low onePoint:(float)high;

-(void)load;

@end
