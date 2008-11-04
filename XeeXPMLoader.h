#import "XeeBitmapImage.h"

@interface XeeXPMImage:XeeBitmapImage
{
	int version;
}

+(NSArray *)fileTypes;
+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;

-(void)load;

-(NSString *)nextLine;
-(NSString *)nextString;

@end
