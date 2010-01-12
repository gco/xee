#import "XeeImageIOLoader.h"
#import "XeeCGImage.h"


@implementation XeeImageIOImage

static size_t XeeImageIOGetBytes(void *info, void *buffer, size_t count) { return [(CSHandle *)info readAtMost:count toBuffer:buffer]; }
static void XeeImageIOSkipBytes(void *info, size_t count) { [(CSHandle *)info skipBytes:count]; }
static void XeeImageIORewind(void *info) { [(CSHandle *)info seekToFileOffset:0]; }
static void XeeImageIOReleaseInfo(void *info) { [(CSHandle *)info release]; }

+(NSArray *)fileTypes
{
	return [NSBitmapImageRep imageFileTypes];
}

+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes
{
	return floor(NSAppKitVersionNumber)>NSAppKitVersionNumber10_3;
}

-(SEL)initLoader
{
	source=NULL;

	NSMutableDictionary *options=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:YES],kCGImageSourceShouldAllowFloat,
	nil];

	if(ref)
	{
		NSString *type=[(NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
		(CFStringRef)[[self filename] pathExtension],CFSTR("public.data")) autorelease];
		//if([type isEqual:(NSString *)kUTTypePICT]) return NULL;
		[options setObject:type forKey:(NSString *)kCGImageSourceTypeIdentifierHint];
	}


//	CGDataProviderRef provider=CGDataProviderCreateWithURL((CFURLRef)[NSURL fileURLWithPath:[self filename]]);
	CGDataProviderCallbacks callbacks=
	{ XeeImageIOGetBytes,XeeImageIOSkipBytes,XeeImageIORewind,XeeImageIOReleaseInfo };
	CGDataProviderRef provider=CGDataProviderCreate([[self handle] retain],&callbacks);
	if(!provider) return NULL;

	source=CGImageSourceCreateWithDataProvider(provider,(CFDictionaryRef)options);
	CGDataProviderRelease(provider);
	if(!source) return NULL;

	NSDictionary *cgproperties=[(id)CGImageSourceCopyPropertiesAtIndex(source,0,(CFDictionaryRef)options) autorelease];
	if(!cgproperties) return NULL;

	width=[[cgproperties objectForKey:(NSString *)kCGImagePropertyPixelWidth] intValue];
	height=[[cgproperties objectForKey:(NSString *)kCGImagePropertyPixelHeight] intValue];

	[self setDepthForImage:self properties:cgproperties];
	[self setFormat:[self formatForType:(NSString *)CGImageSourceGetType(source)]];

	NSNumber *orientnum=[cgproperties objectForKey:(NSString *)kCGImagePropertyOrientation];
	if(orientnum) [self setCorrectOrientation:[orientnum intValue]];

	[properties addObjectsFromArray:[self convertCGProperties:cgproperties]];

	current_image=0;

	if(thumbonly) return @selector(loadThumbnail);
	return @selector(loadImage);
}

-(void)deallocLoader
{
	if(source) CFRelease(source);
}

