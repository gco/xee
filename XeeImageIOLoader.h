#import "XeeMultiImage.h"

#import <Carbon/Carbon.h>

@interface XeeImageIOImage:XeeMultiImage
{
	CGImageSourceRef source;
	int current_image;
}

+(NSArray *)fileTypes;
+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;

-(SEL)initLoader;
-(void)deallocLoader;
-(SEL)loadImage;
-(SEL)loadThumbnail;

-(void)setDepthForImage:(XeeImage *)image properties:(NSDictionary *)properties;
-(NSString *)formatForType:(NSString *)type;

-(NSArray *)convertCGProperties:(NSDictionary *)cgproperties;
-(NSArray *)convertCGPropertyValues:(NSDictionary *)cgproperties imageIOBundle:(NSBundle *)imageio;

+(NSArray *)fileTypes;

@end
