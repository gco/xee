#import "XeeMultiImage.h"

#import <QuickTime/ImageCompression.h>
#import <QuickTime/QuickTimeComponents.h>

@class XeeBitmapImage;

@interface XeeQuicktimeImage:XeeMultiImage
{
	GraphicsImportComponent gi;
	int current_image,current_height;
}

+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;

-(SEL)initLoader;
-(void)deallocLoader;
-(SEL)loadNextImage;
-(SEL)loadImage;

-(XeeBitmapImage *)currentImage;
-(int)currentHeight;

+(void)load;
+(NSArray *)fileTypes;

@end
