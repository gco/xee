#include "XeeBitmapImage.h"

typedef void *CGAccessSessionRef;

@interface XeeCGImage:XeeBitmapImage
{
	CGImageRef imageref;
	CGAccessSessionRef session;
}

-(id)init;
-(id)initWithCGImage:(CGImageRef)cgimage;
-(void)dealloc;

-(BOOL)setCGImage:(CGImageRef)cgimageref;
-(void)invertImage;

-(CGColorSpaceRef)createColorSpaceForCGImage;

@end
