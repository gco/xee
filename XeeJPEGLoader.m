#import "XeeJPEGLoader.h"
#import "XeeBitmapImage.h"
#import "XeeYUVImage.h"



#import "XeeJPEGLoader.h"
#import "XeeBitmapImage.h"
#import "XeeYUVImage.h"
#import "XeeEXIFReader.h"
#import "XeeLoaderMisc.h"
#import "libjpeg/transupp.h"



static struct jpeg_error_mgr *XeeJPEGErrorHandler(struct jpeg_error_mgr *jerr);
static void XeeYUVChunkyToPlanar(uint8 *y_row,uint8 *cb_row,uint8 *cr_row,uint8 *dest_row,int width);



@implementation XeeJPEGImage

-(SEL)identifyFile
{
	jpeg_created=NO;
	mainimage=nil;
	raw=NULL;
	thumbnail=NULL;
	thumbnail_length=0;

	const unsigned char *headbytes=[header bytes];
	if([header length]<2||headbytes[0]!=0xff||headbytes[1]!=0xd8) return NULL;

	cinfo.err=XeeJPEGErrorHandler(&jerr);

	jpeg_create_decompress(&cinfo);
	jpeg_created=YES;

	jpeg_stdio_src(&cinfo,[[self fileHandle] filePointer]);
	jpeg_save_markers(&cinfo,JPEG_APP0+1,0xFFFF);
	jpeg_save_markers(&cinfo,JPEG_COM,0xFFFF);
	jpeg_read_header(&cinfo,TRUE);

	width=cinfo.image_width;
	height=cinfo.image_height;
	mcu_width=cinfo.max_h_samp_factor*DCTSIZE;
	mcu_height=cinfo.max_v_samp_factor*DCTSIZE;

	switch(cinfo.jpeg_color_space)
	{
		case JCS_GRAYSCALE: [self setDepthGrey:8]; break;
		case JCS_RGB: [self setDepthRGB:8]; break;
		case JCS_YCbCr:
			[self setDepth:[NSString stringWithFormat:@"YCbCr H%dV%d",cinfo.max_h_samp_factor,cinfo.max_v_samp_factor]
			iconName:@"depth_rgb"];
		break;
		case JCS_CMYK: [self setDepthCMYK:8 alpha:NO]; break;
		case JCS_YCCK: [self setDepth:@"YCCK"]; break;
		default: [self setDepth:@"Unknown"]; break;
	}

//	if(cinfo.jpeg_color_space==)
//	{
//	[self setDepth:

	jpeg_saved_marker_ptr marker=cinfo.marker_list;

	NSMutableArray *commentprops=nil;
	while(marker)
	{
		switch(marker->marker)
		{
			case JPEG_APP0+1:
			{
				XeeEXIFReader *exif=[[XeeEXIFReader alloc] initWithData:[NSData dataWithBytes:marker->data length:marker->data_length]];
				if(exif)
				{
					[properties addObjectsFromArray:[exif propertyArray]];

					[self setCorrectOrientation:[exif integerForTag:EXIFOrientationTag set:EXIFStandardTagSet]];

					int thumbnail_start=[exif integerForTag:EXIFJPEGInterchangeFormatTag set:EXIFStandardTagSet];
					thumbnail_length=[exif integerForTag:EXIFJPEGInterchangeFormatLengthTag set:EXIFStandardTagSet];
					if(thumbnail_start&&thumbnail_length) thumbnail=marker->data+thumbnail_start+6;

					[exif release];
				}
			}
			break;

			case JPEG_COM:
				if(!commentprops) commentprops=[NSMutableArray array];
				[commentprops addObject:@""];
				[commentprops addObject:XeeNSStringFromByteBuffer(marker->data,marker->data_length)];
			break;
		}

		marker=marker->next;
	}

	if(commentprops)
	{
		[properties addObject:@"JPEG comments"];
		[properties addObject:commentprops];
	}

	[self setFormat:@"JPEG"];

	if(thumbnail&&thumbnailonly) return @selector(finishLoading);
	else return @selector(startLoading);
}

