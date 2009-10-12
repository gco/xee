#import "XeeJPEGLoader.h"
#import "XeeBitmapImage.h"
#import "XeeYUVImage.h"
#import "XeeJPEGUtilities.h"
#import "XeeJPEGQuantizationDatabase.h"
#import "XeeEXIFParser.h"
#import "Xee8BIMParser.h"
#import "XeeIPTCParser.h"
#import "XeeXMPParser.h"
#import "XeeDuckyParser.h"

#import <XADMaster/CSMemoryHandle.h>
#import <XADMaster/CSMultiHandle.h>



@implementation XeeJPEGImage

+(NSArray *)fileTypes
{
	return [NSArray arrayWithObjects:@"jpg",@"jpeg",@"jpe",@"'JPEG'",nil];
}

+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;
{
	const unsigned char *head=[block bytes];
	int len=[block length];

	if(len>=2&&head[0]==0xff&&head[1]==0xd8) return YES;

	return NO;
}
/*
-(SEL)initLoader
{
	jpeg_created=NO;
	ycbcr_buffers=NULL;
	cmyk_buffer=NULL;
	invert_cmyk=NO;
	thumb_ptr=NULL;
	thumb_len=0;

	cinfo.err=XeeJPEGErrorManager(&jerr);

	jpeg_create_decompress(&cinfo);
	jpeg_created=YES;

	cinfo.dct_method=JDCT_IFAST;

	for(int i=0;i<16;i++) jpeg_save_markers(&cinfo,JPEG_APP0+i,0xffff);
	jpeg_save_markers(&cinfo,JPEG_COM,0xffff);

	jpeg_stdio_src(&cinfo,[[self fileHandle] filePointer]);
	jpeg_read_header(&cinfo,TRUE);

	width=cinfo.image_width;
	height=cinfo.image_height;

	mcu_width=DCTSIZE*cinfo.max_h_samp_factor;
	mcu_height=DCTSIZE*cinfo.max_v_samp_factor;

	switch(cinfo.jpeg_color_space)
	{
		case JCS_GRAYSCALE:
			cinfo.out_color_space=JCS_GRAYSCALE;
			[self setDepthGrey:8];
		break;
		case JCS_RGB:
			cinfo.out_color_space=JCS_RGB;
			[self setDepthRGB:8];
		break;
		case JCS_YCbCr:
			cinfo.out_color_space=JCS_RGB;
			[self setDepth:[NSString stringWithFormat:
			@"YCbCr H%dV%d",cinfo.max_h_samp_factor,cinfo.max_v_samp_factor]
			iconName:@"depth_rgb"];
		break;
		case JCS_CMYK:
			cinfo.out_color_space=JCS_CMYK;
			[self setDepthCMYK:8 alpha:NO];
		break;
		case JCS_YCCK:
			cinfo.out_color_space=JCS_CMYK;
			[self setDepth:@"YCCK" iconName:@"depth_cmyk"];
		break;
		default: [self setDepth:@"Unknown"]; break;
	}

	// Parse saved markers (EXIF and comments)

	NSMutableArray *markerprops=[NSMutableArray array];
	NSMutableArray *comments=[NSMutableArray array];
	NSArray *exifprops=nil,*xmpprops=nil,*photoshopprops=nil,*duckyprops=nil;

	for(struct jpeg_marker_struct *marker=cinfo.marker_list;marker;marker=marker->next)
	{
		if(marker->marker==JPEG_COM)
		{
			[comments addObjectsFromArray:[XeePropertyItem itemsWithLabel:@""
			textValue:[[[NSString alloc] initWithBytes:marker->data length:marker->data_length
			encoding:NSISOLatin1StringEncoding] autorelease]]];
		}

		else if(XeeTestJPEGMarker(marker,0,5,"JFIF"))
		{
			[markerprops addObject:[XeePropertyItem itemWithLabel:
			NSLocalizedString(@"JFIF APP0 marker",@"JFIF APP0 marker property title")
			value:NSLocalizedString(@"(parsed)",@"Property value for parsed APPx blocks")]];
		}
		else if(XeeTestJPEGMarker(marker,0,5,"JFXX"))
		{
			[markerprops addObject:[XeePropertyItem itemWithLabel:
			NSLocalizedString(@"Extended JFIF APP0 marker",@"Extended JFIF APP0 marker property title")
			value:@""]];
		}
		else if(XeeTestJPEGMarker(marker,1,6,"Exif\000"))
		{
			[markerprops addObject:[XeePropertyItem itemWithLabel:
			NSLocalizedString(@"Exif APP1 marker",@"Exif APP1 marker property title")
			value:NSLocalizedString(@"(parsed)",@"Property value for parsed APPx blocks")]];

			XeeEXIFParser *exif=[[XeeEXIFParser alloc] initWithBuffer:marker->data+6 length:marker->data_length-6];
			if(exif)
			{
				[self setCorrectOrientation:[exif integerForTag:XeeOrientationTag set:XeeStandardTagSet]];

				int thumb_offs=[exif integerForTag:XeeThumbnailOffsetTag set:XeeStandardTagSet];
				if(thumb_offs)
				{
					thumb_len=[exif integerForTag:XeeThumbnailLengthTag set:XeeStandardTagSet];
					thumb_ptr=marker->data+6+thumb_offs;
				}

				exifprops=[exif propertyArray];
				[exif release];
			}
		}
		else if(XeeTestJPEGMarker(marker,1,29,"http://ns.adobe.com/xap/1.0/"))
		{
			[markerprops addObject:[XeePropertyItem itemWithLabel:
			NSLocalizedString(@"XMP APP1 marker",@"XMP APP1 marker property title")
			value:NSLocalizedString(@"(parsed)",@"Property value for parsed APPx blocks")]];

			XeeXMPParser *xmp=[[XeeXMPParser alloc] initWithHandle:
			[CSMemoryHandle memoryHandleForReadingBuffer:marker->data+29 length:marker->data_length-29]];
			xmpprops=[xmp propertyArray];
			[xmp release];
		}
		else if(XeeTestJPEGMarker(marker,2,12,"ICC_PROFILE"))
		{
			[markerprops addObject:[XeePropertyItem itemWithLabel:
			NSLocalizedString(@"ICC profile APP2 marker",@"ICC profile APP2 marker property title")
			value:@""]];
		}
		else if(XeeTestJPEGMarker(marker,3,6,"META\000")||XeeTestJPEGMarker(marker,3,6,"Meta\000"))
		{
			[markerprops addObject:[XeePropertyItem itemWithLabel:
			NSLocalizedString(@"Meta APP3 marker",@"Meta APP3 marker property title")
			value:@""]];
		}
		else if(XeeTestJPEGMarker(marker,12,5,"Ducky"))
		{
			[markerprops addObject:[XeePropertyItem itemWithLabel:
			NSLocalizedString(@"Ducky APP12 marker",@"Ducky APP12 marker property title")
			value:NSLocalizedString(@"(parsed)",@"Property value for parsed APPx blocks")]];

			XeeDuckyParser *ducky=[[XeeDuckyParser alloc] initWithBuffer:marker->data+5 length:marker->data_length-5];
			duckyprops=[ducky propertyArray];
			[ducky release];
		}
		else if(XeeTestJPEGMarker(marker,13,14,"Photoshop 3.0"))
		{
			[markerprops addObject:[XeePropertyItem itemWithLabel:
			NSLocalizedString(@"Photoshop APP13 marker",@"Photoshop APP13 marker property title")
			value:NSLocalizedString(@"(parsed)",@"Property value for parsed APPx blocks")]];

			Xee8BIMParser *parser=[[Xee8BIMParser alloc] initWithHandle:
			[CSMemoryHandle memoryHandleForReadingBuffer:marker->data+14 length:marker->data_length-14]];
			photoshopprops=[parser propertyArrayWithPhotoshopFirst:NO];
			[parser release];
		}
		else if(XeeTestJPEGMarker(marker,14,5,"Adobe"))
		{
			[markerprops addObject:[XeePropertyItem itemWithLabel:
			NSLocalizedString(@"Adobe APP14 marker",@"Adobe APP14 marker property title")
			value:XeeHexDump(&marker->data[5],marker->data_length-5,16)]];
			if(marker->data_length==12&&marker->data[11]==2) invert_cmyk=YES;
		}
		else
		{
			[markerprops addObject:[XeePropertyItem itemWithLabel:[NSString stringWithFormat:
			NSLocalizedString(@"APP%d marker",@"Unknown APPx marker property title"),marker->marker-JPEG_APP0]
			value:XeeHexDump(marker->data,marker->data_length,16)]];
		}
	}

	if([comments count]) [properties addObject:[XeePropertyItem itemWithLabel:
	NSLocalizedString(@"File comments",@"File comments section title")
	value:comments identifier:@"common.comments"]];

	if(exifprops) [properties addObjectsFromArray:exifprops];
	if(xmpprops) [properties addObjectsFromArray:xmpprops];
	if(photoshopprops) [properties addObjectsFromArray:photoshopprops];
	if(duckyprops) [properties addObjectsFromArray:duckyprops];

	NSMutableArray *jpegprops=[NSMutableArray array];
	[jpegprops addObjectsFromArray:[[XeeJPEGQuantizationDatabase defaultDatabase] propertyArrayForTables:&cinfo]];
	[jpegprops addObjectsFromArray:markerprops];
	[properties addObject:[XeePropertyItem itemWithLabel:
	NSLocalizedString(@"JPEG properties",@"JPEG properties section title")
	value:jpegprops identifier:@"jpeg"]];

	[self setFormat:@"JPEG"];

	if(thumbonly&&thumb_ptr) return @selector(loadThumbnail);
	return @selector(startLoading);
}

-(void)deallocLoader
{
	if(jpeg_created) jpeg_destroy_decompress(&cinfo);
	free(ycbcr_buffers);
	free(cmyk_buffer);
}

-(SEL)startLoading
{
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"jpegYUV"]
	&&cinfo.jpeg_color_space==JCS_YCbCr&&cinfo.comp_info[0].h_samp_factor==2
	&&(cinfo.comp_info[0].v_samp_factor==2||cinfo.comp_info[0].v_samp_factor==1)
	&&cinfo.comp_info[1].h_samp_factor==1&&cinfo.comp_info[1].v_samp_factor==1
	&&cinfo.comp_info[2].h_samp_factor==1&&cinfo.comp_info[2].v_samp_factor==1)
	{
		mainimage=[[[XeeYUVImage alloc] initWithWidth:width height:height] autorelease];
		cinfo.raw_data_out=TRUE;

		int y_width=(width+7)&~7;
		int y_rows=8*cinfo.comp_info[0].v_samp_factor;
		int cbcr_width=((width+1)/2+7)&~7;

		ycbcr_buffers=malloc(y_rows*y_width+2*8*cbcr_width);
		if(!ycbcr_buffers) return NULL;

		y_buf=ycbcr_buffers;
		cb_buf=ycbcr_buffers+y_rows*y_width;
		cr_buf=ycbcr_buffers+y_rows*y_width+8*cbcr_width;

		for(int i=0;i<y_rows;i++) y_lines[i]=y_buf+i*y_width;
		for(int i=0;i<8;i++) cb_lines[i]=cb_buf+i*cbcr_width;
		for(int i=0;i<8;i++) cr_lines[i]=cr_buf+i*cbcr_width;
		image[0]=y_lines;
		image[1]=cb_lines;
		image[2]=cr_lines;
	}
	else
	{
		int type;

		if(cinfo.jpeg_color_space==JCS_GRAYSCALE) type=XeeBitmapTypeLuma8;
		else type=XeeBitmapTypeRGB8;

		if(cinfo.out_color_space==JCS_CMYK)
		{
			cmyk_buffer=malloc(width*4);
			if(!cmyk_buffer) return NULL;
		}

		mainimage=[[[XeeBitmapImage alloc] initWithType:type width:width height:height] autorelease];
	}

	if(!mainimage) return NULL;

	[mainimage setDepth:[self depth]];
	[mainimage setDepthIcon:[self depthIcon]];
	if(correctorientation) [mainimage setCorrectOrientation:correctorientation];
	[self addSubImage:mainimage];

	jpeg_start_decompress(&cinfo);

	if(cinfo.raw_data_out) return @selector(loadYUV);
	else if(cinfo.out_color_space==JCS_CMYK) return @selector(loadCMYK);
	else return @selector(loadRGBOrGrey);
}



-(SEL)loadRGBOrGrey
{
	unsigned char *maindata=[mainimage data];
	int bprow=[mainimage bytesPerRow];

	for(int i=0;i<16;i++)
	{
		uint8_t *row=maindata+cinfo.output_scanline*bprow;
		jpeg_read_scanlines(&cinfo,&row,1);
		[mainimage setCompletedRowCount:cinfo.output_scanline];

		if(cinfo.output_scanline>=cinfo.output_height)
		{
			loaded=YES;
			return @selector(loadThumbnail);
		}
	}
	return @selector(loadRGBOrGrey);
}


-(SEL)loadCMYK
{
	unsigned char *maindata=[mainimage data];
	int bprow=[mainimage bytesPerRow];

	for(int i=0;i<16;i++)
	{
		uint8_t *cmyk=cmyk_buffer;
		uint8_t *rgb=maindata+cinfo.output_scanline*bprow;

		jpeg_read_scanlines(&cinfo,&cmyk_buffer,1);

		// super-lame CMYK conversion
		for(int x=0;x<width;x++)
		{
			uint8_t c=*cmyk++;
			uint8_t m=*cmyk++;
			uint8_t y=*cmyk++;
			uint8_t k=*cmyk++;

		    if(invert_cmyk)
			{
				*rgb++=(k*c)/255;
				*rgb++=(k*m)/255;
				*rgb++=(k*y)/255;
		    }
			else
			{
				*rgb++=(255-k)*(255-c)/255;
				*rgb++=(255-k)*(255-m)/255;
				*rgb++=(255-k)*(255-y)/255;
			}
		}

		[mainimage setCompletedRowCount:cinfo.output_scanline];

		if(cinfo.output_scanline>=cinfo.output_height)
		{
			loaded=YES;
			return @selector(loadThumbnail);
		}
	}
	return @selector(loadCMYK);
}

-(SEL)loadYUV
{
	unsigned char *maindata=[mainimage data];
	int bprow=[mainimage bytesPerRow];

	int start_line=cinfo.output_scanline;
	int num_lines=8*cinfo.comp_info[0].v_samp_factor;
	jpeg_read_raw_data(&cinfo,image,num_lines);

	for(int y=0;y<num_lines;y++)
	{
		if(start_line+y>=height) break;
		unsigned char *row=maindata+(start_line+y)*bprow;

		JSAMPLE *y_row=y_lines[y];
		JSAMPLE *cb_row=cb_lines[y/cinfo.comp_info[0].v_samp_factor];
		JSAMPLE *cr_row=cr_lines[y/cinfo.comp_info[0].v_samp_factor];

		XeeJPEGPlanarToChunky(row,y_row,cb_row,cr_row,width);
	}

	[mainimage setCompletedRowCount:cinfo.output_scanline];

	if(cinfo.output_scanline>=cinfo.output_height)
	{
		loaded=YES;
		return @selector(loadThumbnail);
	}
	return @selector(loadYUV);
}

-(SEL)loadThumbnail
{
	if(thumb_ptr)
	{
		XeeJPEGImage *thumbnail=[[XeeJPEGImage alloc] initWithHandle:[CSMemoryHandle memoryHandleForReadingBuffer:thumb_ptr length:thumb_len]];
		if(thumbnail)
		{
			if(correctorientation) [thumbnail setCorrectOrientation:correctorientation];
			[self addSubImage:thumbnail];
			[thumbnail release];

			loaded=YES; // for thumbnail-only loading
		}
	}
	return NULL;
}

*/




