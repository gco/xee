#import "XeeQuicktimeLoader.h"

#import "XeeBitmapImage.h"


//#define USE_CGIMAGE


static void XeeSetQTDepth(XeeImage *image,int qtdepth);
static OSErr XeeQTProgressFunc(short message,Fixed completeness,long refcon);



@implementation XeeQuicktimeImage

+(BOOL)canOpenFile:(NSString *)filename firstBlock:(NSData *)block attributes:(NSDictionary *)attrs;
{
	if(
		[[filename pathExtension] caseInsensitiveCompare:@"bmp"]==NSOrderedSame
		||[attrs fileHFSTypeCode]=='BMP '||[attrs fileHFSTypeCode]=='BMP '
		||[[filename pathExtension] caseInsensitiveCompare:@"tga"]==NSOrderedSame
		||[attrs fileHFSTypeCode]=='TPIC'
		||[[filename pathExtension] caseInsensitiveCompare:@"sgi"]==NSOrderedSame
		||[[filename pathExtension] caseInsensitiveCompare:@"rgb"]==NSOrderedSame
		||[attrs fileHFSTypeCode]=='.SGI'
		||[[filename pathExtension] caseInsensitiveCompare:@"nef"]==NSOrderedSame
	) return NO;// explicitly exclude BMP, TGA and SGI - what the hell, Quicktime?

	return YES;
}

-(SEL)initLoader
{
	gi=NULL;

	NSURL *url=[NSURL fileURLWithPath:[self filename]];

	FSRef fsref;
	if(!CFURLGetFSRef((CFURLRef)url,&fsref)) return NULL;

	FSSpec fsspec;
	if(FSGetCatalogInfo(&fsref,kFSCatInfoNone,NULL,NULL,&fsspec,NULL)!=noErr) return NULL;

	if(GetGraphicsImporterForFile(&fsspec,&gi)!=noErr) return NULL;

	ImageDescriptionHandle desc;
	if(GraphicsImportGetImageDescription(gi,&desc)!=noErr) return NULL;

	width=(*desc)->width;
	height=(*desc)->height;

	[self setFormat:[[[NSString alloc] initWithBytes:(*desc)->name+1 length:(*desc)->name[0]
	encoding:CFStringConvertEncodingToNSStringEncoding(CFStringGetSystemEncoding())] autorelease]];

	int qtdepth=(*desc)->depth;
	XeeSetQTDepth(self,qtdepth);

	DisposeHandle((Handle)desc);

	current_image=-1;

	return @selector(loadNextImage);
}

-(void)deallocLoader
{
	if(gi) CloseComponent(gi);
}


-(SEL)loadNextImage
{
	unsigned long count;
	GraphicsImportGetImageCount(gi,&count);

	current_image++;

	if(thumbonly)
	{
		if(current_image==0)
		{
			if(GraphicsImportSetImageIndexToThumbnail(gi)!=noErr)
			if(GraphicsImportSetImageIndex(gi,1)!=noErr)
			return NULL;
		}
		else
		{
			loaded=YES;
			return NULL;
		}
	}
	else
	{
		if(current_image==count)
		{
			loaded=YES;
			return NULL;
		}
		else
		{
			if(GraphicsImportSetImageIndex(gi,current_image+1)!=noErr) return @selector(loadNextImage);
		}
	}
	return @selector(loadImage);
}