-(void)deallocLoader
{
	if(jpeg_created) jpeg_destroy_decompress(&cinfo);
	if(raw) free(raw);

	[super deallocLoader];
}



static const unsigned char gammatable[256]=
{
	0x00,0x00,0x01,0x01,0x02,0x02,0x03,0x03,0x04,0x04,0x05,0x05,0x06,0x07,0x07,0x08,
	0x09,0x09,0x0a,0x0b,0x0b,0x0c,0x0d,0x0d,0x0e,0x0f,0x10,0x10,0x11,0x12,0x13,0x13,
	0x14,0x15,0x16,0x17,0x17,0x18,0x19,0x1a,0x1b,0x1b,0x1c,0x1d,0x1e,0x1f,0x1f,0x20,
	0x21,0x22,0x23,0x24,0x25,0x25,0x26,0x27,0x28,0x29,0x2a,0x2b,0x2c,0x2c,0x2d,0x2e,
	0x2f,0x30,0x31,0x32,0x33,0x34,0x35,0x35,0x36,0x37,0x38,0x39,0x3a,0x3b,0x3c,0x3d,
	0x3e,0x3f,0x40,0x41,0x42,0x43,0x44,0x45,0x45,0x46,0x47,0x48,0x49,0x4a,0x4b,0x4c,
	0x4d,0x4e,0x4f,0x50,0x51,0x52,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5a,0x5b,0x5c,
	0x5d,0x5e,0x5f,0x60,0x61,0x62,0x63,0x64,0x65,0x67,0x68,0x69,0x6a,0x6b,0x6c,0x6d,
	0x6e,0x6f,0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7b,0x7c,0x7d,0x7e,
	0x7f,0x80,0x81,0x82,0x83,0x84,0x85,0x86,0x87,0x89,0x8a,0x8b,0x8c,0x8d,0x8e,0x8f,
	0x90,0x91,0x92,0x94,0x95,0x96,0x97,0x98,0x99,0x9a,0x9b,0x9c,0x9e,0x9f,0xa0,0xa1,
	0xa2,0xa3,0xa4,0xa5,0xa7,0xa8,0xa9,0xaa,0xab,0xac,0xad,0xaf,0xb0,0xb1,0xb2,0xb3,
	0xb4,0xb5,0xb7,0xb8,0xb9,0xba,0xbb,0xbc,0xbd,0xbf,0xc0,0xc1,0xc2,0xc3,0xc4,0xc6,
	0xc7,0xc8,0xc9,0xca,0xcb,0xcd,0xce,0xcf,0xd0,0xd1,0xd3,0xd4,0xd5,0xd6,0xd7,0xd8,
	0xda,0xdb,0xdc,0xdd,0xde,0xe0,0xe1,0xe2,0xe3,0xe4,0xe6,0xe7,0xe8,0xe9,0xea,0xec,
	0xed,0xee,0xef,0xf0,0xf2,0xf3,0xf4,0xf5,0xf6,0xf8,0xf9,0xfa,0xfb,0xfd,0xfe,0xff,
};

