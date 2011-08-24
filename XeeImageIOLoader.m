#import "XeeImageIOLoader.h"
#import "XeeBitmapImage.h"


@implementation XeeImageIOImage

-(id)initWithPasteboard:(NSPasteboard *)pboard
{
	if(self=[super init])
	{
		NSData *data=[pboard dataForType:NSTIFFPboardType];
		if(data)
		{
			source=CGImageSourceCreateWithData((CFDataRef)data,NULL);

			nextselector=[self startLoading];
			[self runLoader];

			if([self completed]&&success) return self;
		}

		[self release];
	}
	return nil;
}


-(SEL)identifyFile
{
	source=NULL;

/*	loaderinfo.fh=fopen([name fileSystemRepresentation],"rb");
	loaderinfo.stop=&stop;

	if(loaderinfo.fh)
	{
		CGDataProviderCallbacks callbacks={
			(CGDataProviderGetBytesCallback)IIOLoaderGetBytes,
			(CGDataProviderSkipBytesCallback)IIOLoaderSkipBytes,
			(CGDataProviderRewindCallback)IIOLoaderRewind,
			(CGDataProviderReleaseInfoCallback)IIOLoaderReleaseInfo
		};
		CGDataProviderRef provider=CGDataProviderCreate(&loaderinfo,&callbacks);
		fclose(loaderinfo.fh);
	}*/

	CGDataProviderRef provider=CGDataProviderCreateWithURL((CFURLRef)[NSURL fileURLWithPath:filename]);
	if(!provider) return NULL;

	NSString *type=[(id)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
	(CFStringRef)[filename pathExtension],CFSTR("public.data")) autorelease];

	source=CGImageSourceCreateWithDataProvider(provider,(CFDictionaryRef)[NSDictionary dictionaryWithObjectsAndKeys:
		type,kCGImageSourceTypeIdentifierHint,
	nil]);

	CGDataProviderRelease(provider);

	return [self startLoading];
}

-(void)deallocLoader
{
	if(source) CFRelease(source);

	[super deallocLoader];
}

-(SEL)startLoading
{
	if(!source) return NULL;

	NSDictionary *cgproperties=(NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source,0,(CFDictionaryRef)[NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:YES],kCGImageSourceShouldAllowFloat,
	nil]);
	if(!cgproperties) return NULL;

	width=[[cgproperties objectForKey:(NSString *)kCGImagePropertyPixelWidth] intValue];
	height=[[cgproperties objectForKey:(NSString *)kCGImagePropertyPixelHeight] intValue];

	NSNumber *orientnum=[cgproperties objectForKey:(NSString *)kCGImagePropertyOrientation];
	if(orientnum) [self setCorrectOrientation:[orientnum intValue]];

	NSMutableArray *array=[NSMutableArray array];
	NSEnumerator *enumerator=[cgproperties keyEnumerator];
	NSString *key;
	while(key=[enumerator nextObject])
	{
		[array addObject:key];
		[array addObject:[cgproperties objectForKey:key]];
	}
	[properties addObject:@"ImageIO properties"];
	[properties addObject:array];

	[self setDepthForImage:self properties:cgproperties];
	[self setFormat:[self formatForType:(NSString *)CGImageSourceGetType(source)]];

	nextindex=0;

	if(thumbnailonly) return @selector(loadThumbnail);
	else return @selector(loadNextImage);
}

