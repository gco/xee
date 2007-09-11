#import "XeeBitmapImage.h"

@interface XeeBitmapRawImage:XeeBitmapImage
{
	int bytesperfilerow,row;
	uint8 *buffer;
}

-(id)initWithHandle:(CSHandle *)fh width:(int)w height:(int)h parentImage:(XeeMultiImage *)parent;
-(id)initWithHandle:(CSHandle *)fh width:(int)w height:(int)h bytesPerRow:(int)bpr parentImage:(XeeMultiImage *)parent;
-(void)dealloc;

-(SEL)initLoader;
-(void)deallocLoader;
-(SEL)load;

@end