-(SEL)startLoading
{
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"jpegYUV"]
	&&cinfo.jpeg_color_space==JCS_YCbCr
	&&cinfo.comp_info[0].h_samp_factor==2&&(cinfo.comp_info[0].v_samp_factor==2||cinfo.comp_info[0].v_samp_factor==1)
	&&cinfo.comp_info[1].h_samp_factor==1&&cinfo.comp_info[1].v_samp_factor==1
	&&cinfo.comp_info[2].h_samp_factor==1&&cinfo.comp_info[2].v_samp_factor==1)
	{
		mainimage=[[[XeeYUVImage alloc] initWithWidth:width height:height] autorelease];

		cinfo.raw_data_out=TRUE;

		int cbcr_lines=cinfo.comp_info[0].v_samp_factor==2?8:16;
		int y_width=(width+7)&~7;
		int cbcr_width=((width+1)/2+7)&~7;
		int y_size=16*y_width;
		int cbcr_size=cbcr_lines*cbcr_width;

		raw=malloc(sizeof(struct raw_data)+y_size+2*cbcr_size);
		if(!raw) return NULL;

		JSAMPLE *y_buf=raw->data;
		JSAMPLE *cb_buf=raw->data+y_size;
		JSAMPLE *cr_buf=raw->data+y_size+cbcr_size;

		for(int i=0;i<16;i++) raw->y_lines[i]=y_buf+i*y_width;
		for(int i=0;i<cbcr_lines;i++) raw->cb_lines[i]=cb_buf+i*cbcr_width;
		for(int i=0;i<cbcr_lines;i++) raw->cr_lines[i]=cr_buf+i*cbcr_width;
		raw->image[0]=raw->y_lines;
		raw->image[1]=raw->cb_lines;
		raw->image[2]=raw->cr_lines;
	}
	else
	{
		int type;
		if(cinfo.jpeg_color_space==JCS_GRAYSCALE) type=XeeBitmapTypeLuma8;
		else type=XeeBitmapTypeRGB8;

		mainimage=[[[XeeBitmapImage alloc] initWithType:type width:width height:height] autorelease];
	}

	if(!mainimage) return NULL;

	[mainimage setDepth:[self depth]];
	[mainimage setDepthIcon:[self depthIcon]];
	[mainimage setCorrectOrientation:correctorientation];
	[self addSubImage:mainimage];

	cinfo.dct_method=JDCT_IFAST;
	jpeg_start_decompress(&cinfo);

	return @selector(load);
}

-(SEL)load
{
	unsigned char *maindata=[mainimage data];
	int bprow=[mainimage bytesPerRow];

	if(cinfo.raw_data_out)
	{
		int start_line=cinfo.output_scanline;
		jpeg_read_raw_data(&cinfo,raw->image,2*DCTSIZE);

		for(int y=0;y<16;y++)
		{
			if(start_line+y>=height) break;
			unsigned char *row=maindata+(start_line+y)*bprow;

			if(cinfo.comp_info[0].v_samp_factor==2)
			XeeYUVChunkyToPlanar(raw->y_lines[y],raw->cb_lines[y/2],raw->cr_lines[y/2],row,width);
			else
			XeeYUVChunkyToPlanar(raw->y_lines[y],raw->cb_lines[y],raw->cr_lines[y],row,width);
		}
	}
	else
	{
		// fix this!
		for(int i=0;i<16;i++)
		{
			unsigned char *row=maindata+cinfo.output_scanline*bprow;
			jpeg_read_scanlines(&cinfo,&row,1);
			if(cinfo.output_scanline>=cinfo.output_height) break;
		}
	}

	[mainimage setCompletedRowCount:cinfo.output_scanline];

	if(cinfo.output_scanline>=cinfo.output_height) return @selector(finishLoading);
	else return @selector(load);
}

-(SEL)finishLoading
{
	if(thumbnail)
	{
		XeeDirectJPEGImage *thumb=[[[XeeDirectJPEGImage alloc] initWithBytes:thumbnail length:thumbnail_length] autorelease];
		if(thumb)
		{
			[thumb setCorrectOrientation:correctorientation];
			[self addSubImage:thumb];

			thumbnail_pixelsize=imax([thumb width],[thumb height]);
		}
	}

	success=YES;
	return NULL;
}



-(int)losslessFlags
{
	if(currindex!=0) return 0;

	int flags=XeeCanLosslesslySaveFlag;

	int rounded_width=(width/mcu_width)*mcu_width;
	int rounded_height=(height/mcu_height)*mcu_height;

	XeeTransformation orient=[mainimage orientation];
	NSRect crop=[mainimage rawCroppingRect];
	NSRect transcrop=XeeTransformRect(orient,rounded_width,rounded_height,crop);

	if(transcrop.origin.x<0)
	{
		if(![self isCropped]) flags|=XeeNeedsTrimmingFlag;
		else flags|=XeeCroppingInexactFlag;
	}

	if(transcrop.origin.y<0)
	{
		if(![self isCropped]) flags|=XeeNeedsTrimmingFlag;
		else flags|=XeeCroppingInexactFlag;
	}

	if(((int)crop.origin.x)%mcu_width) flags|=XeeCroppingInexactFlag;
	if(((int)crop.origin.y)%mcu_height) flags|=XeeCroppingInexactFlag;

	return flags;
}

