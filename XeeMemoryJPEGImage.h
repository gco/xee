#import "XeeBitmapImage.h"

@interface XeeMemoryJPEGImage:XeeBitmapImage
{
}
 
-(id)initWithBytes:(const void *)bytes length:(int)len;
-(id)initWithData:(NSData *)data;
 
@end

