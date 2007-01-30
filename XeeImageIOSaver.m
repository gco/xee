#import "XeeImageIOSaver.h"

@implementation XeeCGImageSaver

+(BOOL)canSaveImage:(XeeImage *)img
{
	if(floor(NSAppKitVersionNumber)<=NSAppKitVersionNumber10_3) return NO;

	CGImageRef cgimage=[img createCGImage];
	if(!img) return NO;

	int depth=CGImageGetBitsPerComponent(cgimage);
	int info=CGImageGetBitmapInfo(cgimage);

	CGImageRelease(cgimage);

	return [self canSaveImageWithBitDepth:depth floating:info&kCGBitmapFloatComponents?YES:NO];
}

+(BOOL)canSaveImageWithBitDepth:(int)depth floating:(BOOL)floating
{
	return depth==8&&!floating; // save 8-bit images by default
}

-(BOOL)save:(NSString *)filename
{
	NSURL *url=[NSURL fileURLWithPath:filename];

	CGImageDestinationRef dest=CGImageDestinationCreateWithURL((CFURLRef)url,(CFStringRef)[self type],1,NULL);
	if(!dest) return NO;

	BOOL res=NO;

	CGImageRef cgimage=[image createCGImage];
	if(cgimage)
	{
		CGImageDestinationAddImage(dest,cgimage,(CFDictionaryRef)[self properties]);

		res=CGImageDestinationFinalize(dest);
		CGImageRelease(cgimage);
	}
	CFRelease(dest);

	return res;
}

-(NSString *)type { return nil; }

-(NSMutableDictionary *)properties
{
	NSMutableDictionary *properties=[NSMutableDictionary dictionary];

	NSColor *back=[[image backgroundColor] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	CGColorSpaceRef colorspace=CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);

	if(colorspace&&back)
	{
		float components[4]=
		{
			[back redComponent],
			[back greenComponent],
			[back blueComponent],
			1
		};
		CGColorRef col=CGColorCreate(colorspace,components);
		if(col) [properties setObject:(id)col forKey:(NSString *)kCGImageDestinationBackgroundColor];
	}

	CGColorSpaceRelease(colorspace);

	return properties;
}

@end



@implementation XeeAlphaSaver

-(id)initWithImage:(XeeImage *)img
{
	if(self=[super initWithImage:img])
	{
		if([image transparent])
		{
			alpha=[XeeSLSwitch switchWithTitle:nil label:
			NSLocalizedString(@"Save alpha channel",@"Alpha channel checkbox for saving images")
			defaultValue:YES];
			[self setControl:alpha];
		}
		else alpha=nil;
	}
	return self;
}

-(NSMutableDictionary *)properties
{
	NSMutableDictionary *properties=[super properties];
	[properties setObject:[NSNumber numberWithBool:[alpha value]] forKey:@"kCGImageDestinationAllowAlpha"];
	return properties;
}

@end



@implementation XeePNGSaver

+(BOOL)canSaveImageWithBitDepth:(int)depth floating:(BOOL)floating
{
	return (depth==8||depth==16)&&!floating;
}

-(id)initWithImage:(XeeImage *)img
{
	if(self=[super initWithImage:img])
	{
		//depth=[XeeSLPopUp popUpWithTitle:@"Depth:" defaultValue:1 contents:@"256 colors",@"24 bit RGB",nil];

		interlaced=[XeeSLSwitch switchWithTitle:nil label:
		NSLocalizedString(@"Interlaced",@"Interlaced checkbox for saving PNGs")
		defaultValue:NO];

		[self setControl:[XeeSLGroup groupWithControls:interlaced,[self control],nil]];
	}
	return self;
}

-(NSString *)format { return @"PNG"; }

-(NSString *)extension { return @"png"; }

-(NSString *)type { return (NSString *)kUTTypePNG; }

-(NSMutableDictionary *)properties
{
	NSMutableDictionary *properties=[super properties];
	[properties setObject:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:[interlaced value]],(NSString *)kCGImagePropertyPNGInterlaceType,
	nil] forKey:(NSString *)kCGImagePropertyPNGDictionary];
	return properties;
}

@end



@implementation XeeJPEGSaver

-(id)initWithImage:(XeeImage *)img
{
	if(self=[super initWithImage:img])
	{
		quality=[XeeSLSlider sliderWithTitle:
		NSLocalizedString(@"Quality:",@"Quality slider for saving JPEG and JPEG2000")
		minLabel:NSLocalizedString(@"Least",@"Label for lowest quality")
		maxLabel:NSLocalizedString(@"Best",@"Label for highest quality")
		min:0 max:1 defaultValue:0.8];

		[self setControl:quality];
	}
	return self;
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
		quality=[XeeSLSlider sliderWithTitle:
		NSLocalizedString(@"Quality:",@"Quality slider for saving JPEG and JPEG2000")
		minLabel:NSLocalizedString(@"Least",@"Label for lowest quality")
		maxLabel:NSLocalizedString(@"Lossless",@"Label for lossless quality")
		min:0 max:1 defaultValue:0.8];

		[self setControl:[XeeSLGroup groupWithControls:quality,[self control],nil]];
	}
	return self;
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

+(BOOL)canSaveImageWithBitDepth:(int)depth floating:(BOOL)floating
{
	return (depth==8||depth==16)&&!floating; // can ImageIO save 32 bit/floating TIFF?
}

-(id)initWithImage:(XeeImage *)img
{
	if(self=[super initWithImage:img])
	{
		compression=[XeeSLPopUp popUpWithTitle:
		NSLocalizedString(@"Compression:",@"Compression type popup for saving TIFFs")
		defaultValue:1 contents:
		NSLocalizedString(@"None",@"No TIFF compression popup entry"),
		NSLocalizedString(@"LZW",@"LZW TIFF compression popup entry"),
		NSLocalizedString(@"PackBits",@"PackBits TIFF compression popup entry"),
		nil];

		[self setControl:[XeeSLGroup groupWithControls:compression,[self control],nil]];
	}
	return self;
}

-(NSString *)format { return @"TIFF"; }

-(NSString *)extension { return @"tiff"; }

-(NSString *)type { return (NSString *)kUTTypeTIFF; }

-(NSMutableDictionary *)properties
{
	NSMutableDictionary *properties=[super properties];

	static const int compcodes[]=
	{
		NSTIFFCompressionNone,
		NSTIFFCompressionLZW,
		NSTIFFCompressionPackBits,
	};

	[properties setObject:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:compcodes[[compression value]]],(NSString *)kCGImagePropertyTIFFCompression,
	nil] forKey:(NSString *)kCGImagePropertyTIFFDictionary];

	return properties;
}

@end



@implementation XeePhotoshopSaver

+(BOOL)canSaveImageWithBitDepth:(int)depth floating:(BOOL)floating
{
	return (depth==8||depth==16)&&!floating;
}

-(NSString *)format { return @"Photoshop"; }
-(NSString *)extension { return @"psd"; }
-(NSString *)type { return @"com.adobe.photoshop"; }

@end



@implementation XeeOpenEXRSaver

+(BOOL)canSaveImageWithBitDepth:(int)depth floating:(BOOL)floating
{
	return floating;
}

-(NSString *)format { return @"OpenEXR"; }
-(NSString *)extension { return @"exr"; }
-(NSString *)type { return @"com.ilm.openexr-image"; }

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
