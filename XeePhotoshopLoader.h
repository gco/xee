#import "XeeMultiImage.h"
#import "XeeBitmapImage.h"

@interface XeePhotoshopImage:XeeMultiImage
{
}

-(id)initWithFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;
-(void)dealloc;

-(void)load;

+(NSArray *)fileTypes;

@end

@interface XeePhotoshopSubImage:XeeBitmapImage
{
}

//-(id)initWithFilehandle:(FILE *)fh offset:(size_t)offset ...
-(void)dealloc;

-(void)load;

@end
