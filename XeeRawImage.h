#import "XeeBitmapImage.h"

#define XeeGreyRawColourSpace 1
#define XeeRGBRawColourSpace 2
#define XeeCMYKRawColourSpace 3
#define XeeLabRawColourSpace 4

#define XeeAlphaFirstRawFlag 0x0001
#define XeeAlphaLastRawFlag 0x0002
#define XeeNoAlphaRawFlag 0x0000
#define XeeAlphaPremultipliedRawFlag 0x0004
#define XeeAlphaPrecomposedRawFlag 0x0008
#define XeeBigEndianRawFlag 0x0010
#define XeeLittleEndianRawFlag 0x0000
#define XeeFloatingPointRawFlag 0x0020

@interface XeeRawImage:XeeBitmapImage
{
	int bitdepth,inbpr,channels,uncomposition,transformation,type;
	uint8 *buffer;
	BOOL flipendian,needsbuffer;

	int row;
}

-(id)initWithHandle:(CSHandle *)inhandle width:(int)framewidth height:(int)frameheight
depth:(int)framedepth colourSpace:(int)space flags:(int)flags
parentImage:(XeeMultiImage *)parent;
-(id)initWithHandle:(CSHandle *)inhandle width:(int)framewidth height:(int)frameheight
depth:(int)framedepth colourSpace:(int)space flags:(int)flags bytesPerRow:(int)byterperinputrow
parentImage:(XeeMultiImage *)parent;
-(void)dealloc;

-(SEL)initLoader;
-(SEL)load;

@end
