#import "XeeBitmapImage.h"

@class XeePalette;

@interface XeeIndexedRawImage:XeeBitmapImage
{
	XeePalette *pal;
	uint8 *buffer;
	int inbpr,row;
}

-(id)initWithHandle:(CSHandle *)fh width:(int)framewidth height:(int)frameheight
palette:(XeePalette *)palette parentImage:(XeeMultiImage *)parent;
-(id)initWithHandle:(CSHandle *)fh width:(int)framewidth height:(int)frameheight
palette:(XeePalette *)palette bytesPerRow:(int)bytesperinputrow parentImage:(XeeMultiImage *)parent;
-(void)dealloc;

-(SEL)initLoader;
-(void)deallocLoader;
-(SEL)load;

@end

@interface XeePalette:NSObject
{
	uint32 pal[256];
	int numcolours;
	BOOL istrans;
}

-(int)numberOfColours;
-(uint32)colourAtIndex:(int)index;
-(BOOL)isTransparent;
-(uint32 *)colours;

-(void)setColourAtIndex:(int)index red:(uint8)red green:(uint8)green blue:(uint8)blue;
-(void)setColourAtIndex:(int)index red:(uint8)red green:(uint8)green blue:(uint8)blue alpha:(uint8)alpha;
-(void)setTransparent:(int)index;

-(void)convertIndexes:(uint8 *)indexes count:(int)count toRGB8:(uint8 *)dest;
-(void)convertIndexes:(uint8 *)indexes count:(int)count toARGB8:(uint8 *)dest;

@end