-(BOOL)losslessSaveTo:(NSString *)destination flags:(int)flags
{
	if(currindex!=0) return NO;

	static JXFORM_CODE jxform_table[9]=
	{
		[XeeUnknownTransformation]=JXFORM_NONE,
		[XeeNoTransformation]=JXFORM_NONE,
		[XeeMirrorHorizontalTransformation]=JXFORM_FLIP_H,
		[XeeRotate180Transformation]=JXFORM_ROT_180,
		[XeeMirrorVerticalTransformation]=JXFORM_FLIP_V,
		[XeeTransposeTransformation]=JXFORM_TRANSPOSE,
		[XeeRotateCWTransformation]=JXFORM_ROT_90,
		[XeeTransverseTransformation]=JXFORM_TRANSVERSE,
		[XeeRotateCCWTransformation]=JXFORM_ROT_270,
	};

	XeeTransformation orient=[mainimage orientation];

	jpeg_transform_info transformoption={0};
	transformoption.transform=jxform_table[orient];
	transformoption.trim=flags&XeeTrimFlag?TRUE:FALSE;
	transformoption.force_grayscale=FALSE;

	if([self isCropped])
	{
		int rounded_width=(width/mcu_width)*mcu_width;
		int rounded_height=(height/mcu_height)*mcu_height;
		NSRect crop=[mainimage rawCroppingRect];
		NSRect transcrop=XeeTransformRect(orient,rounded_width,rounded_height,crop);

		if(transcrop.origin.x<0)
		{
			transcrop.size.width+=transcrop.origin.x;
			transcrop.origin.x=0;
		}

		if(transcrop.origin.y<0)
		{
			transcrop.size.height+=transcrop.origin.y;
			transcrop.origin.y=0;
		}

		transformoption.crop=TRUE;
		transformoption.crop_xoffset=transcrop.origin.x;
		transformoption.crop_yoffset=transcrop.origin.y;
		transformoption.crop_width=transcrop.size.width;
		transformoption.crop_height=transcrop.size.height;
		transformoption.crop_xoffset_set=
		transformoption.crop_yoffset_set=
		transformoption.crop_width_set=
		transformoption.crop_height_set=JCROP_POS;
	}
	else transformoption.crop=FALSE;

	struct jpeg_decompress_struct srcinfo;
	struct jpeg_compress_struct dstinfo;
	struct jpeg_error_mgr jsrcerr,jdsterr;
	srcinfo.err=XeeJPEGErrorHandler(&jsrcerr);
	dstinfo.err=XeeJPEGErrorHandler(&jdsterr);
	jpeg_create_decompress(&srcinfo);
	jpeg_create_compress(&dstinfo);

	FILE *fh=NULL;
	BOOL res=NO;

	@try
	{
		srcinfo.mem->max_memory_to_use = dstinfo.mem->max_memory_to_use;

		fh=fopen([filename fileSystemRepresentation],"rb");
		if(!fh) [NSException raise:@"XeeJPEGTransformException" format:@"Couldn't read from file"];

		jpeg_stdio_src(&srcinfo,fh);
		jpeg_save_markers(&srcinfo,JPEG_COM,0xFFFF);
		for(int i=0;i<16;i++) jpeg_save_markers(&srcinfo,JPEG_APP0+i,0xFFFF);

		jpeg_read_header(&srcinfo,TRUE);

		jtransform_request_workspace(&srcinfo,&transformoption);

		jvirt_barray_ptr *src_coef_arrays=jpeg_read_coefficients(&srcinfo);

		jpeg_copy_critical_parameters(&srcinfo,&dstinfo);

		jvirt_barray_ptr *dst_coef_arrays=jtransform_adjust_parameters(&srcinfo,&dstinfo,
		src_coef_arrays,&transformoption);

		fclose(fh);
		fh=fopen([destination fileSystemRepresentation],"wb");
		if(!fh) [NSException raise:@"XeeJPEGTransformException" format:@"Couldn't write to file"];

		jpeg_stdio_dest(&dstinfo,fh);
		jpeg_write_coefficients(&dstinfo,dst_coef_arrays);

		jpeg_saved_marker_ptr marker;
		for(marker=srcinfo.marker_list;marker;marker=marker->next)
		{
			if(dstinfo.write_JFIF_header&&marker->marker==JPEG_APP0&&marker->data_length>=5&&
			GETJOCTET(marker->data[0])=='J'&&GETJOCTET(marker->data[1])=='F'&&
			GETJOCTET(marker->data[2])=='I'&&GETJOCTET(marker->data[3])=='F'&&
			GETJOCTET(marker->data[4])==0) continue; // reject duplicate JFIF

			if(dstinfo.write_Adobe_marker&&marker->marker==JPEG_APP0+14&&marker->data_length>=5&&
			GETJOCTET(marker->data[0])=='A'&&GETJOCTET(marker->data[1])=='d'&&
			GETJOCTET(marker->data[2])=='o'&&GETJOCTET(marker->data[3])=='b'&&
			GETJOCTET(marker->data[4])=='e') continue; // reject duplicate Adobe

			if(marker->marker==JPEG_APP0+1&&marker->data_length>=6&&
			GETJOCTET(marker->data[0])=='E'&&GETJOCTET(marker->data[1])=='x'&&
			GETJOCTET(marker->data[2])=='i'&&GETJOCTET(marker->data[3])=='f'&&
			GETJOCTET(marker->data[4])==0&&GETJOCTET(marker->data[5])==0) // Exif marker, needs adjustment
			{
				XeeEXIFReader *exif=[[XeeEXIFReader alloc] initWithBuffer:marker->data length:marker->data_length mutable:YES];
				if(exif)
				{
					[exif setShort:1 forTag:EXIFOrientationTag set:EXIFStandardTagSet];

					if(XeeTransformationIsFlipped(orientation))
					{
						EXIFRational x_res=[exif rationalForTag:EXIF_T_XRES set:EXIFStandardTagSet];
						EXIFRational y_res=[exif rationalForTag:EXIF_T_XRES set:EXIFStandardTagSet];
						[exif setRational:y_res forTag:EXIF_T_XRES set:EXIFStandardTagSet];
						[exif setRational:x_res forTag:EXIF_T_YRES set:EXIFStandardTagSet];

						EXIFRational x_fpres=[exif rationalForTag:EXIF_T_FPXRES set:EXIFStandardTagSet];
						EXIFRational y_fpres=[exif rationalForTag:EXIF_T_FPYRES set:EXIFStandardTagSet];
						[exif setRational:y_fpres forTag:EXIF_T_FPXRES set:EXIFStandardTagSet];
						[exif setRational:x_fpres forTag:EXIF_T_FPYRES set:EXIFStandardTagSet];
					}

					int thumb_start=[exif integerForTag:EXIFJPEGInterchangeFormatTag set:EXIFStandardTagSet];
					int thumb_length=[exif integerForTag:EXIFJPEGInterchangeFormatLengthTag set:EXIFStandardTagSet];

					if(thumb_start&&thumb_length)
					{
						// Make a new thumbnail and write a whole new marker
						int maxsize=0xffff-6-thumb_start;
						NSData *newthumb=[self makeJPEGThumbnailWithMaxSize:maxsize];
						if(newthumb)
						{
							const uint8 *newthumb_data=[newthumb bytes];
							int newthumb_length=[newthumb length];

							[exif setLong:newthumb_length forTag:EXIFJPEGInterchangeFormatLengthTag set:EXIFStandardTagSet];

							jpeg_write_m_header(&dstinfo,JPEG_APP0+1,6+thumb_start+newthumb_length);

							for(int i=0;i<thumb_start+6;i++)
							jpeg_write_m_byte(&dstinfo,marker->data[i]);

							for(int i=0;i<newthumb_length;i++)
							jpeg_write_m_byte(&dstinfo,newthumb_data[i]);

							[exif release];
							continue;
						}
						[exif release];
					}
				}
			}

			jpeg_write_marker(&dstinfo,marker->marker,marker->data,marker->data_length);
		}

		jtransform_execute_transformation(&srcinfo,&dstinfo,src_coef_arrays,&transformoption);

		jpeg_finish_compress(&dstinfo);
		jpeg_finish_decompress(&srcinfo);

		res=YES;
	}
	@catch(id e)
	{
		NSLog(@"JPEG transformation exception: %@",e);
	}
	@finally
	{
		jpeg_destroy_compress(&dstinfo);
		jpeg_destroy_decompress(&srcinfo);
		if(fh) fclose(fh);
	}

//  exit(jsrcerr.num_warnings + jdsterr.num_warnings ?EXIT_WARNING:EXIT_SUCCESS);

	return res;
}