-(SEL)loadImage
{
	int count=CGImageSourceGetCount(source);
	if(current_image==count) return @selector(loadThumbnail);

	NSDictionary *options=[NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:YES],kCGImageSourceShouldAllowFloat,
		[NSNumber numberWithBool:NO],kCGImageSourceShouldCache,
	nil];

	CGImageRef cgimage=CGImageSourceCreateImageAtIndex(source,current_image++,(CFDictionaryRef)options);
	if(!cgimage) return @selector(loadImage);

	NSDictionary *cgproperties=[(id)CGImageSourceCopyPropertiesAtIndex(source,current_image-1,(CFDictionaryRef)options) autorelease];

	CFStringRef colormodel=(CFStringRef)[cgproperties objectForKey:(NSString *)kCGImagePropertyColorModel];
	NSNumber *isindexed=[cgproperties objectForKey:(NSString *)kCGImagePropertyIsIndexed];
	NSNumber *hasalpha=[cgproperties objectForKey:(NSString *)kCGImagePropertyHasAlpha];
	//int framedepth=[[cgproperties objectForKey:(NSString *)kCGImagePropertyDepth] intValue];

	XeeBitmapImage *image=nil;

	if(colormodel!=kCGImagePropertyColorModelCMYK&&colormodel!=kCGImagePropertyColorModelLab
	&&!(isindexed&&[isindexed boolValue]))
	{
		image=[[[XeeCGImage alloc] initWithCGImage:cgimage] autorelease];

		NSNumber *photometric=[[cgproperties objectForKey:@"{TIFF}"] objectForKey:@"PhotometricInterpretation"];
		if(photometric&&[photometric intValue]==0) [(XeeCGImage *)image invertImage];
	}

	if(!image)
	{
		int type;
		if(hasalpha&&[hasalpha boolValue]) type=XeeBitmapTypePremultipliedARGB8;
		else if(colormodel==kCGImagePropertyColorModelGray) type=XeeBitmapTypeLuma8;
		else type=XeeBitmapTypeNRGB8;

		int pixelwidth=CGImageGetWidth(cgimage);
		int pixelheight=CGImageGetHeight(cgimage);

		image=[[[XeeBitmapImage alloc] initWithType:type width:pixelwidth height:pixelheight] autorelease];

		if(image)
		{
			CGContextRef cgcontext=[image createCGContext];
			if(cgcontext)
			{
				CGContextDrawImage(cgcontext,CGRectMake(0,0,pixelwidth,pixelheight),cgimage);
				CGContextRelease(cgcontext);
			}
			else image=nil;
		}
	}

	CGImageRelease(cgimage);

	if(!image) return @selector(loadImage);

	[self setDepthForImage:image properties:cgproperties];

	NSNumber *orientnum=[cgproperties objectForKey:(NSString *)kCGImagePropertyOrientation];
	if(orientnum) [image setCorrectOrientation:[orientnum intValue]];

	[self addSubImage:image];
	[image setCompleted];

	return @selector(loadImage);
}

-(SEL)loadThumbnail
{
	loaded=!thumbonly;

	NSDictionary *options=[NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:NO],kCGImageSourceShouldCache,
		[NSNumber numberWithBool:thumbonly],kCGImageSourceCreateThumbnailFromImageIfAbsent,
	nil];

	CGImageRef cgimage=CGImageSourceCreateThumbnailAtIndex(source,0,(CFDictionaryRef)options);
	if(!cgimage) return NULL;

	NSDictionary *cgproperties=[(id)CGImageSourceCopyPropertiesAtIndex(source,0,(CFDictionaryRef)options) autorelease];
	XeeCGImage *image=[[[XeeCGImage alloc] initWithCGImage:cgimage] autorelease];

	NSNumber *photometric=[[cgproperties objectForKey:@"{TIFF}"] objectForKey:@"PhotometricInterpretation"];
	if(photometric&&[photometric intValue]==0) [image invertImage];

	CGImageRelease(cgimage);

	if(!image) return NULL;

	[self setDepthForImage:image properties:cgproperties];
	[self addSubImage:image];
	[image setCompleted];

	loaded=YES;
	return NULL;
}

-(void)setDepthForImage:(XeeImage *)image properties:(NSDictionary *)cgproperties
{
	CFStringRef colormodel=(CFStringRef)[cgproperties objectForKey:(NSString *)kCGImagePropertyColorModel];
	NSNumber *indexednum=[cgproperties objectForKey:(NSString *)kCGImagePropertyIsIndexed];
	NSNumber *floatnum=[cgproperties objectForKey:(NSString *)kCGImagePropertyIsFloat];
	NSNumber *alphanum=[cgproperties objectForKey:(NSString *)kCGImagePropertyHasAlpha];
	int framedepth=[[cgproperties objectForKey:(NSString *)kCGImagePropertyDepth] intValue];
	BOOL isindexed=indexednum&&[indexednum boolValue];
	BOOL isfloat=floatnum&&[floatnum boolValue];
	BOOL hasalpha=alphanum&&[alphanum boolValue];

	if(isindexed) [image setDepthIndexed:1<<framedepth];
	else if(colormodel==kCGImagePropertyColorModelGray) [image setDepthGrey:framedepth alpha:hasalpha floating:isfloat];
	else if(colormodel==kCGImagePropertyColorModelRGB)  [image setDepthRGB:framedepth alpha:hasalpha floating:isfloat];
	else if(colormodel==kCGImagePropertyColorModelCMYK) [image setDepthCMYK:framedepth alpha:hasalpha];
	else if(colormodel==kCGImagePropertyColorModelLab) [image setDepthLab:framedepth alpha:hasalpha];
}

