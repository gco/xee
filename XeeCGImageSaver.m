#import "XeeCGImageSaver.h"




@implementation XeeCGImageSaver

-(id)initWithImage:(XeeImage *)img
{
	if(self=[super initWithImage:img])
	{
	}
	return self;
}

-(BOOL)save:(NSString *)filename
{
	CGImageRef cgimg=[image makeCGImage];
	BOOL res=NO;

	if(cgimg)
	{
		CGImageDestinationRef dest=CGImageDestinationCreateWithURL(
		(CFURLRef)[NSURL fileURLWithPath:filename],(CFStringRef)[self type],1,NULL);

		if(dest)
		{
			CGImageDestinationAddImage(dest,cgimg,(CFDictionaryRef)[self properties]);
			if(CGImageDestinationFinalize(dest)) res=YES;

			CFRelease(dest);
		}

		CGImageRelease(cgimg);
	}

	return res;
}

-(NSString *)type { return nil; }

-(NSMutableDictionary *)properties
{
	NSMutableDictionary *properties=[NSMutableDictionary dictionary];

	NSColor *back=[[image backgroundColor] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	CGColorSpaceRef colorspace=CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	float components[3]={[back redComponent],[back greenComponent],[back blueComponent]};
	[properties setObject:[(id)CGColorCreate(colorspace,components) autorelease] forKey:(NSString *)kCGImageDestinationBackgroundColor];
	CGColorSpaceRelease(colorspace);

	return properties;
}

+(BOOL)canSaveImage:(XeeImage *)img
{
	CGImageRef cgimg=[img makeCGImage];
	if(!cgimg) return NO;

	int depth=CGImageGetBitsPerComponent(cgimg);
	BOOL floating=CGImageGetBitmapInfo(cgimg)&kCGBitmapFloatComponents?YES:NO;

	CGImageRelease(cgimg);

	return [self canSaveImageWithBitDepth:depth floating:floating];
}

+(BOOL)canSaveImageWithBitDepth:(int)depth floating:(BOOL)floating
{
	return depth==8&&!floating; // handle 8-bit images by default
}

@end



@implementation XeeAlphaSaver

-(id)initWithImage:(XeeImage *)img
{
	if(self=[super initWithImage:img])
	{
		if([image transparent])
		{
			alpha=[[XeeSLSwitch switchWithTitle:nil label:NSLocalizedString(@"Save alpha channel",
			@"Alpha channel checkbox for saving images") defaultValue:YES] retain];
			[self setControl:alpha];
		}
		else alpha=nil;
	}
	return self;
}

-(void)dealloc
{
	[alpha release];
	[super dealloc];
}

-(NSMutableDictionary *)properties
{
	NSMutableDictionary *properties=[super properties];

	[properties setObject:[NSNumber numberWithBool:[alpha value]] forKey:@"kCGImageDestinationAllowAlpha"];

	return properties;
}

@end



@implementation XeePNGSaver

-(id)initWithImage:(XeeImage *)img
{
	if(self=[super initWithImage:img])
	{
		//depth=[[XeeSLPopUp popUpWithTitle:@"Depth:" defaultValue:1 contents:@"256 colors",@"24 bit RGB",nil] retain];

		interlaced=[[XeeSLSwitch switchWithTitle:nil label:NSLocalizedString(@"Interlaced",
		@"Interlaced checkbox for saving PNGs") defaultValue:NO] retain];

		[self setControl:[XeeSLGroup groupWithControls:interlaced,[self control],nil]];
	}
	return self;
}

-(void)dealloc
{
	//[depth release];
	[interlaced release];
	[super dealloc];
}

-(NSString *)format { return @"PNG"; }

-(NSString *)extension { return @"png"; }

-(NSString *)type { return (NSString *)kUTTypePNG; }

-(NSMutableDictionary *)properties
{
	NSMutableDictionary *properties=[super properties];

	if([interlaced value]) [properties setObject:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:YES],(NSString *)kCGImagePropertyPNGInterlaceType,
	nil] forKey:(NSString *)kCGImagePropertyPNGDictionary];

	return properties;
}

+(BOOL)canSaveImageWithBitDepth:(int)depth floating:(BOOL)floating { return (depth==8||depth==16)&&!floating; }

@end




@implementation XeeJPEGSaver

-(id)initWithImage:(XeeImage *)img
{
	if(self=[super initWithImage:img])
	{
		quality=[[XeeSLSlider sliderWithTitle:NSLocalizedString(@"Quality:",@"Quality slider for saving JPEG and JPEG2000")
		minLabel:NSLocalizedString(@"Least",@"Label for lowest quality")
		maxLabel:NSLocalizedString(@"Best",@"Label for highest quality")
		min:0 max:1 defaultValue:0.8] retain];

		[self setControl:quality];
	}
	return self;
}

-(void)dealloc
{
	[quality release];
	[super dealloc];
}

-(NSString *)format { return @"JPEG"; }

-(NSString *)extension { return @"jpg"; }

-(NSString *)type { return (NSString *)kUTTypeJPEG; }