-(CGImageRef)makeRGBThumbnail:(NSData **)dataptr
{
	int currwidth=[mainimage width],currheight=[mainimage height];
	int thumbwidth,thumbheight;
	if(currwidth>currheight)
	{
		thumbwidth=thumbnail_pixelsize;
		thumbheight=(thumbnail_pixelsize*currheight+currwidth/2)/currwidth;
	}
	else
	{
		thumbwidth=(thumbnail_pixelsize*currwidth+currheight/2)/currheight;
		thumbheight=thumbnail_pixelsize;
	}

	CGImageRef thumbimage=NULL;
	if(dataptr) *dataptr=NULL;

	CGImageRef cgimage=[mainimage makeCGImage];
	if(cgimage)
	{
		int bytesperpixel,alpha;
		switch(CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(cgimage)))
		{
			case 1: bytesperpixel=1; alpha=kCGImageAlphaNone; break;
			default: bytesperpixel=4; alpha=kCGImageAlphaNoneSkipLast; break;
		}

		NSMutableData *thumbdata=[NSMutableData dataWithLength:thumbwidth*thumbheight*bytesperpixel];
		if(thumbdata)
		{
			CGContextRef context=CGBitmapContextCreate([thumbdata mutableBytes],thumbwidth,thumbheight,8,
			thumbwidth*bytesperpixel,CGImageGetColorSpace(cgimage),alpha);
			if(context)
			{
				CGContextSetInterpolationQuality(context,kCGInterpolationHigh);
				CGContextDrawImage(context,CGRectMake(0,0,thumbwidth,thumbheight),cgimage);
				CGContextRelease(context);

				if(dataptr) *dataptr=thumbdata;

				CGDataProviderRef provider=CGDataProviderCreateWithCFData((CFDataRef)thumbdata);
				if(provider)
				{
					thumbimage=CGImageCreate(thumbwidth,thumbheight,8,8*bytesperpixel,thumbwidth*bytesperpixel,
					CGImageGetColorSpace(cgimage),alpha,provider,NULL,NO,kCGRenderingIntentDefault);

					CFRelease(provider);
				}
			}
		}
		CGImageRelease(cgimage);
	}

	return thumbimage;
}

