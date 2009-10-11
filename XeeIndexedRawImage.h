#import "XeeBitmapImage.h"

@class XeePalette;

@interface XeeIndexedRawImage:XeeBitmapImage
{
	XeePalette *pal;
	uint8_t *buffer;
	int bitdepth,inbpr;
}

-(id)initWithHandle:(CSHandle *)fh width:(int)framewidth height:(int)frameheight
palette:(XeePalette *)palette;
-(id)initWithHandle:(CSHandle *)fh width:(int)framewidth height:(int)frameheight
palette:(XeePalette *)palette bytesPerRow:(int)bytesperinputrow;
-(id)initWithHandle:(CSHandle *)fh width:(int)framewidth height:(int)frameheight
depth:(int)framedepth palette:(XeePalette *)palette;
-(id)initWithHandle:(CSHandle *)fh width:(int)framewidth height:(int)frameheight
depth:(int)framedepth palette:(XeePalette *)palette bytesPerRow:(int)bytesperinputrow;
-(void)dealloc;

-(void)load;

@end

@interface XeePalette:NSObject
{
	uint32_t pal[256];
	int numcolours;
	BOOL istrans;
}

+(XeePalette *)palette;

-(int)numberOfColours;
-(uint32_t)colourAtIndex:(int)index;
-(BOOL)isTransparent;
-(uint32_t *)colours;

-(void)setColourAtIndex:(int)index red:(uint8_t)red green:(uint8_t)green blue:(uint8_t)blue;
-(void)setColourAtIndex:(int)index red:(uint8_t)red green:(uint8_t)green blue:(uint8_t)blue alpha:(uint8_t)alpha;
-(void)setTransparent:(int)index;

-(void)convertIndexes:(uint8_t *)indexes count:(int)count depth:(int)depth toRGB8:(uint8_t *)dest;
-(void)convertIndexes:(uint8_t *)indexes count:(int)count depth:(int)depth toARGB8:(uint8_t *)dest;

@end
