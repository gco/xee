#import "XeeBitmapImage.h"

#define XeeGreyRawColourSpace 1
#define XeeRGBRawColourSpace 2
#define XeeCMYKRawColourSpace 3
#define XeeLabRawColourSpace 4

#define XeeAlphaFirstRawFlag 0x0001
#define XeeAlphaLastRawFlag 0x0002
#define XeeNoAlphaRawFlag 0x0000
#define XeeSkipAlphaRawFlag 0x0004
#define XeeAlphaPremultipliedRawFlag 0x0004
#define XeeAlphaPrecomposedRawFlag 0x0010
#define XeeBigEndianRawFlag 0x0020
#define XeeLittleEndianRawFlag 0x0000
#define XeeFloatingPointRawFlag 0x0040

@interface XeeRawImage:XeeBitmapImage
{
	int bitdepth,inbpr,channels,uncomposition,transformation,type;
	uint8_t *buffer;
	BOOL flipendian,needsbuffer,adjustranges;
	float range[5][2];
}

-(id)initWithHandle:(CSHandle *)inhandle width:(int)framewidth height:(int)frameheight
depth:(int)framedepth colourSpace:(int)space flags:(int)flags;
-(id)initWithHandle:(CSHandle *)inhandle width:(int)framewidth height:(int)frameheight
depth:(int)framedepth colourSpace:(int)space flags:(int)flags bytesPerRow:(int)byterperinputrow;
-(void)dealloc;

-(void)setZeroPoint:(float)low onePoint:(float)high forChannel:(int)channel;

-(void)load;

@end
