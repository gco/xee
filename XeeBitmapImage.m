#import "XeeBitmapImage.h"


static void XeeBitmapImageReleaseData(void *info);
static void XeeBitmapImageReadPixel(void *datarow,int x,uint8 *pixel,void *context);



@implementation XeeBitmapImage

-(id)init
{
	if(self=[super init]) [self _initBitmapImage];
	return self;
}

-(id)initWithFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes
{
	if(self=[super initWithFile:name firstBlock:block attributes:attributes]) [self _initBitmapImage];
	return self;
}

-(id)initWithCGImage:(CGImageRef)cgimage
{
	if(self=[super init])
	{
		[self _initBitmapImage];
		if([self setCGImage:cgimage]) return self;
		[self release];
	}
	return nil;
}

-(id)initWithConvertedCGImage:(CGImageRef)cgimage type:(int)pixeltype
{
	int framewidth=CGImageGetWidth(cgimage);
	int frameheight=CGImageGetHeight(cgimage);

	if(self=[self initWithType:pixeltype width:framewidth height:frameheight])
	{
		CGContextRef cgcontext=[self createContext];
		if(cgcontext)
		{
			CGContextDrawImage(cgcontext,CGRectMake(0,0,framewidth,frameheight),cgimage);
			CGContextRelease(cgcontext);
			return self;
		}

		[self release];
	}
	return nil;
}

-(id)initWithType:(int)pixeltype width:(int)framewidth height:(int)frameheight
{
	if(self=[super init])
	{
		[self _initBitmapImage];
		if([self allocWithType:pixeltype width:framewidth height:frameheight]) return self;
		[self release];
	}

	return nil;
}

-(void)_initBitmapImage
{
	imageref=NULL;
	session=NULL;
	freedata=NULL;
}

-(void)dealloc
{
	if(session) CGAccessSessionRelease(session);
	CGImageRelease(imageref);

	free(freedata);

	[super dealloc];
}


GLuint XeePickTexType(int bitspercomponent,int bitmapinfo)
{
	switch(bitspercomponent)
	{
		case 8: return GL_UNSIGNED_BYTE;
		case 16: return GL_UNSIGNED_SHORT;
		case 32:
			if(bitmapinfo&kCGBitmapFloatComponents) return GL_FLOAT;
			else return GL_UNSIGNED_INT;
		break;
		default: return 0;
	}
}