-(NSMutableDictionary *)properties
{
	NSMutableDictionary *properties=[super properties];
	[properties setObject:[NSNumber numberWithFloat:[quality value]] forKey:(NSString *)kCGImageDestinationLossyCompressionQuality];
	return properties;
}

@end



@implementation XeeJP2Saver

-(id)initWithImage:(XeeImage *)img
{
	if(self=[super initWithImage:img])
	{
		quality=[[XeeSLSlider sliderWithTitle:NSLocalizedString(@"Quality:",@"Quality slider for saving JPEG and JPEG2000")
		minLabel:NSLocalizedString(@"Least",@"Label for lowest quality")
		maxLabel:NSLocalizedString(@"Lossless",@"Label for lossless quality")
		min:0 max:1 defaultValue:0.8] retain];

		[self setControl:[XeeSLGroup groupWithControls:quality,[self control],nil]];
	}
	return self;
}

-(void)dealloc
{
	[quality release];
	[super dealloc];
}

-(NSString *)format { return @"JPEG-2000"; }

-(NSString *)extension { return @"jp2"; }

-(NSString *)type { return (NSString *)kUTTypeJPEG2000; }

-(NSMutableDictionary *)properties
{
	NSMutableDictionary *properties=[super properties];
	[properties setObject:[NSNumber numberWithFloat:[quality value]] forKey:(NSString *)kCGImageDestinationLossyCompressionQuality];
	return properties;
}


@end



@implementation XeeTIFFSaver

-(id)initWithImage:(XeeImage *)img
{
	if(self=[super initWithImage:img])
	{
		compression=[[XeeSLPopUp popUpWithTitle:NSLocalizedString(@"Compression:",@"Compression type popup for saving TIFFs")
		defaultValue:1 contents:
		NSLocalizedString(@"None",@"No TIFF compression popup entry"),
		NSLocalizedString(@"LZW",@"LZW TIFF compression popup entry"),
		NSLocalizedString(@"PackBits",@"PackBits TIFF compression popup entry"),
		nil] retain];

		[self setControl:[XeeSLGroup groupWithControls:compression,[self control],nil]];
	}
	return self;
}

-(void)dealloc
{
	[compression release];
	[super dealloc];
}

-(NSString *)format { return @"TIFF"; }

-(NSString *)extension { return @"tiff"; }

-(NSString *)type { return @"public.tiff"; }

-(NSMutableDictionary *)properties
{
	NSMutableDictionary *properties=[super properties];
	switch([compression value])
	{
		case 0:
		break;
		case 1:
			[properties setObject:[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:5],(NSString *)kCGImagePropertyTIFFCompression,
			nil] forKey:(NSString *)kCGImagePropertyPNGDictionary];
		break;
		case 2:
			[properties setObject:[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:32773],(NSString *)kCGImagePropertyTIFFCompression,
			nil] forKey:(NSString *)kCGImagePropertyPNGDictionary];
		break;
	}

	return properties;
}

+(BOOL)canSaveImageWithBitDepth:(int)depth floating:(BOOL)floating
{
	if(depth==8&&!floating) return YES;
	if(depth==16&&!floating) return YES;
	if(depth==32&&floating) return YES;
	return NO;
}

@end



@implementation XeePhotoshopSaver
-(NSString *)format { return @"Photoshop"; }
-(NSString *)extension { return @"psd"; }
-(NSString *)type { return @"com.adobe.photoshop-image"; }
+(BOOL)canSaveImageWithBitDepth:(int)depth floating:(BOOL)floating { return (depth==8||depth==16)&&!floating; }
@end

@implementation XeeOpenEXRSaver
-(NSString *)format { return @"OpenEXR"; }
-(NSString *)extension { return @"exr"; }
-(NSString *)type { return @"com.ilm.openexr-image"; }
+(BOOL)canSaveImageWithBitDepth:(int)depth floating:(BOOL)floating { return depth==32; }
@end




@implementation XeeGIFSaver
-(NSString *)format { return @"GIF"; }
-(NSString *)extension { return @"gif"; }
-(NSString *)type { return (NSString *)kUTTypeGIF; }
@end

@implementation XeePICTSaver
-(NSString *)format { return @"PICT"; }
-(NSString *)extension { return @"pict"; }
-(NSString *)type { return (NSString *)kUTTypePICT; }
@end

@implementation XeeBMPSaver
-(NSString *)format { return @"BMP"; }
-(NSString *)extension { return @"bmp"; }
-(NSString *)type { return (NSString *)kUTTypeBMP; }
-(NSMutableDictionary *)properties
{
	// Force composition of the alpha channel, because it is not actually saved to the file anyway.
	NSMutableDictionary *properties=[super properties];
	[properties setObject:[NSNumber numberWithBool:NO] forKey:@"kCGImageDestinationAllowAlpha"];
	return properties;
}
@end

@implementation XeeTGASaver
-(NSString *)format { return @"Targa"; }
-(NSString *)extension { return @"tga"; }
-(NSString *)type { return @"com.truevision.tga-image"; }
@end

@implementation XeeSGISaver
-(NSString *)format { return @"SGI"; }
-(NSString *)extension { return @"sgi"; }
-(NSString *)type { return @"com.sgi.sgi-image"; }
@end
