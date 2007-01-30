#import "XeeImage.h"

@interface XeeImage (Thumbnailing)

-(CGImageRef)makeRGBThumbnailOfSize:(int)size;
-(NSData *)makeJPEGThumbnailOfSize:(int)size maxBytes:(int)maxbytes;

@end
