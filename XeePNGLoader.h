#import "XeeBitmapImage.h"

#import "libpng/png.h"

@interface XeePNGImage:XeeBitmapImage
{
	png_structp png;
	png_infop info;

	int bit_depth,color_type,interlace_passes;
	int current_line,current_pass;

	NSMutableArray *commentprops;
	int first_comments;
}

-(SEL)identifyFile;
-(void)deallocLoader;
-(SEL)startLoading;
-(SEL)load;
-(SEL)finishLoading;

+(NSArray *)fileTypes;

@end
