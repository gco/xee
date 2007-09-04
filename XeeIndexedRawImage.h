#import "XeeBitmapImage.h"

@interface XeeIndexedRawImage:XeeBitmapImage
{
}

-(id)initWithHandle:(CSHandle *)fh width:(int)width height:(int)height colours:(int)numcolours palette:(uint8 *)palette;
-(void)dealloc;

-(SEL)initLoader;
-(SEL)load;

@end
