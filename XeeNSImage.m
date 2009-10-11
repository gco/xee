#import "XeeNSImage.h"


@implementation XeeNSImage

-(id)init
{
	if(self=[super init])
	{
		rep=nil;
	}
	return self;
}

-(id)initWithNSBitmapImageRep:(NSBitmapImageRep *)imagerep
{
	if(self=[super init])
	{
		rep=nil;

		if([self setNSBitmapImageRep:imagerep]) return self;
		[self release];
	}
	return nil;
}


-(void)dealloc
{
	[rep release];
	[super dealloc];
}

-(BOOL)setNSBitmapImageRep:(NSBitmapImageRep *)imagerep
{
	if(!imagerep) return NO;
	if([imagerep isPlanar]) return NO;

	uint8_t *pixeldata=[imagerep bitmapData];
	int pixelwidth=[imagerep pixelsWide];
	int pixelheight=[imagerep pixelsHigh];
	int bppixel=[imagerep bitsPerPixel];
	int bpcomponent=[imagerep bitsPerSample];
	int bprow=[imagerep bytesPerRow];

	int bitmapformat=[imagerep respondsToSelector:@selector(bitmapFormat)]?[imagerep bitmapFormat]:0;
	NSString *colorspace=[imagerep colorSpaceName];

	int components,mode,alpha,flags=0;

	if(!colorspace||[colorspace isEqual:NSCalibratedRGBColorSpace]||[colorspace isEqual:NSDeviceRGBColorSpace])
	{ mode=XeeRGBBitmap; components=3; }
	else if([colorspace isEqual:NSCalibratedWhiteColorSpace]||[colorspace isEqual:NSDeviceWhiteColorSpace])
	{ mode=XeeGreyBitmap; components=1; }
	else return NO;

	if([imagerep hasAlpha])
	{
		if(bitmapformat&NSAlphaNonpremultipliedBitmapFormat)
		{
			if(bitmapformat&NSAlphaFirstBitmapFormat) alpha=XeeAlphaFirst;
			else alpha=XeeAlphaLast;
		}
		else
		{
			if(bitmapformat&NSAlphaFirstBitmapFormat) alpha=XeeAlphaPremultipliedFirst;
			else alpha=XeeAlphaPremultipliedLast;
		}
	}
	else
	{
		if(bppixel==(components+1)*bpcomponent)
		{
			if(bitmapformat&NSAlphaFirstBitmapFormat) alpha=XeeAlphaNoneSkipFirst;
			else alpha=XeeAlphaNoneSkipLast;
		}
		else alpha=XeeAlphaNone;
	}
	if(bitmapformat&NSFloatingPointSamplesBitmapFormat) flags|=XeeBitmapFloatingPointFlag;

	if(![self setData:pixeldata freeData:NO width:pixelwidth height:pixelheight
	bitsPerPixel:bppixel bitsPerComponent:bpcomponent bytesPerRow:bprow
	mode:mode alphaType:alpha flags:flags]) return NO;

	[imagerep retain];
	[rep release];
	rep=imagerep;

	[self setCompleted];

	return YES;
}

@end


/*		if(hasalpha&&!premultiplied) bitmapformat|=NSAlphaNonpremultipliedBitmapFormat;

		if([NSBitmapImageRep instancesRespondToSelector:@selector(initWithBitmapDataPlanes:pixelsWide:pixelsHigh:bitsPerSample:samplesPerPixel:hasAlpha:isPlanar:colorSpaceName:bitmapFormat:bytesPerRow:bitsPerPixel:)])
		{
			imagerep=[[NSBitmapImageRep alloc]
			initWithBitmapDataPlanes:(unsigned char **)&data pixelsWide:width pixelsHigh:height bitsPerSample:bitspersample
			samplesPerPixel:samplesperpixel hasAlpha:hasalpha isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace
			bitmapFormat:bitmapformat bytesPerRow:bytesperrow bitsPerPixel:bitsperpixel];
		}
		else
		{
			if(bitmapformat) imagerep=[[self makeImageRep] retain];
			else imagerep=[[NSBitmapImageRep alloc]
			initWithBitmapDataPlanes:(unsigned char **)&data pixelsWide:width pixelsHigh:height bitsPerSample:bitspersample
			samplesPerPixel:samplesperpixel hasAlpha:hasalpha isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace
			bytesPerRow:bytesperrow bitsPerPixel:bitsperpixel];
		}*/

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
					pixeltype=XeeBitmapTypeRGB48;
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
