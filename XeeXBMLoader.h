#import "XeeBitmapImage.h"

@interface XeeXBMImage:XeeBitmapImage
{
}

+(NSArray *)fileTypes;
+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;

-(void)load;
-(int)nextInteger;

@end
