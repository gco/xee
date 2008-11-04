#import "XeeBitmapImage.h"
#import "XeeMultiImage.h"

@interface XeeDreamcastImage:XeeBitmapImage
{
}

+(NSArray *)fileTypes;
+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;

-(void)load;

-(void)loadTwiddledWithOffset:(int)offset pixelFormat:(int)pixelformat;
-(void)loadTwiddledYUVWithOffset:(int)offset;
-(void)load8BitWithPalette:(BOOL)haspalette pixelFormat:(int)pixelformat;
-(void)load4BitWithPalette:(BOOL)haspalette pixelFormat:(int)pixelformat;
-(void)loadVQWithOffset:(int)offset entries:(int)entries pixelFormat:(int)pixelformat;
-(void)loadRectangleWithOffset:(int)offset pixelFormat:(int)pixelformat;

-(void)raiseFormatMismatchWithPixelFormat:(int)pixelformat packingType:(int)packingtype;

@end

@interface XeeDreamcastMultiImage:XeeMultiImage
{
}

+(NSArray *)fileTypes;
+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;

-(void)load;

@end
