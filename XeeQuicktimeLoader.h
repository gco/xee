#import "XeeMultiImage.h"

#import <QuickTime/ImageCompression.h>
#import <QuickTime/QuickTimeComponents.h>

@class XeeBitmapImage;

@interface XeeQuicktimeImage:XeeMultiImage
{
	GraphicsImportComponent gi;

	int current_image;
}

-(SEL)identifyFile;
-(void)deallocLoader;
-(SEL)loadNextImage;
-(SEL)loadImage;

-(XeeBitmapImage *)finalSubImage;

+(void)load;
+(NSArray *)fileTypes;

@end