-(SEL)loadNextImage
{
//	if(!source) source=[self createImageSource:filename];

	NSDictionary *options=[NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:YES],kCGImageSourceShouldAllowFloat,
		[NSNumber numberWithBool:NO],kCGImageSourceShouldCache,
	nil];

	CGImageRef cgimage=CGImageSourceCreateImageAtIndex(source,nextindex,(CFDictionaryRef)options);

	if(cgimage)
	{
		NSDictionary *imgprops=(NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source,nextindex,(CFDictionaryRef)options);
//NSLog(@"%@",properties);

		CFStringRef colormodel=(CFStringRef)[imgprops objectForKey:(NSString *)kCGImagePropertyColorModel];
		NSNumber *isindexed=[imgprops objectForKey:(NSString *)kCGImagePropertyIsIndexed];
		NSNumber *hasalpha=[imgprops objectForKey:(NSString *)kCGImagePropertyHasAlpha];
		int framedepth=[[imgprops objectForKey:(NSString *)kCGImagePropertyDepth] intValue];

		XeeBitmapImage *image=nil;

		if(colormodel==kCGImagePropertyColorModelCMYK||colormodel==kCGImagePropertyColorModelLab
		||(isindexed&&[isindexed boolValue])||(framedepth&7))
		{
			int type;
			if(hasalpha&&[hasalpha boolValue]) type=XeeBitmapTypePremultipliedARGB8;
			else if(colormodel==kCGImagePropertyColorModelGray) type=XeeBitmapTypeLuma8;
			else type=XeeBitmapTypeNRGB8;

			image=[[[XeeBitmapImage alloc] initWithConvertedCGImage:cgimage type:type] autorelease];
		}
		else
		{
			image=[[[XeeBitmapImage alloc] initWithCGImage:cgimage] autorelease];
		}

		CGImageRelease(cgimage);

		if(image)
		{
			//if() [image setTransparent:YES]
			[self setDepthForImage:image properties:imgprops];
			[self addSubImage:image];
			NSNumber *orientnum=[imgprops objectForKey:(NSString *)kCGImagePropertyOrientation];
			if(orientnum) [image setCorrectOrientation:[orientnum intValue]];
			[image setCompleted];
		}

		[imgprops release];
	}

	nextindex++;

	int count=CGImageSourceGetCount(source);
	if(nextindex>=count) return @selector(loadThumbnail);
	else return @selector(loadNextImage);
}


-(SEL)loadThumbnail
{
	NSDictionary *options=[NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:NO],kCGImageSourceShouldCache,
		[NSNumber numberWithBool:thumbnailonly],kCGImageSourceCreateThumbnailFromImageIfAbsent,
	nil];

	CGImageRef cgimage=CGImageSourceCreateThumbnailAtIndex(source,0,(CFDictionaryRef)options);
	if(cgimage)
	{
		NSDictionary *imgprops=(NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source,0,(CFDictionaryRef)options);
		XeeBitmapImage *image=[[[XeeBitmapImage alloc] initWithCGImage:cgimage] autorelease];

		CGImageRelease(cgimage);

		if(image)
		{
			[self setDepthForImage:image properties:imgprops];
			[self addSubImage:image];
			[image setCompleted];
		}

		[imgprops release];
	}

	if([self frames]) success=YES;
	return NULL;
}

/*static size_t IIOLoaderGetBytes(struct IIOLoaderInfo *info,void *buffer,size_t count)
{
	if(*info->stop) {NSLog(@"stopped");return 0;}
	return fread(buffer,1,count,info->fh);
}

static void IIOLoaderSkipBytes(struct IIOLoaderInfo *info,size_t count)
{
	fseek(info->fh,count,SEEK_CUR);
}

void IIOLoaderRewind(struct IIOLoaderInfo *info)
{
	fseek(info->fh,0,SEEK_SET);
}

void IIOLoaderReleaseInfo(struct IIOLoaderInfo *info)
{
	fclose(info->fh);
}*/

-(void)setDepthForImage:(XeeImage *)image properties:(NSDictionary *)imgprops
{
	CFStringRef colormodel=(CFStringRef)[imgprops objectForKey:(NSString *)kCGImagePropertyColorModel];
	NSNumber *isindexednum=[imgprops objectForKey:(NSString *)kCGImagePropertyIsIndexed];
	NSNumber *isfloatnum=[imgprops objectForKey:(NSString *)kCGImagePropertyIsFloat];
	NSNumber *hasalphanum=[imgprops objectForKey:(NSString *)kCGImagePropertyHasAlpha];
	int framedepth=[[imgprops objectForKey:(NSString *)kCGImagePropertyDepth] intValue];
	BOOL isindexed=isindexednum&&[isindexednum boolValue];
	BOOL isfloat=isfloatnum&&[isfloatnum boolValue];
	BOOL hasalpha=hasalphanum&&[hasalphanum boolValue];

	if(isindexed) [image setDepthIndexed:1<<framedepth];
	else if(colormodel==kCGImagePropertyColorModelGray) [image setDepthGrey:framedepth alpha:hasalpha floating:isfloat];
	else if(colormodel==kCGImagePropertyColorModelRGB) [image setDepthRGB:framedepth alpha:hasalpha floating:isfloat];
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
	nil] retain];

	NSString *shortformat=[formatdict objectForKey:type];
	if(shortformat) return shortformat;
	else return type;
}

+(NSArray *)fileTypes
{
	return [NSBitmapImageRep imageFileTypes];
}

@end
