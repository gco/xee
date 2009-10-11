#import "XeeBitmapImage.h"


static GLuint XeePickTexType(int bitspercomponent,int flags);
static void XeeBitmapImageReadPixel(uint8_t *row,int x,int pixelsize,uint8_t *dest);

@implementation XeeBitmapImage

-(id)init
{
	if(self=[super init])
	{
		bitsperpixel=bitspercomponent=0;
		colourmode=alphatype=modeflags=0;
	}
	return self;
}

-(id)initWithType:(int)pixelgltype width:(int)framewidth height:(int)frameheight
{
	if(self=[super init])
	{
		bitsperpixel=bitspercomponent=0;
		colourmode=alphatype=modeflags=0;

		if([self allocWithType:pixelgltype width:framewidth height:frameheight]) return self;
		[self release];
	}

	return nil;
}

-(void)dealloc
{
	[super dealloc];
}




-(BOOL)setData:(uint8_t *)pixeldata freeData:(BOOL)willfree width:(int)pixelwidth height:(int)pixelheight
bitsPerPixel:(int)bppixel bitsPerComponent:(int)bpcomponent bytesPerRow:(int)bprow
mode:(int)mode alphaType:(int)alpha flags:(int)flags 
{
	int pixelsize=bppixel/8;

	int components;
	switch(mode)
	{
		case XeeGreyBitmap: components=1; break;
		case XeeRGBBitmap: components=3; break;
		default: return NO;
	}

/*NSLog(@"setData:%x freeData:%d width:%d height:%d bitsPerPixel:%d bitsPerComponent:%d "
@"bytesPerRow:%d mode:%d alphaType:%d flags:%x",pixeldata,willfree,pixelwidth,pixelheight,
bppixel,bpcomponent,bprow,mode,alpha,flags); */

	// sanity checks
	if(bppixel&7) return NO; // non-byte aligned sizes not supported
	if(alpha==XeeAlphaNone&&bppixel!=bpcomponent*components) return NO;
	if(alpha!=XeeAlphaNone&&bppixel!=bpcomponent*(components+1)) return NO;
	if(bprow<pixelsize*width) return NO;

	BOOL premult=NO;
	if(alpha==XeeAlphaPremultipliedFirst||alpha==XeeAlphaPremultipliedLast) premult=YES;

	BOOL trans=NO;
	if(alpha!=XeeAlphaNone&&alpha!=XeeAlphaNoneSkipFirst&&alpha!=XeeAlphaNoneSkipLast) trans=YES;

	int glintformat,glformat,gltype;
	if(mode==XeeRGBBitmap)
	{
		switch(alpha)
		{
			case XeeAlphaNone:
				glintformat=GL_RGB;
				glformat=GL_RGB;
				gltype=XeePickTexType(bpcomponent,flags);
			break;

			case XeeAlphaPremultipliedFirst: // native glformat
			case XeeAlphaFirst:
			case XeeAlphaNoneSkipFirst:
				if(bpcomponent!=8) return NO;
				glintformat=GL_RGBA8;
				glformat=GL_BGRA;
				#ifdef __BIG_ENDIAN__
				gltype=GL_UNSIGNED_INT_8_8_8_8_REV;
				#else
				gltype=GL_UNSIGNED_INT_8_8_8_8;
				#endif
			break;

			case XeeAlphaPremultipliedLast:
			case XeeAlphaLast:
			case XeeAlphaNoneSkipLast:
				glintformat=GL_RGBA8;
				glformat=GL_RGBA;
				gltype=XeePickTexType(bpcomponent,flags);
			break;

			default: return NO;
		}
	}
	else if(mode==XeeGreyBitmap)
	{
		switch(alpha)
		{
			case XeeAlphaNone:
				glintformat=GL_LUMINANCE8;
				glformat=GL_LUMINANCE;
				gltype=XeePickTexType(bpcomponent,flags);
			break;

			case XeeAlphaPremultipliedFirst: // native glformat
			case XeeAlphaFirst:
			case XeeAlphaNoneSkipFirst:
				if(bpcomponent!=8) return NO;
				glintformat=GL_LUMINANCE8_ALPHA8;
				glformat=GL_LUMINANCE_ALPHA;
				#ifdef __BIG_ENDIAN__
				gltype=GL_UNSIGNED_SHORT_8_8_REV_APPLE;
				#else
				gltype=GL_UNSIGNED_SHORT_8_8_APPLE;
				#endif
			break;

			case XeeAlphaPremultipliedLast:
			case XeeAlphaLast:
			case XeeAlphaNoneSkipLast:
				glintformat=GL_LUMINANCE8_ALPHA8;
				glformat=GL_LUMINANCE_ALPHA;
				gltype=XeePickTexType(bpcomponent,flags);
			break;

			default: return NO;
		}
	}
	else return NO;

	if(!gltype) return NO;

	[super setData:pixeldata freeData:willfree width:pixelwidth height:pixelheight
	bytesPerPixel:pixelsize bytesPerRow:bprow premultiplied:premult
	glInternalFormat:glintformat glFormat:glformat glType:gltype];

	transparent=trans;

	bitsperpixel=bppixel;
	bitspercomponent=bpcomponent;
	colourmode=mode;
	alphatype=alpha;
	modeflags=flags;

	return YES;
}