-(BOOL)setCGImage:(CGImageRef)cgimage
{
	if(!cgimage) return NO;

	width=CGImageGetWidth(cgimage);
	height=CGImageGetHeight(cgimage);
	bytesperrow=CGImageGetBytesPerRow(cgimage);

	int bitsperpixel=CGImageGetBitsPerPixel(cgimage);
	int bitspercomponent=CGImageGetBitsPerComponent(cgimage);
	int bitmapinfo=CGImageGetBitmapInfo(cgimage); // only on 10.4
	int alphainfo=CGImageGetAlphaInfo(cgimage);
	CGColorSpaceRef colorspace=CGImageGetColorSpace(cgimage);
	int components=CGColorSpaceGetNumberOfComponents(colorspace);

//NSLog(@"%dx%d, %d bpr, %d bpp, %d bpc, %x info, %x alpha, %d comps",
//width,height,bytesperrow,bitsperpixel,bitspercomponent,bitmapinfo,alphainfo,components);

	pixelsize=bitsperpixel/8;

	if(alphainfo!=kCGImageAlphaNone&&alphainfo!=kCGImageAlphaNoneSkipFirst&&alphainfo!=kCGImageAlphaNoneSkipLast)
	transparent=YES;

	if(alphainfo==kCGImageAlphaPremultipliedFirst||alphainfo==kCGImageAlphaPremultipliedLast)
	premultiplied=YES;

	int byteorder=bitmapinfo&kCGBitmapByteOrderMask;
	#ifdef BIG_ENDIAN
	if(byteorder==kCGBitmapByteOrder16Little||byteorder==kCGBitmapByteOrder32Little) return NO;
	#else
	if(byteorder==kCGBitmapByteOrder16Big||byteorder==kCGBitmapByteOrder32Big) return NO;
	#endif

	CGDataProviderRef provider=CGImageGetDataProvider(cgimage);
	if(!provider) return NO;

	session=CGAccessSessionCreate(provider);
	if(!session) return NO;

	data=CGAccessSessionGetBytePointer(session);
	if(!data)
	{
		size_t bytes=height*bytesperrow;
		data=malloc(bytes);
		if(!data) return NO;
		freedata=data;

		/*size_t res=*/CGAccessSessionGetBytes(session,data,bytes);
		// should check res, maybe?

		CGAccessSessionRelease(session);
		session=NULL;
	}

	switch(components)
	{
		case 1:
			if(alphainfo)
			{
				switch(alphainfo)
				{
					case kCGImageAlphaPremultipliedFirst: // native format
					case kCGImageAlphaFirst:
					case kCGImageAlphaNoneSkipFirst:
						if(bitspercomponent!=8) return NO;
						texformat=GL_LUMINANCE_ALPHA;
						#ifdef BIG_ENDIAN
						textype=GL_UNSIGNED_SHORT_8_8_REV_APPLE;
						#else
						textype=GL_UNSIGNED_SHORT_8_8;
						#endif
					break;

					case kCGImageAlphaPremultipliedLast:
					case kCGImageAlphaLast:
					case kCGImageAlphaNoneSkipLast:
						texformat=GL_LUMINANCE_ALPHA;
						textype=XeePickTexType(bitspercomponent,bitmapinfo);
					break;

					default: return NO;
				}

				texintformat=GL_LUMINANCE8_ALPHA8;
			}
			else
			{
				texintformat=GL_LUMINANCE8;
				texformat=GL_LUMINANCE;
				textype=XeePickTexType(bitspercomponent,bitmapinfo);
			}
		break;

		case 3:
			if(alphainfo)
			{
				// could support 1-5-5-5, 4-4-4-4, &c too.
				switch(alphainfo)
				{
					case kCGImageAlphaPremultipliedFirst: // native format
					case kCGImageAlphaFirst:
					case kCGImageAlphaNoneSkipFirst:
						if(bitspercomponent!=8) return NO;
						texformat=GL_BGRA;
						#ifdef BIG_ENDIAN
						textype=GL_UNSIGNED_INT_8_8_8_8_REV;
						#else
						textype=GL_UNSIGNED_INT_8_8_8_8;
						#endif
					break;

					case kCGImageAlphaPremultipliedLast:
					case kCGImageAlphaLast:
					case kCGImageAlphaNoneSkipLast:
						texformat=GL_RGBA;
						textype=XeePickTexType(bitspercomponent,bitmapinfo);
					break;

					default: return NO;
				}

				texintformat=GL_RGBA8;
			}
			else
			{
				texintformat=GL_RGB;
				texformat=GL_RGB;
				textype=XeePickTexType(bitspercomponent,bitmapinfo);
			}
		break;

		case 4:
		default:
			return NO;
		break;
	}

	if(!textype) return NO;

	CGImageRetain(cgimage);
	CGImageRelease(imageref);
	imageref=cgimage;

	return YES;
}

static void BitmapImageReleaseData(void *info,const void *data,size_t size) { free((void *)data); }

