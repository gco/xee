#import "XeeMultiImage.h"
#import "XeeBitmapImage.h"

@interface XeePhotoshopPICTImage:XeeMultiImage
{
	XeeBitmapImage *image;
}

+(NSArray *)fileTypes;
+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;

-(void)load;
-(void)fallback;

@end
