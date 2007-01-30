#import "XeeBitmapImage.h"

@interface XeeDreamcastImage:XeeBitmapImage
{
}

+(NSArray *)fileTypes;
+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;

-(SEL)initLoader;
-(void)deallocLoader;
-(SEL)startLoading;
-(SEL)load;

@end
