#import "XeeJPEGLoader.h"

@interface XeeBrokenJPEGImage:XeeJPEGImage
{
}

+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;
-(SEL)initLoader;

-(int)losslessSaveFlags;

@end
