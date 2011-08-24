#import "XeeQuicktimeLoader.h"

#import "XeeBitmapImage.h"
#import "XeeNSImageLoader.h"


//#define USE_CGIMAGE


void set_qt_depth(XeeImage *image,int qtdepth)
{
	if(qtdepth<=8) [image setDepthIndexed:(1<<qtdepth)];
	else if(qtdepth>32) [image setDepthGrey:(qtdepth-32)];
	else if(qtdepth==15) [image setDepth:@"5:5:5 bit RGB" iconName:@"depth_rgb"];
	else if(qtdepth==16) [image setDepth:@"1:5:5:5 bit ARGB" iconName:@"depth_rgba"];
	else if(qtdepth==24) [image setDepthRGB:8];
	else if(qtdepth==32) [image setDepthRGBA:8];
}



@implementation XeeQuicktimeImage

-(SEL)identifyFile
{
	gi=NULL;

/*	if(
		[[filename pathExtension] caseInsensitiveCompare:@"bmp"]==NSOrderedSame
		||[attrs fileHFSTypeCode]=='BMP '||[attrs fileHFSTypeCode]=='BMP '
		||[[filename pathExtension] caseInsensitiveCompare:@"tga"]==NSOrderedSame
		||[attrs fileHFSTypeCode]=='TPIC'
		||[[filename pathExtension] caseInsensitiveCompare:@"sgi"]==NSOrderedSame
		||[[filename pathExtension] caseInsensitiveCompare:@"rgb"]==NSOrderedSame
		||[attrs fileHFSTypeCode]=='.SGI'
		||[[filename pathExtension] caseInsensitiveCompare:@"nef"]==NSOrderedSame
		||[[filename pathExtension] caseInsensitiveCompare:@"dng"]==NSOrderedSame
		||[[filename pathExtension] caseInsensitiveCompare:@"pict"]==NSOrderedSame
		||[[filename pathExtension] caseInsensitiveCompare:@"pct"]==NSOrderedSame
		||[attrs fileHFSTypeCode]=='PICT'
	) return NULL; // explicitly exclude formats that Quicktime chokes on*/

	NSURL *url=[NSURL fileURLWithPath:filename];
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

	set_qt_depth(self,(*desc)->depth);

	DisposeHandle((Handle)desc);

	EnterMoviesOnThread(0);

	current_image=-1;

	return @selector(loadNextImage);
}

-(void)deallocLoader
{
	if(gi) CloseComponent(gi);

	ExitMoviesOnThread();

	[super deallocLoader];
}


static OSErr progress_func(short message,Fixed completeness,long refcon)
{
	XeeQuicktimeImage *image=(XeeQuicktimeImage *)refcon; // ow ow ow, 64-bit issues!

	if([image hasBeenStopped]) return codecAbortErr;

#if 0
	static int i=0;
	if((i++)%32==0)
	{
		XeeBitmapImage *subimage=[image finalSubImage];
		[subimage triggerChangeAction];
	}
#endif

	return noErr;
}

-(SEL)loadNextImage
{
	unsigned long count;
	GraphicsImportGetImageCount(gi,&count);

	current_image++;

	if(thumbnailonly)
	{
		if(currindex==0)
		{
			if(GraphicsImportSetImageIndexToThumbnail(gi)!=noErr)
			if(GraphicsImportSetImageIndex(gi,1)!=noErr) return NULL;
			return @selector(loadImage);
		}
	}
	else
	{
		if(current_image<count)
		{
			if(GraphicsImportSetImageIndex(gi,current_image+1)!=noErr) return NULL;
			return @selector(loadImage);
		}
	}

	success=YES;
	return NULL;
}

-(SEL)loadImage
{
	struct ICMProgressProcRecord progrec={progress_func,(long)self};
	GraphicsImportSetProgressProc(gi,&progrec);
	GraphicsImportSetQuality(gi,codecLosslessQuality);

	ImageDescriptionHandle desc;
	if(GraphicsImportGetImageDescription(gi,&desc)!=noErr) return NULL;

	int framewidth=(*desc)->width;
	int frameheight=(*desc)->height;
	int framedepth=(*desc)->depth;
	DisposeHandle((Handle)desc);

	#ifdef USE_CGIMAGE
	// 10.4 code using CGImages. QT seems buggy and gets the size of the CGImage wrong.

	CGImageRef cgimage;
	if(GraphicsImportCreateCGImage(gi,&cgimage,kGraphicsImportCreateCGImageUsingCurrentSettings)==noErr)
	{
		XeeBitmapImage *image;

		if(framedepth>32&&framedepth!=40) image=[[[XeeBitmapImage alloc] initWithConvertedCGImage:cgimage type:XeeBitmapTypeLuma8] autorelease];
		else image=[[[XeeBitmapImage alloc] initWithCGImage:cgimage] autorelease];

		if(image)
		{
			set_qt_depth(image,framedepth);

			[self addSubImage:image];
			[image setCompleted];
		}
		CGImageRelease(cgimage);
	}
	else
	{
		if(stop) return @selector(loadImage);
		else return NULL;
	}

	#else

	int type;
	OSType pixelformat;

	if(framedepth>32)
	{
		type=XeeBitmapTypeLuma8;
		pixelformat=k8IndexedGrayPixelFormat;
	}
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
	if(image)
	{
		set_qt_depth(image,framedepth);

		GWorldPtr gw;
		Rect rect;
		SetRect(&rect,0,0,framewidth,frameheight);
		if(QTNewGWorldFromPtr(&gw,pixelformat,&rect,NULL,NULL,0,[image data],[image bytesPerRow])==noErr)
		{
			if(GraphicsImportSetGWorld(gi,gw,NULL)==noErr)
			{
//				[self addSubImage:image];

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
				else
				{
					if(stop) return @selector(loadImage);
					else return NULL;
				}
			}
			DisposeGWorld(gw);
		}
	}
	#endif

	return @selector(loadNextImage);
}

-(XeeBitmapImage *)finalSubImage { return [subimages objectAtIndex:[subimages count]-1]; }



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
