#import "XeeTileImage.h"



#define XeeColorSpaceGrey 1
#define XeeColorSpaceRGB 2
#define XeeBitmapType(colorspace,depth,bitmapformat) ((colorspace<<24)|(depth<<16)|(bitmapformat&0xffff))
#define XeeBitmapTypeColorSpace(type) (((type)>>24)&0xff)
#define XeeBitmapTypeDepth(type) (((type)>>16)&0xff)
#define XeeBitmapTypeBitmapInfo(type) ((type)&0xffff)



// Grescale formats
#define XeeBitmapTypeLuma8				XeeBitmapType(XeeColorSpaceGrey,8,kCGImageAlphaNone)
#define XeeBitmapTypeLuma16				XeeBitmapType(XeeColorSpaceGrey,16,kCGImageAlphaNone)
#define XeeBitmapTypeLuma32FP			XeeBitmapType(XeeColorSpaceGrey,32,kCGImageAlphaNone|kCGBitmapFloatComponents)
// Grey+alpha formats
#define XeeBitmapTypeLumaAlpha8			XeeBitmapType(XeeColorSpaceGrey,8,kCGImageAlphaLast)
#define XeeBitmapTypeLumaAlpha16		XeeBitmapType(XeeColorSpaceGrey,16,kCGImageAlphaLast)
#define XeeBitmapTypeLumaAlpha32FP		XeeBitmapType(XeeColorSpaceGrey,32,kCGImageAlphaLast|kCGBitmapFloatComponents)
// RGB formats
#define XeeBitmapTypeRGB8				XeeBitmapType(XeeColorSpaceRGB,8,kCGImageAlphaNone)
#define XeeBitmapTypeRGB16				XeeBitmapType(XeeColorSpaceRGB,16,kCGImageAlphaNone)
#define XeeBitmapTypeRGB32FP				XeeBitmapType(XeeColorSpaceRGB,32,kCGImageAlphaNone|kCGBitmapFloatComponents)
// RGBA formats
#define XeeBitmapTypeRGBA8				XeeBitmapType(XeeColorSpaceRGB,8,kCGImageAlphaLast)
#define XeeBitmapTypeRGBA16				XeeBitmapType(XeeColorSpaceRGB,16,kCGImageAlphaLast)
#define XeeBitmapTypeRGBA32FP			XeeBitmapType(XeeColorSpaceRGB,32,kCGImageAlphaLast|kCGBitmapFloatComponents)
// Native ARGB formats
#define XeeBitmapTypeARGB8				XeeBitmapType(XeeColorSpaceRGB,8,kCGImageAlphaFirst)
#define XeeBitmapTypePremultipliedARGB8	XeeBitmapType(XeeColorSpaceRGB,8,kCGImageAlphaPremultipliedFirst)
#define XeeBitmapTypeNRGB8				XeeBitmapType(XeeColorSpaceRGB,8,kCGImageAlphaNoneSkipFirst)



#ifdef BIG_ENDIAN
#define XeeMakeARGB8(a,r,g,b) (((a)<<24)|((r)<<16)|((g)<<8)|(b))
#define XeeMakeNRGB8(r,g,b) ((0xff<<24)|((r)<<16)|((g)<<8)|(b))
#define XeeGetAFromARGB8(argb) (((argb)>>24)&0xff)
#define XeeGetRFromARGB8(argb) (((argb)>>16)&0xff)
#define XeeGetGFromARGB8(argb) (((argb)>>8)&0xff)
#define XeeGetBFromARGB8(argb) (((argb))&0xff)
#else
#define XeeMakeARGB8(a,r,g,b) ((a)|((r)<<8)|((g)<<16)|((b)<<24))
#define XeeMakeNRGB8(r,g,b) ((0xff)|((r)<<8)|((g)<<16)|((b)<<24))
#define XeeGetAFromARGB8(argb) (((argb))&0xff)
#define XeeGetRFromARGB8(argb) (((argb)>>8)&0xff)
#define XeeGetGFromARGB8(argb) (((argb)>>16)&0xff)
#define XeeGetBFromARGB8(argb) (((argb)>>24)&0xff)
#endif

#define XeeGetRFromNRGB8 XeeGetRFromARGB8
#define XeeGetGFromNRGB8 XeeGetGFromARGB8
#define XeeGetbFromNRGB8 XeeGetBFromARGB8


// Reverse-engineered API calls. Evil!

typedef void *CGAccessSessionRef;
CGAccessSessionRef CGAccessSessionCreate(CGDataProviderRef provider);
void *CGAccessSessionGetBytePointer(CGAccessSessionRef session);
size_t CGAccessSessionGetBytes(CGAccessSessionRef session,void *buffer,size_t bytes);
void CGAccessSessionRelease(CGAccessSessionRef session);



@interface XeeBitmapImage:XeeTileImage
{
	CGImageRef imageref;
	CGAccessSessionRef session;
	void *freedata;
}

-(id)init;
-(id)initWithFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;
-(id)initWithCGImage:(CGImageRef)cgimage;
-(id)initWithConvertedCGImage:(CGImageRef)cgimage type:(int)pixeltype;
-(id)initWithType:(int)pixeltype width:(int)framewidth height:(int)frameheight;
-(void)_initBitmapImage;
-(void)dealloc;

-(BOOL)setCGImage:(CGImageRef)cgimageref;
-(BOOL)allocWithType:(int)pixeltype width:(int)framewidth height:(int)frameheight;
-(CGContextRef)createContext;

-(CGImageRef)makeCGImage;

-(int)CGImageBitsPerComponent;
-(int)CGImageBitsPerPixel;
-(CGBitmapInfo)CGImageBitmapInfo;
-(CGColorSpaceRef)CGImageCopyColorSpace;
-(XeePixelAccessFunc)CGImageReadPixelFunc;
-(void *)CGImageReadPixelContext;

@end