-(NSData *)makeJPEGThumbnailWithMaxSize:(int)maxsize
{
	CGImageRef thumbimage=[self makeRGBThumbnail:NULL];
	if(thumbimage)
	{
		NSMutableData *jpegdata=nil;
		int quality=50;

		do
		{
			[jpegdata release];
			jpegdata=[[NSMutableData alloc] init];
			if(jpegdata)
			{
				BOOL res=NO;

				CGImageDestinationRef dest=CGImageDestinationCreateWithData(
				(CFMutableDataRef)jpegdata,kUTTypeJPEG,1,NULL);
				if(dest)
				{
					CGImageDestinationAddImage(dest,thumbimage,(CFDictionaryRef)[NSDictionary dictionaryWithObjectsAndKeys:
						[NSNumber numberWithFloat:(float)quality/100.0],(NSString *)kCGImageDestinationLossyCompressionQuality,
					nil]);
					if(CGImageDestinationFinalize(dest)) res=YES;

					CFRelease(dest);

				}

				if(!res)
				{
					[jpegdata release];
					jpegdata=nil;
					break;
				}
			}
			else break;

			quality-=10;
		} while(quality>=0&&[jpegdata length]>maxsize);

		CGImageRelease(thumbimage);

		if(!jpegdata||quality<0) return nil;

		return [jpegdata autorelease];
	}

	return nil;
}