-(id)init
{
	if(self=[super init])
	{
		jpeg_created=NO;
		thumbhandle=nil;
		overwriting=NO;
	}
	return self;
}

-(void)dealloc
{
	if(jpeg_created) jpeg_destroy_decompress(&cinfo);
	[thumbhandle release];
	[super dealloc];
}

-(void)load
{
	cinfo.err=XeeJPEGErrorManager(&jerr);

	jpeg_create_decompress(&cinfo);
	jpeg_created=YES;

	cinfo.dct_method=JDCT_IFAST;

	for(int i=0;i<16;i++) jpeg_save_markers(&cinfo,JPEG_APP0+i,0xffff);
	jpeg_save_markers(&cinfo,JPEG_COM,0xffff);

	cinfo.src=XeeJPEGSourceManager(&jsrc,[self handle]);
	jpeg_read_header(&cinfo,TRUE);

	width=cinfo.image_width;
	height=cinfo.image_height;

	mcu_width=DCTSIZE*cinfo.max_h_samp_factor;
	mcu_height=DCTSIZE*cinfo.max_v_samp_factor;

	switch(cinfo.jpeg_color_space)
	{
		case JCS_GRAYSCALE:
			cinfo.out_color_space=JCS_GRAYSCALE;
			[self setDepthGrey:8];
		break;
		case JCS_RGB:
			cinfo.out_color_space=JCS_RGB;
			[self setDepthRGB:8];
		break;
		case JCS_YCbCr:
			cinfo.out_color_space=JCS_RGB;
			[self setDepth:[NSString stringWithFormat:
			@"YCbCr H%dV%d",cinfo.max_h_samp_factor,cinfo.max_v_samp_factor]
			iconName:@"depth_rgb"];
		break;
		case JCS_CMYK:
			cinfo.out_color_space=JCS_CMYK;
			[self setDepthCMYK:8 alpha:NO];
		break;
		case JCS_YCCK:
			cinfo.out_color_space=JCS_CMYK;
			[self setDepth:@"YCCK" iconName:@"depth_cmyk"];
		break;
		default: [self setDepth:@"Unknown"]; break;
	}

	// Parse saved markers (EXIF and comments)

	NSMutableArray *markerprops=[NSMutableArray array];
	NSMutableArray *comments=[NSMutableArray array];
	NSMutableArray *exifhandles=[NSMutableArray array];
	NSMutableArray *xmphandles=[NSMutableArray array];
	NSMutableArray *pshandles=[NSMutableArray array];
	NSArray *duckyprops=nil;
	BOOL invert_cmyk=NO;

	for(struct jpeg_marker_struct *marker=cinfo.marker_list;marker;marker=marker->next)
	{
		if(marker->marker==JPEG_COM)
		{
			[comments addObjectsFromArray:[XeePropertyItem itemsWithLabel:@""
			textValue:[[[NSString alloc] initWithBytes:marker->data length:marker->data_length
			encoding:NSISOLatin1StringEncoding] autorelease]]];
		}
		else if(XeeTestJPEGMarker(marker,0,5,"JFIF"))
		{
			[markerprops addObject:[XeePropertyItem itemWithLabel:
			NSLocalizedString(@"JFIF APP0 marker",@"JFIF APP0 marker property title")
			value:NSLocalizedString(@"(parsed)",@"Property value for parsed APPx blocks")]];
		}
		else if(XeeTestJPEGMarker(marker,0,5,"JFXX"))
		{
			[markerprops addObject:[XeePropertyItem itemWithLabel:
			NSLocalizedString(@"Extended JFIF APP0 marker",@"Extended JFIF APP0 marker property title")
			value:@""]];
		}
		else if(XeeTestJPEGMarker(marker,1,6,"Exif\000"))
		{
			[markerprops addObject:[XeePropertyItem itemWithLabel:
			NSLocalizedString(@"Exif APP1 marker",@"Exif APP1 marker property title")
			value:NSLocalizedString(@"(parsed)",@"Property value for parsed APPx blocks")]];

			[exifhandles addObject:[CSMemoryHandle memoryHandleForReadingBuffer:marker->data+6 length:marker->data_length-6]];
		}
		else if(XeeTestJPEGMarker(marker,1,29,"http://ns.adobe.com/xap/1.0/"))
		{
			[markerprops addObject:[XeePropertyItem itemWithLabel:
			NSLocalizedString(@"XMP APP1 marker",@"XMP APP1 marker property title")
			value:NSLocalizedString(@"(parsed)",@"Property value for parsed APPx blocks")]];

			[xmphandles addObject:[CSMemoryHandle memoryHandleForReadingBuffer:marker->data+29 length:marker->data_length-29]];
		}
		else if(XeeTestJPEGMarker(marker,2,12,"ICC_PROFILE"))
		{
			[markerprops addObject:[XeePropertyItem itemWithLabel:
			NSLocalizedString(@"ICC profile APP2 marker",@"ICC profile APP2 marker property title")
			value:@""]];
		}
		else if(XeeTestJPEGMarker(marker,3,6,"META\000")||XeeTestJPEGMarker(marker,3,6,"Meta\000"))
		{
			[markerprops addObject:[XeePropertyItem itemWithLabel:
			NSLocalizedString(@"Meta APP3 marker",@"Meta APP3 marker property title")
			value:@""]];
		}
		else if(XeeTestJPEGMarker(marker,12,5,"Ducky"))
		{
			[markerprops addObject:[XeePropertyItem itemWithLabel:
			NSLocalizedString(@"Ducky APP12 marker",@"Ducky APP12 marker property title")
			value:NSLocalizedString(@"(parsed)",@"Property value for parsed APPx blocks")]];

			XeeDuckyParser *ducky=[[XeeDuckyParser alloc] initWithBuffer:marker->data+5 length:marker->data_length-5];
			duckyprops=[ducky propertyArray];
			[ducky release];
		}
		else if(XeeTestJPEGMarker(marker,13,14,"Photoshop 3.0"))
		{
			[markerprops addObject:[XeePropertyItem itemWithLabel:
			NSLocalizedString(@"Photoshop APP13 marker",@"Photoshop APP13 marker property title")
			value:NSLocalizedString(@"(parsed)",@"Property value for parsed APPx blocks")]];

			[pshandles addObject:[CSMemoryHandle memoryHandleForReadingBuffer:marker->data+14 length:marker->data_length-14]];
		}
		else if(XeeTestJPEGMarker(marker,14,5,"Adobe"))
		{
			[markerprops addObject:[XeePropertyItem itemWithLabel:
			NSLocalizedString(@"Adobe APP14 marker",@"Adobe APP14 marker property title")
			value:XeeHexDump(&marker->data[5],marker->data_length-5,16)]];

			if(marker->data_length==12&&marker->data[11]==2) invert_cmyk=YES;
		}
		else
		{
			[markerprops addObject:[XeePropertyItem itemWithLabel:[NSString stringWithFormat:
			NSLocalizedString(@"APP%d marker",@"Unknown APPx marker property title"),marker->marker-JPEG_APP0]
			value:XeeHexDump(marker->data,marker->data_length,16)]];
		}
	}

	if([comments count])
	{
		[properties addObject:[XeePropertyItem itemWithLabel:
		NSLocalizedString(@"File comments",@"File comments section title")
		value:comments identifier:@"common.comments"]];
	}

	if([exifhandles count])
	{
		CSHandle *exifhandle=[CSMultiHandle multiHandleWithHandleArray:exifhandles];
		NSData *data=[exifhandle remainingFileContents];
		XeeEXIFParser *exif=[[XeeEXIFParser alloc] initWithBuffer:[data bytes] length:[data length]];
		if(exif)
		{
			[self setCorrectOrientation:[exif integerForTag:XeeOrientationTag set:XeeStandardTagSet]];

			int offs=[exif integerForTag:XeeThumbnailOffsetTag set:XeeStandardTagSet];
			if(offs)
			{
				int len=[exif integerForTag:XeeThumbnailLengthTag set:XeeStandardTagSet];
				thumbhandle=[[exifhandle subHandleFrom:offs length:len] retain];
				[thumbhandle seekToFileOffset:0];
			}

			[properties addObjectsFromArray:[exif propertyArray]];
			[exif release];
		}
	}

	if([xmphandles count])
	{
		XeeXMPParser *xmp=[[XeeXMPParser alloc] initWithHandle:[CSMultiHandle multiHandleWithHandleArray:xmphandles]];
		[properties addObjectsFromArray:[xmp propertyArray]];
		[xmp release];
	}

	if([pshandles count])
	{
		Xee8BIMParser *parser=[[Xee8BIMParser alloc] initWithHandle:[CSMultiHandle multiHandleWithHandleArray:pshandles]];
		[properties addObjectsFromArray:[parser propertyArrayWithPhotoshopFirst:NO]];
		[parser release];
	}

	if(duckyprops) [properties addObjectsFromArray:duckyprops];

	NSMutableArray *jpegprops=[NSMutableArray array];
	[jpegprops addObjectsFromArray:[[XeeJPEGQuantizationDatabase defaultDatabase] propertyArrayForTables:&cinfo]];
	[jpegprops addObjectsFromArray:markerprops];
	[properties addObject:[XeePropertyItem itemWithLabel:
	NSLocalizedString(@"JPEG properties",@"JPEG properties section title")
	value:jpegprops identifier:@"jpeg"]];

	[self setFormat:@"JPEG"];

	XeeImageLoaderHeaderDone();

	if(!thumbonly||!thumbhandle)
	{
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"jpegYUV"]
		&&cinfo.jpeg_color_space==JCS_YCbCr&&cinfo.comp_info[0].h_samp_factor==2
		&&(cinfo.comp_info[0].v_samp_factor==2||cinfo.comp_info[0].v_samp_factor==1)
		&&cinfo.comp_info[1].h_samp_factor==1&&cinfo.comp_info[1].v_samp_factor==1
		&&cinfo.comp_info[2].h_samp_factor==1&&cinfo.comp_info[2].v_samp_factor==1)
		{
			mainimage=[[[XeeYUVImage alloc] initWithWidth:width height:height] autorelease];
			if(!mainimage) XeeImageLoaderDone(NO);
			[self addSubImage:mainimage];

			int num_lines=8*cinfo.comp_info[0].v_samp_factor;
			int y_width=(width+7)&~7;
			int y_rows=8*cinfo.comp_info[0].v_samp_factor;
			int cbcr_width=((width+1)/2+7)&~7;
			uint8_t y_buf[y_rows*y_width];
			uint8_t cb_buf[8*cbcr_width];
			uint8_t cr_buf[8*cbcr_width];
			JSAMPROW y_lines[y_rows],cb_lines[8],cr_lines[8];
			JSAMPARRAY image[3]={y_lines,cb_lines,cr_lines};

			for(int i=0;i<y_rows;i++) y_lines[i]=y_buf+i*y_width;
			for(int i=0;i<8;i++) cb_lines[i]=cb_buf+i*cbcr_width;
			for(int i=0;i<8;i++) cr_lines[i]=cr_buf+i*cbcr_width;

			cinfo.raw_data_out=TRUE;
			jpeg_start_decompress(&cinfo);
			while(cinfo.output_scanline<cinfo.output_height)
			{
				int start_line=cinfo.output_scanline;
				jpeg_read_raw_data(&cinfo,image,num_lines);

				for(int y=0;y<num_lines;y++)
				{
					if(start_line+y>=height) break;
					uint8_t *row=XeeImageDataRow(mainimage,start_line+y);

					JSAMPLE *y_row=y_lines[y];
					JSAMPLE *cb_row=cb_lines[y/cinfo.comp_info[0].v_samp_factor];
					JSAMPLE *cr_row=cr_lines[y/cinfo.comp_info[0].v_samp_factor];
					XeeJPEGPlanarToChunky(row,y_row,cb_row,cr_row,width);
				}

				[mainimage setCompletedRowCount:cinfo.output_scanline];
				XeeImageLoaderYield();
			}
		}
		else if(cinfo.out_color_space==JCS_CMYK)
		{
			mainimage=[[[XeeBitmapImage alloc] initWithType:XeeBitmapTypeRGB8 width:width height:height] autorelease];
			if(!mainimage) XeeImageLoaderDone(NO);
			[self addSubImage:mainimage];

			uint8_t cmyk_buffer[width*4];
			//JSAMPARRAY ...

			jpeg_start_decompress(&cinfo);
			while(cinfo.output_scanline<cinfo.output_height)
			{
				uint8_t *cmyk=cmyk_buffer;
				uint8_t *rgb=XeeImageDataRow(mainimage,cinfo.output_scanline);

				jpeg_read_scanlines(&cinfo,&cmyk,1);

				// super-lame CMYK conversion
				for(int x=0;x<width;x++)
				{
					uint8_t c=*cmyk++;
					uint8_t m=*cmyk++;
					uint8_t y=*cmyk++;
					uint8_t k=*cmyk++;

					if(invert_cmyk)
					{
						*rgb++=(k*c)/255;
						*rgb++=(k*m)/255;
						*rgb++=(k*y)/255;
					}
					else
					{
						*rgb++=(255-k)*(255-c)/255;
						*rgb++=(255-k)*(255-m)/255;
						*rgb++=(255-k)*(255-y)/255;
					}
				}
				[mainimage setCompletedRowCount:cinfo.output_scanline];
				XeeImageLoaderYield();
			}
		}
		else
		{
			if(cinfo.jpeg_color_space==JCS_GRAYSCALE) mainimage=[[[XeeBitmapImage alloc] initWithType:XeeBitmapTypeLuma8 width:width height:height] autorelease];
			else mainimage=[[[XeeBitmapImage alloc] initWithType:XeeBitmapTypeRGB8 width:width height:height] autorelease];
			if(!mainimage) XeeImageLoaderDone(NO);
			[self addSubImage:mainimage];

			jpeg_start_decompress(&cinfo);
			while(cinfo.output_scanline<cinfo.output_height)
			{
				uint8_t *row=XeeImageDataRow(mainimage,cinfo.output_scanline);
				jpeg_read_scanlines(&cinfo,&row,1);
				[mainimage setCompletedRowCount:cinfo.output_scanline];
				XeeImageLoaderYield();
			}
		}
	}

	if(thumbhandle)
	{
		XeeJPEGImage *thumbnail=[[XeeJPEGImage alloc] initWithHandle:thumbhandle];
		if(thumbnail)
		{
			if(correctorientation) [thumbnail setCorrectOrientation:correctorientation];
			[self addSubImage:thumbnail];
			[self runLoaderOnSubImage:thumbnail];
			[thumbnail release];
		}
		[thumbhandle release];
		thumbhandle=nil;
	}

	jpeg_destroy_decompress(&cinfo);
	jpeg_created=NO;

	XeeImageLoaderDone(YES);
}

@end