-(BOOL)allocWithType:(int)type width:(int)pixelwidth height:(int)pixelheight
{
	int mode=XeeBitmapMode(type);
	int bpcomponent=XeeBitmapDepth(type);
	int alpha=XeeBitmapAlpha(type);
	int flags=XeeBitmapFlags(type);

	int components;
	switch(mode)
	{
		case XeeGreyBitmap: components=1; break;
		case XeeRGBBitmap: components=3; break;
		default: return NO;
	}

	int bppixel=bpcomponent*(components+(alpha==XeeAlphaNone?0:1));
	int bprow=((bppixel/8)*pixelwidth+3)&~3; // align to 4 bytes
//	int bprow=((bppixel/8)*pixelwidth+15)&~15; // align to 16 bytes

	void *newdata=calloc(bprow*pixelheight,1);
	if(newdata)
	{
		if([self setData:newdata freeData:YES width:pixelwidth height:pixelheight
		bitsPerPixel:bppixel bitsPerComponent:bpcomponent bytesPerRow:bprow
		mode:mode alphaType:alpha flags:flags]) return YES;

		free(newdata);
	}

	return NO;
}

/*CGColorSpaceRef CreateSystemColorSpace()
{
	CMProfileRef sysprof=NULL;
	CGColorSpaceRef dispColorSpace=NULL;

	// Get the Systems Profile for the main display
	if(CMGetSystemProfile(&sysprof)==noErr)
	{
		// Create a colorspace with the systems profile
		dispColorSpace = CGColorSpaceCreateWithPlatformColorSpace(sysprof);

		// Close the profile
		CMCloseProfile(sysprof);
	}

	return dispColorSpace;
}*/


-(CGContextRef)createCGContext
{
	CGColorSpaceRef colorspace=[self createColorSpaceForCGImage];
	if(!colorspace) return NULL;

	int bitmapinfo=[self bitmapInfoForCGImage];

	CGContextRef cgcontext=CGBitmapContextCreate(data,width,height,8,bytesperrow,colorspace,bitmapinfo);

	CGColorSpaceRelease(colorspace);

	return cgcontext;
}

-(int)bitsPerComponentForCGImage { return bitspercomponent; }

-(int)bytesPerPixelForCGImage { return bytesperpixel; }

-(CGColorSpaceRef)createColorSpaceForCGImage
{
	switch(colourmode)
	{
		case XeeGreyBitmap: return CGColorSpaceCreateDeviceGray();
		case XeeRGBBitmap: return CGColorSpaceCreateDeviceRGB();
		default: return NULL;
	}
}

-(int)bitmapInfoForCGImage
{
	return alphatype|(modeflags&XeeBitmapFloatingPointFlag?kCGBitmapFloatComponents:0);
}

-(XeeReadPixelFunction)readPixelFunctionForCGImage { return XeeBitmapImageReadPixel; }

@end



static GLuint XeePickTexType(int bitspercomponent,int flags)
{
	switch(bitspercomponent)
	{
		case 8: return GL_UNSIGNED_BYTE;
		case 16: return GL_UNSIGNED_SHORT;
		case 32:
			if(flags&XeeBitmapFloatingPointFlag) return GL_FLOAT;
			else return GL_UNSIGNED_INT;
		break;
		default: return 0;
	}
}

static void XeeBitmapImageReadPixel(uint8_t *row,int x,int pixelsize,uint8_t *dest)
{
	memcpy(dest,row+x*pixelsize,pixelsize);
}