+(NSArray *)fileTypes
{
	return [NSArray arrayWithObjects:@"jpg",@"jpeg",@"jpe",@"'JPEG'",nil];
}

@end




void XeeJPEGMemoryInitSource(struct jpeg_decompress_struct *cinfo) {}
boolean XeeJPEGMemoryFillInputBuffer(struct jpeg_decompress_struct *cinfo) { return 1; }
void XeeJPEGMemorySkipInputData(struct jpeg_decompress_struct *cinfo,long num_bytes)
{ cinfo->src->next_input_byte+=num_bytes; cinfo->src->bytes_in_buffer-=num_bytes; }
boolean XeeJPEGMemoryResyncToRestart(struct jpeg_decompress_struct *cinfo,int desired) { return 1; }
void XeeJPEGMemoryTermSource(struct jpeg_decompress_struct *cinfo) {}

@implementation XeeDirectJPEGImage

-(id)initWithBytes:(void *)buffer length:(int)length
{
	if(self=[super init])
	{
		struct jpeg_decompress_struct cinfo;

		struct jpeg_error_mgr jerr;
		cinfo.err=XeeJPEGErrorHandler(&jerr);

		@try
		{
			jpeg_create_decompress(&cinfo);

			struct jpeg_source_mgr jsrc;
			jsrc.next_input_byte=buffer;
			jsrc.bytes_in_buffer=length;
			jsrc.init_source=XeeJPEGMemoryInitSource;
			jsrc.fill_input_buffer=XeeJPEGMemoryFillInputBuffer;
			jsrc.skip_input_data=XeeJPEGMemorySkipInputData;
			jsrc.resync_to_restart=XeeJPEGMemoryResyncToRestart;
			jsrc.term_source=XeeJPEGMemoryTermSource;
			cinfo.src=&jsrc;

			jpeg_read_header(&cinfo,TRUE);

			width=cinfo.image_width;
			height=cinfo.image_height;

			switch(cinfo.jpeg_color_space)
			{
				case JCS_GRAYSCALE: [self setDepthGrey:8]; break;
				case JCS_RGB: [self setDepthRGB:8]; break;
				case JCS_YCbCr:
					[self setDepth:[NSString stringWithFormat:@"YCbCr H%dV%d",cinfo.max_h_samp_factor,cinfo.max_v_samp_factor]
					iconName:@"depth_rgb"];
				break;
				case JCS_CMYK: [self setDepthCMYK:8 alpha:NO]; break;
				case JCS_YCCK: [self setDepth:@"YCCK"]; break;
				default: [self setDepth:@"Unknown"]; break;
			}

			int type;
			if(cinfo.jpeg_color_space==JCS_GRAYSCALE) type=XeeBitmapTypeLuma8;
			else type=XeeBitmapTypeRGB8;

			if([self allocWithType:type width:width height:height])
			{
				cinfo.dct_method=JDCT_IFAST;
				jpeg_start_decompress(&cinfo);

				for(int i=0;i<height;i++)
				{
					unsigned char *row=data+cinfo.output_scanline*bytesperrow;
					jpeg_read_scanlines(&cinfo,&row,1);
				}

				jpeg_destroy_decompress(&cinfo);

				success=YES;
				[self setCompleted];
				[self setFormat:@"JPEG"];

				return self;
			}
		}
		@catch(id e) {}

		jpeg_destroy_decompress(&cinfo);
		[self release];
	}

	return nil;
}