-(BOOL)allocWithType:(int)type width:(int)framewidth height:(int)frameheight
{
	if(data) return NO; // maybe dealloc?

	BOOL res=NO;

	int bpcomp=XeeBitmapTypeDepth(type);
	int bitmapinfo=XeeBitmapTypeBitmapInfo(type);

	CGColorSpaceRef colorspace;
	switch(XeeBitmapTypeColorSpace(type))
	{
		case XeeColorSpaceGrey: colorspace=CGColorSpaceCreateDeviceGray(); break;
		case XeeColorSpaceRGB: colorspace=CGColorSpaceCreateDeviceRGB(); break;
		//	CGColorSpaceRef colorspace=CGColorSpaceCreateDeviceRGB();
		//	CGColorSpaceRef colorspace=CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	}

	int bppixel=bpcomp*(CGColorSpaceGetNumberOfComponents(colorspace)+((bitmapinfo&kCGBitmapAlphaInfoMask)?1:0));
//	int bprow=((bppixel/8)*framewidth+3)&~3; // align to 4 bytes
	int bprow=((bppixel/8)*framewidth+15)&~15; // align to 16 bytes

	void *newdata=calloc(bprow*frameheight,1);
	if(newdata)
	{
		CGDataProviderRef provider=CGDataProviderCreateWithData(NULL,newdata,bprow*frameheight,BitmapImageReleaseData);
		if(provider)
		{
			newdata=NULL; // inhibit freeing the memory

			CGImageRef newimage=CGImageCreate(framewidth,frameheight,bpcomp,bppixel,bprow,
			colorspace,bitmapinfo,provider,NULL,NO,kCGRenderingIntentDefault);
			if(newimage)
			{
				res=[self setCGImage:newimage];

				CGImageRelease(newimage);
			}
			CGDataProviderRelease(provider);
		}
		free(newdata);
	}
	CGColorSpaceRelease(colorspace);

	return res;
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

-(CGContextRef)createContext
{
	return CGBitmapContextCreate(data,width,height,8,bytesperrow,CGImageGetColorSpace(imageref),CGImageGetBitmapInfo(imageref));
}



-(CGImageRef)makeCGImage
{
	if(![self isTransformed])
	{
		CGDataProviderRef provider=CGDataProviderCreateWithData(self,data,height*bytesperrow,NULL);
		if(provider)
		{
			[self retain];

			CGImageRef cgimg=CGImageCreate([self width],[self height],
			CGImageGetBitsPerComponent(imageref),CGImageGetBitsPerPixel(imageref),
			bytesperrow,CGImageGetColorSpace(imageref),
			CGImageGetBitmapInfo(imageref),provider,
			NULL,NO,kCGRenderingIntentDefault);

			CGDataProviderRelease(provider);

			return cgimg;
		}
	}
	return [super makeCGImage];
}

-(int)CGImageBitsPerComponent { return CGImageGetBitsPerComponent(imageref); }

-(int)CGImageBitsPerPixel { return CGImageGetBitsPerPixel(imageref); }

-(CGBitmapInfo)CGImageBitmapInfo { return CGImageGetBitmapInfo(imageref); }

-(CGColorSpaceRef)CGImageCopyColorSpace
{
	CGColorSpaceRef colorspace=CGImageGetColorSpace(imageref);
	CGColorSpaceRetain(colorspace);
	return colorspace;
}

-(XeePixelAccessFunc)CGImageReadPixelFunc { return XeeBitmapImageReadPixel; };

-(void *)CGImageReadPixelContext { return &pixelsize; };

@end



static void XeeBitmapImageReleaseData(void *info) { [(id)info release]; }

static void XeeBitmapImageReadPixel(void *datarow,int x,uint8 *pixel,void *context)
{
	int pixelsize=*((int *)context);
	memcpy(pixel,datarow+x*pixelsize,pixelsize);
}


/*-(id)initWithImageRep:(NSBitmapImageRep *)rep
{
	if(self=[self initWithFile:nil firstBlock:nil attributes:nil])
	{
		if(![rep isPlanar])
		{
			int bitmapformat=[rep respondsToSelector:@selector(bitmapFormat)]?[rep bitmapFormat]:0;
			int pixeltype;

			switch([rep bitsPerPixel])
			{
				case 8:
					pixeltype=XeeBitmapTypeLuma8;
					[self setDepthGrey:256];
				break;

				case 24:
					pixeltype=XeeBitmapTypeRGB8;
					[self setDepthRGB:24];
				break;

				case 32:
					if(bitmapformat&NSAlphaFirstBitmapFormat) pixeltype=XeeBitmapTypeARGB8;
					else pixeltype=XeeBitmapTypeRGBA8;
					if([rep samplesPerPixel]==4) [self setDepthRGBA:32];
					else [self setDepthRGB:24];
				break;

				case 48:
					pixeltype=XeeBitmapTypeRGB16;
					[self setDepthRGB:48];
				break;

				case 96:
					if(bitmapformat&NSFloatingPointSamplesBitmapFormat)
					{
						pixeltype=XeeBitmapTypeRGBFloat;
						[self setDepthFloat:32];
					}
					else
					{
						pixeltype=XeeBitmapTypeRGB96;
						[self setDepthRGB:96];
					}
				break;

				default: pixeltype=0; break;
			}

			if(pixeltype)
			{
				[self setData:[rep bitmapData] type:pixeltype width:[rep pixelsWide] height:[rep pixelsHigh] bytesPerRow:[rep bytesPerRow]];

				if([rep samplesPerPixel]==4) [self setTransparent:YES];

				if(!(bitmapformat&NSAlphaNonpremultipliedBitmapFormat)) [self setPremultiplied:YES];

				imagerep=[rep retain];

				return self;
			}
		}
		[self release];
	}
	return nil;
}*/

