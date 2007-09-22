#import "XeeBitmapImage.h"

#import "libpng/png.h"

@interface XeePNGImage:XeeBitmapImage
{
	png_structp png;
	png_infop info;

	int bit_depth,color_type,interlace_passes;
	int current_line,current_pass;
}

+(NSArray *)fileTypes;
+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;

-(SEL)initLoader;
-(void)deallocLoader;
-(SEL)startLoading;
-(SEL)loadImage;
-(SEL)finishLoading;

@end
