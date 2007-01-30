#import "XeeJPEGLoader.h"
#import "XeeBitmapImage.h"
#import "XeeYUVImage.h"
#import "XeeEXIFReader.h"
#import "XeeMemoryJPEGImage.h"
#import "XeeJPEGUtilities.h"



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

-(SEL)initLoader
{
	jpeg_created=NO;
	ycbcr_buffers=NULL;
	cmyk_buffer=NULL;
	thumb_ptr=NULL;
	thumb_len=0;

	cinfo.err=XeeJPEGErrorManager(&jerr);

	jpeg_create_decompress(&cinfo);
	jpeg_created=YES;

	cinfo.dct_method=JDCT_IFAST;

	jpeg_save_markers(&cinfo,JPEG_APP0+1,0xffff);
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

	NSMutableArray *comments=nil;

	for(struct jpeg_marker_struct *marker=cinfo.marker_list;marker;marker=marker->next)
	{
		if(marker->marker==JPEG_APP0+1&&marker->data_length>6&&
		marker->data[0]=='E'&&marker->data[1]=='x'&&marker->data[2]=='i'&&
		marker->data[3]=='f'&&marker->data[4]==0&&marker->data[5]==0)
		{
			XeeEXIFReader *exif=[[XeeEXIFReader alloc] initWithBuffer:marker->data length:marker->data_length];
			if(exif)
			{
				[self setCorrectOrientation:[exif integerForTag:XeeOrientationTag set:XeeStandardTagSet]];

				int thumb_offs=[exif integerForTag:XeeThumbnailOffsetTag set:XeeStandardTagSet];
				if(thumb_offs)
				{
					thumb_len=[exif integerForTag:XeeThumbnailLengthTag set:XeeStandardTagSet];
					thumb_ptr=marker->data+6+thumb_offs;
				}

				[properties addObjectsFromArray:[exif propertyArray]];
				[exif release];
			}
		}
		else if(marker->marker==JPEG_COM)
		{
			if(!comments)
			{
				comments=[NSMutableArray array];
				[properties addObject:[XeePropertyItem itemWithLabel:
				NSLocalizedString(@"File comments",@"File comments section title")
				value:comments]];
			}
			[comments addObject:[XeePropertyItem itemWithLabel:@""
			value:[[[NSString alloc] initWithBytes:marker->data length:marker->data_length
			encoding:NSISOLatin1StringEncoding] autorelease]]];
		}
	}

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
		uint8 *row=maindata+cinfo.output_scanline*bprow;
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
		uint8 *cmyk=cmyk_buffer;
		uint8 *rgb=maindata+cinfo.output_scanline*bprow;

		jpeg_read_scanlines(&cinfo,&cmyk_buffer,1);

		// super-lame CMYK conversion
		for(int x=0;x<width;x++)
		{
			uint8 c=*cmyk++;
			uint8 m=*cmyk++;
			uint8 y=*cmyk++;
			uint8 k=*cmyk++;

		    if(cinfo.saw_Adobe_marker)
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
		XeeImage *thumbnail=[[XeeMemoryJPEGImage alloc] initWithBytes:thumb_ptr length:thumb_len];
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

@end