@end



static void XeeJPEGErrorExit(j_common_ptr cinfo)
{
	char buffer[JMSG_LENGTH_MAX];
	(*cinfo->err->format_message)(cinfo,buffer);
	[NSException raise:@"XeeLibJPEGException" format:@"libjpeg error: %s",buffer];
}

static void XeeJPEGEmitMessage(j_common_ptr cinfo,int msg_level) { } // Ignore warnings for now

static void XeeJPEGResetErrorMgr(j_common_ptr cinfo) {}

static struct jpeg_error_mgr *XeeJPEGErrorHandler(struct jpeg_error_mgr *jerr)
{
	jpeg_std_error(jerr);
	jerr->error_exit=XeeJPEGErrorExit;
	jerr->emit_message=XeeJPEGEmitMessage;
	jerr->reset_error_mgr=XeeJPEGResetErrorMgr;
	return jerr;
}



static void XeeYUVChunkyToPlanar(uint8 *y_row,uint8 *cb_row,uint8 *cr_row,uint8 *dest_row,int width)
{
	int count=width/8;

	uint32 *y_longrow=(uint32 *)y_row;
	uint32 *cb_longrow=(uint32 *)cb_row;
	uint32 *cr_longrow=(uint32 *)cr_row;
	uint32 *dest_longrow=(uint32 *)dest_row;

	for(int i=0;i<count;i++)
	{
		uint32 y1=*y_longrow++;
		uint32 y2=*y_longrow++;
		uint32 cb=*cb_longrow++;
		uint32 cr=*cr_longrow++;

		#ifdef BIG_ENDIAN
		*dest_longrow++=(cb&0xff000000)|((y1>>8)&0x00ff0000)|((cr>>16)&0x0000ff00)|((y1>>16)&0x000000ff);
		*dest_longrow++=((cb<<8)&0xff000000)|((y1<<8)&0x00ff0000)|((cr>>8)&0x0000ff00)|(y1&0x000000ff);
		*dest_longrow++=((cb<<16)&0xff000000)|((y2>>8)&0x00ff0000)|(cr&0x0000ff00)|((y2>>16)&0x000000ff);
		*dest_longrow++=((cb<<24)&0xff000000)|((y2<<8)&0x00ff0000)|((cr<<8)&0x0000ff00)|(y2&0x000000ff);
		#else
		*dest_longrow++=(cb&0x000000ff)|((y1<<8)&0x0000ff00)|((cr<<16)&0x00ff0000)|((y1<<16)&0xff000000);
		*dest_longrow++=((cb>>8)&0x000000ff)|((y1>>8)&0x0000ff00)|((cr<<8)&0x00ff0000)|(y1&0xff000000);
		*dest_longrow++=((cb>>16)&0x000000ff)|((y2<<8)&0x0000ff00)|(cr&0x00ff0000)|((y2<<16)&0xff000000);
		*dest_longrow++=((cb>>24)&0x000000ff)|((y2>>8)&0x0000ff00)|((cr>>8)&0x00ff0000)|(y2&0xff000000);
		#endif
	}

	count=((width&7)+1)/2;
	y_row=(uint8 *)y_longrow;
	cb_row=(uint8 *)cb_longrow;
	cr_row=(uint8 *)cr_longrow;
	dest_row=(uint8 *)dest_longrow;

	for(int i=0;i<count;i++)
	{
		*dest_row++=*cb_row++;
//		*dest_row++=gammatable[*y_row++];
		*dest_row++=*y_row++;
		*dest_row++=*cr_row++;
//		*dest_row++=gammatable[*y_row++];
		*dest_row++=*y_row++;
	}
}