-(NSString *)formatForType:(NSString *)type
{
	static NSDictionary *formatdict=nil;
	if(!formatdict) formatdict=[[NSDictionary dictionaryWithObjectsAndKeys:
		@"TIFF",@"public.tiff",
		@"BMP",@"com.microsoft.bmp",
		@"GIF",@"com.compuserve.gif",
		@"JPEG",@"public.jpeg",
		@"PICT",@"com.apple.pict",
		@"PNG",@"public.png",
		@"QTIF",@"com.apple.quicktime-image",
		@"TGA",@"com.truevision.tga-image",
		@"SGI",@"com.sgi.sgi-image",
		@"PSD",@"com.adobe.photoshop-image",
		@"PNTG",@"com.apple.macpaint-image",
		@"FPX",@"com.kodak.flashpix-image",
		@"JPEG2000",@"public.jpeg-2000",
		@"ICO",@"com.microsoft.ico",
		@"XBM",@"public.xbitmap-image",
		@"EXR",@"com.ilm.openexr-image",
		@"Fax",@"public.fax",
		@"Icns",@"com.apple.icns",
		@"Radiance",@"public.radiance",
		@"PCX",@"cx.c3.pcx",
		@"IFF ILBM",@"com.ea.iff-ilbm",
		@"DNG",@"com.adobe.raw-image",
		@"Leica",@"com.leica.raw-image",
		@"RAW",@"com.panasonic.raw-image",
		@"DCR",@"com.kodak.raw-image",
		@"CR2",@"com.canon.cr2-raw-image",
		@"CRW",@"com.canon.crw-raw-image",
		@"MRW",@"com.konicaminolta.raw-image",
		@"RAF",@"com.fuji.raw-image",
		@"NEF",@"com.nikon.raw-image",
		@"ORF",@"com.olympus.raw-image",
		@"SRF",@"com.sony.raw-image",
		@"PEF",@"com.pentax.raw-image",
	nil] retain];

	NSString *shortformat=[formatdict objectForKey:type];
	if(shortformat) return shortformat;
	else return type;
}

-(NSArray *)convertCGProperties:(NSDictionary *)cgproperties
{
	NSMutableArray *array=[NSMutableArray array];
	NSBundle *imageio=[NSBundle bundleWithIdentifier:@"com.apple.ImageIO.framework"];

	NSEnumerator *enumerator=[cgproperties keyEnumerator];
	NSString *key;
	while(key=[enumerator nextObject])
	{
		id value=[cgproperties objectForKey:key];
		if(![value isKindOfClass:[NSDictionary class]]) continue;

		NSString *keyname=[imageio localizedStringForKey:key value:key table:@"CGImageSource"];

		[array addObject:[XeePropertyItem itemWithLabel:keyname
		value:[self convertCGPropertyValues:value imageIOBundle:imageio]
		identifier:[NSString stringWithFormat:@"%@.%@",@"imageio",key]]];
	}

	[array sortUsingSelector:@selector(compare:)];

	[array addObject:[XeePropertyItem itemWithLabel:
	NSLocalizedString(@"More properties",@"More properties (from ImageIO.framework) section title")
	value:[self convertCGPropertyValues:cgproperties imageIOBundle:imageio]]];

	return array;
}

-(NSArray *)convertCGPropertyValues:(NSDictionary *)cgproperties imageIOBundle:(NSBundle *)imageio
{
	NSMutableArray *array=[NSMutableArray array];
	NSEnumerator *enumerator=[cgproperties keyEnumerator];
	NSString *key;
	while(key=[enumerator nextObject])
	{
		id value=[cgproperties objectForKey:key];
		key=[imageio localizedStringForKey:key value:key table:@"CGImageSource"];

		if([value isKindOfClass:[NSDictionary class]]) continue;
		else if([value isKindOfClass:[NSArray class]])
		[array addObjectsFromArray:[XeePropertyItem itemsWithLabel:key valueArray:value]];
		else
		[array addObject:[XeePropertyItem itemWithLabel:key value:value]];
	}
	[array sortUsingSelector:@selector(compare:)];
	return array;
}

@end
