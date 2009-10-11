#import "XeeTileImage.h"

#define XeeBitmapType(mode,depth,alpha,flags) (((flags)<<18)|((mode)<<13)|((depth)<<5)|((alpha)<<0))

#define XeeBitmapMode(type) (((type)>>13)&0x1f)
#define XeeBitmapDepth(type)  (((type)>>5)&0xff)
#define XeeBitmapAlpha(type) (((type)>>0)&0x1f) 
#define XeeBitmapFlags(type) (((type)>>18)&0x3fff)

#define XeeGreyBitmap 0
#define XeeRGBBitmap 1

#define XeeAlphaNone kCGImageAlphaNone
#define XeeAlphaNoneSkipFirst kCGImageAlphaNoneSkipFirst
#define XeeAlphaNoneSkipLast kCGImageAlphaNoneSkipLast
#define XeeAlphaFirst kCGImageAlphaFirst
#define XeeAlphaLast kCGImageAlphaLast
#define XeeAlphaPremultipliedFirst kCGImageAlphaPremultipliedFirst
#define XeeAlphaPremultipliedLast kCGImageAlphaPremultipliedLast

#define XeeBitmapFloatingPointFlag 0x0001



#define XeeBitmapTypeLuma8 XeeBitmapType(XeeGreyBitmap,8,XeeAlphaNone,0)
#define XeeBitmapTypeLumaAlpha8 XeeBitmapType(XeeGreyBitmap,8,XeeAlphaLast,0)
#define XeeBitmapTypeLuma16 XeeBitmapType(XeeGreyBitmap,16,XeeAlphaNone,0)
#define XeeBitmapTypeLumaAlpha16 XeeBitmapType(XeeGreyBitmap,16,XeeAlphaLast,0) 

#define XeeBitmapTypeRGB8 XeeBitmapType(XeeRGBBitmap,8,XeeAlphaNone,0)
#define XeeBitmapTypeRGBA8 XeeBitmapType(XeeRGBBitmap,8,XeeAlphaLast,0)
#define XeeBitmapTypeRGB16 XeeBitmapType(XeeRGBBitmap,16,XeeAlphaNone,0)
#define XeeBitmapTypeRGBA16 XeeBitmapType(XeeRGBBitmap,16,XeeAlphaLast,0)

#define XeeBitmapTypeARGB8 XeeBitmapType(XeeRGBBitmap,8,XeeAlphaFirst,0)
#define XeeBitmapTypePremultipliedARGB8 XeeBitmapType(XeeRGBBitmap,8,XeeAlphaPremultipliedFirst,0)
#define XeeBitmapTypeNRGB8 XeeBitmapType(XeeRGBBitmap,8,XeeAlphaNoneSkipFirst,0)




#ifdef __BIG_ENDIAN__
static inline uint32_t XeeMakeARGB8(uint8_t a,uint8_t r,uint8_t g,uint8_t b)
{ return (a<<24)|(r<<16)|(g<<8)|b; }
static inline uint32_t XeeMakeNRGB8(uint8_t r,uint8_t g,uint8_t b)
{ return (0xff<<24)|(r<<16)|(g<<8)|b; }
static inline int XeeGetAFromARGB8(uint32_t argb) { return (argb>>24)&0xff; }
static inline int XeeGetRFromARGB8(uint32_t argb) { return (argb>>16)&0xff; }
static inline int XeeGetGFromARGB8(uint32_t argb) { return (argb>>8)&0xff; }
static inline int XeeGetBFromARGB8(uint32_t argb) { return argb&0xff; }
#else
static inline uint32_t XeeMakeARGB8(uint8_t a,uint8_t r,uint8_t g,uint8_t b)
{ return a|(r<<8)|(g<<16)|(b<<24); }
static inline uint32_t XeeMakeNRGB8(uint8_t r,uint8_t g,uint8_t b)
{ return 0xff|(r<<8)|(g<<16)|(b<<24); }
static inline int XeeGetAFromARGB8(uint32_t argb) { return argb&0xff; }
static inline int XeeGetRFromARGB8(uint32_t argb) { return (argb>>8)&0xff; }
static inline int XeeGetGFromARGB8(uint32_t argb) { return (argb>>16)&0xff; }
static inline int XeeGetBFromARGB8(uint32_t argb) { return (argb>>24)&0xff; }
#endif

#define XeeGetRFromNRGB8 XeeGetRFromARGB8
#define XeeGetGFromNRGB8 XeeGetGFromARGB8
#define XeeGetBFromNRGB8 XeeGetBFromARGB8






@interface XeeBitmapImage:XeeTileImage
{
	int bitsperpixel,bitspercomponent;
	int colourmode,alphatype,modeflags;
}

-(id)init;
-(id)initWithType:(int)pixeltype width:(int)framewidth height:(int)frameheight;
-(void)dealloc;

-(BOOL)setData:(uint8_t *)pixeldata freeData:(BOOL)willfree width:(int)pixelwidth height:(int)pixelheight
bitsPerPixel:(int)bppixel bitsPerComponent:(int)bpcomponent bytesPerRow:(int)bprow
mode:(int)mode alphaType:(int)alpha flags:(int)flags;

-(BOOL)allocWithType:(int)pixeltype width:(int)framewidth height:(int)frameheight;

-(CGContextRef)createCGContext;

-(int)bitsPerComponentForCGImage;
-(int)bytesPerPixelForCGImage;
-(CGColorSpaceRef)createColorSpaceForCGImage;
-(int)bitmapInfoForCGImage;
-(XeeReadPixelFunction)readPixelFunctionForCGImage;


@end