-(SEL)loadImage
{
	EnterMoviesOnThread(0);

	struct ICMProgressProcRecord progrec={XeeQTProgressFunc,(long)self};
	GraphicsImportSetProgressProc(gi,&progrec);

	GraphicsImportSetQuality(gi,codecLosslessQuality);

	ImageDescriptionHandle desc;
	if(GraphicsImportGetImageDescription(gi,&desc)!=noErr) return @selector(loadNextImage);

	int framewidth=(*desc)->width;
	int frameheight=(*desc)->height;
	int framedepth=(*desc)->depth;
	current_height=frameheight;

	DisposeHandle((Handle)desc);

	#ifdef USE_CGIMAGE
	// 10.4 code using CGImages. QT seems buggy and gets the size of the CGImage wrong.

	CGImageRef cgimage;
	if(GraphicsImportCreateCGImage(gi,&cgimage,kGraphicsImportCreateCGImageUsingCurrentSettings)!=noErr) return @selector(loadNextImage);

	XeeBitmapImage *image;
	if(framedepth>32&&framedepth!=40) image=[[[XeeBitmapImage alloc] initWithConvertedCGImage:cgimage type:XeeBitmapTypeLuma8] autorelease];
	else image=[[[XeeBitmapImage alloc] initWithCGImage:cgimage] autorelease];
	if(!image) return @selector(loadNextImage);

	XeeSetQTDepth(image,framedepth);

	[self addSubImage:image];
	[image setCompleted];

	CGImageRelease(cgimage);

	#else

	int type;
	OSType pixelformat;

	if(framedepth>32)
	{
		type=XeeBitmapTypeLuma8;
		pixelformat=k8IndexedGrayPixelFormat;
	}
	//else if([format isEqual:@"JPEG"]&&[[NSUserDefaults standardUserDefaults] integerForKey:@"jpegYUV"]==1)
	//{
	//	type=XeeBitmapTypeYUV422;
	//	pixelformat=k2vuyPixelFormat;
	//}
	else if(framedepth==32||framedepth==16)
	{
		pixelformat=k32ARGBPixelFormat;
		type=XeeBitmapTypeARGB8;
	}
	else
	{
		type=XeeBitmapTypeRGB8;
		pixelformat=k24RGBPixelFormat;
	}

	XeeBitmapImage *image=[[[XeeBitmapImage alloc] initWithType:type width:framewidth height:frameheight] autorelease];
	if(!image) return @selector(loadNextImage);

	XeeSetQTDepth(image,framedepth);

	GWorldPtr gw;
	Rect rect;
	SetRect(&rect,0,0,framewidth,frameheight);
	if(QTNewGWorldFromPtr(&gw,pixelformat,&rect,NULL,NULL,0,[image data],[image bytesPerRow])!=noErr) return @selector(loadNextImage);

	if(GraphicsImportSetGWorld(gi,gw,NULL)==noErr)
	{
//		[self addSubImage:image];

		if(GraphicsImportDraw(gi)==noErr)
		{
			//if(type==XeeBitmapTypeYUV422) [image fixYUVGamma];
			if(type==XeeBitmapTypeLuma8)
			{
				unsigned long *ptr=(unsigned long *)[image data];
				int n=[image bytesPerRow]*frameheight/4;
				while(n--) *ptr=~*ptr++;
			}

			[self addSubImage:image];
			[image setCompleted];
		}
	}

	DisposeGWorld(gw);
	#endif

	ExitMoviesOnThread();

	return @selector(loadNextImage);
}

-(XeeBitmapImage *)currentImage { return [subimages objectAtIndex:[subimages count]-1]; }

-(int)currentHeight { return current_height; }



+(void)load
{
	EnterMovies();
}

+(NSArray *)fileTypes
{
	return [NSArray arrayWithObjects:
		@"jpg", // JPEG Image
		@"jpeg",
		@"jpe",
		@"'JPEG'",

		@"png", // Portable Network Graphics
		@"'PNG '", 
		@"'PNGf'", 

		@"gif", // Graphics Interchange Format
		@"'GIFf'",
		@"'GIF '",

		@"tif", // TIFF Image
		@"tiff", 
		@"'TIFF'", 

		@"bmp", // Windows Bitmap Image
		@"dib", //?
		@"'BMP '", 
		@"'BMPf'", 
		@"'BMPp'", 

		@"psd", // Adobe Photoshop Image
		@"'8BPS'",

		@"tga", // Targa Image
		@"'TPIC'", 

		@"jp2", // JPEG 2000 Image
		@"'jp2 '", 

		@"pict", // PICT Image
		@"pct", 
		@"pic",
		@"'PICT'", 

		@"fpx", // FlashPix Image
		@"'FPix'", 

		@"qtif", // Apple Quicktime Image
		@"qti",
		@"qif", 
		@"'qtif'", 

		@"sgi", // Silicon Graphics Image
		@"'SGI '", 
		@"'.SGI'", 

		@"pntg", // Apple MacPaint image
		@"'PNTG'", 

		@"mac", //?

		nil
	];
}


@end

static void XeeSetQTDepth(XeeImage *image,int qtdepth)
{
	if(qtdepth<=8) [image setDepthIndexed:(1<<qtdepth)];
	else if(qtdepth>32) [image setDepthGrey:qtdepth-32];
	else if(qtdepth==15) [image setDepth:@"5:5:5 bit RGB" iconName:@"depth_rgb"];
	else if(qtdepth==16) [image setDepth:@"1:5:5:5 bit ARGB" iconName:@"depth_rgba"];
	else if(qtdepth==24) [image setDepthRGB:8];
	else if(qtdepth==32) [image setDepthRGBA:8];
}

static OSErr XeeQTProgressFunc(short message,Fixed completeness,long refcon)
{
	XeeQuicktimeImage *image=(XeeQuicktimeImage *)refcon; // ow ow ow, 64-bit issues!

	if([image hasBeenStopped]) return codecAbortErr;

	return noErr;
}
