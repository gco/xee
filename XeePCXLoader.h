#import "XeeBitmapImage.h"


@interface XeePCXImage:XeeBitmapImage
{
	int current_line;
	uint8 palette[3*256];
	NSData *header;
}

+(NSArray *)fileTypes;
+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;

-(SEL)initLoader;
-(void)deallocLoader;
-(SEL)startLoading;
-(SEL)loadImage;

@end
