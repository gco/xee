#import "XeeTileImage.h"

@interface XeeYUVImage:XeeTileImage
{
	void *freedata;
}

-(id)init;
-(id)initWithFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;
-(id)initWithWidth:(int)framewidth height:(int)frameheight;
-(void)_initYUVImage;
-(void)dealloc;

-(void)setData:(void *)pixeldata width:(int)framewidth height:(int)frameheight bytesPerRow:(int)bprow;
-(BOOL)allocWithWidth:(int)framewidth height:(int)frameheight;

-(void)fixYUVGamma;

-(int)CGImageBitsPerComponent;
-(int)CGImageBitsPerPixel;
-(CGBitmapInfo)CGImageBitmapInfo;
-(CGColorSpaceRef)CGImageCopyColorSpace;
-(XeePixelAccessFunc)CGImageReadPixelFunc;
-(void *)CGImageReadPixelContext;

@end
