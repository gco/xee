#import "XeeJPEGLosslessSaving.h"
#import "XeeEXIFParser.h"
#import "XeeJPEGUtilities.h"
#import "XeeImageThumbnailing.h"

#import "libjpeg/transupp.h"



@implementation XeeJPEGImage (LosslessSaving)

-(int)losslessSaveFlags
{
	if(currindex!=0) return [super losslessSaveFlags];

	int flags=XeeCanSaveLosslesslyFlag;

	if(ref&&!overwriting) flags|=XeeCanOverwriteLosslesslyFlag;

	int orient=[mainimage orientation];
	int trimmed_width=width-width%mcu_width;
	int trimmed_height=height-height%mcu_height;
	XeeMatrix m=XeeMatrixForTransformation(orient,trimmed_width,trimmed_height);
	NSRect crop=[mainimage rawCroppingRect];
	NSRect destcrop=XeeTransformRect(m,crop);
	int start_x=XeeTransformationIsFlipped(orient)?crop.origin.y:crop.origin.x;
	int start_y=XeeTransformationIsFlipped(orient)?crop.origin.x:crop.origin.y;
	int trans_mcu_width=XeeTransformationIsFlipped(orient)?mcu_height:mcu_width;
	int trans_mcu_height=XeeTransformationIsFlipped(orient)?mcu_width:mcu_height;

	if(destcrop.origin.x<0||destcrop.origin.y<0)
	{
		flags|=XeeHasUntransformableBlocksFlag;
		if((destcrop.origin.x<0&&start_x!=0)||(destcrop.origin.y<0&&start_y!=0)) flags|=XeeNotActuallyLosslessFlag;
		else flags|=XeeUntransformableBlocksCanBeRetainedFlag;
	}
	else
	{
		if((int)destcrop.origin.x%trans_mcu_width||(int)destcrop.origin.y%trans_mcu_height)
		flags|=XeeCroppingIsInexactFlag;
	}

	if([mainimage isCropped]) flags|=XeeNotActuallyLosslessFlag;

	return flags;
}

-(NSString *)losslessFormat { return @"JPEG"; }

-(NSString *)losslessExtension { return @"jpg"; }

-(BOOL)losslessSaveTo:(NSString *)path flags:(int)flags
{
	if(currindex!=0) return [super losslessSaveTo:path flags:flags];

	overwriting=YES;

	BOOL res=NO;
//	NSString *tmppath=[[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:
//	[NSString stringWithFormat:@".xee__%@.tmp",[path lastPathComponent]]];

	static JXFORM_CODE transform_table[9]=
	{
		[XeeUnknownTransformation]=JXFORM_NONE,
		[XeeNoTransformation]=JXFORM_NONE,
		[XeeRotateCWTransformation]=JXFORM_ROT_90,
		[XeeRotate180Transformation]=JXFORM_ROT_180,
		[XeeRotateCCWTransformation]=JXFORM_ROT_270,
		[XeeMirrorHorizontalTransformation]=JXFORM_FLIP_H,
		[XeeMirrorVerticalTransformation]=JXFORM_FLIP_V,
		[XeeTransposeTransfromation]=JXFORM_TRANSPOSE,
		[XeeTransverseTransformation]=JXFORM_TRANSVERSE,
	};

	int orient=[mainimage orientation];
	int trimmed_width=width-width%mcu_width;
	int trimmed_height=height-height%mcu_height;
	XeeMatrix m=XeeMatrixForTransformation(orient,trimmed_width,trimmed_height);
	NSRect crop=[mainimage rawCroppingRect];
	NSRect destcrop=XeeTransformRect(m,crop);
	int start_x=XeeTransformationIsFlipped(orient)?crop.origin.y:crop.origin.x;
	int start_y=XeeTransformationIsFlipped(orient)?crop.origin.x:crop.origin.y;
	int trans_mcu_width=XeeTransformationIsFlipped(orient)?mcu_height:mcu_width;
	int trans_mcu_height=XeeTransformationIsFlipped(orient)?mcu_width:mcu_height;

	// Handle trimming of untransformable blocks
	if(destcrop.origin.x<0)
	{
		if(!(flags&XeeRetainUntransformableBlocksFlag)||start_x!=0) destcrop.size.width+=destcrop.origin.x;
		destcrop.origin.x=0;
	}
	if(destcrop.origin.y<0)
	{
		if(!(flags&XeeRetainUntransformableBlocksFlag)||start_y!=0) destcrop.size.height+=destcrop.origin.y;
		destcrop.origin.y=0;
	}

	// Trim or expand cropping to MCU boundaries
	int x_offs=(int)destcrop.origin.x%trans_mcu_width;
	int y_offs=(int)destcrop.origin.y%trans_mcu_height;
	if(x_offs)
	{
		if(flags&XeeTrimCroppingFlag)
		{
			destcrop.origin.x+=trans_mcu_width-x_offs;
			destcrop.size.width-=trans_mcu_width-x_offs;
		}
		else
		{
			destcrop.origin.x-=x_offs;
			destcrop.size.width+=x_offs;
		}
	}
	if(y_offs)
	{
		if(flags&XeeTrimCroppingFlag)
		{
			destcrop.origin.y+=trans_mcu_height-y_offs;
			destcrop.size.height-=trans_mcu_height-y_offs;
		}
		else
		{
			destcrop.origin.y-=y_offs;
			destcrop.size.height+=y_offs;
		}
	}

	jpeg_transform_info xform={0};
	xform.crop_xoffset=destcrop.origin.x;
	xform.crop_yoffset=destcrop.origin.y;
	xform.crop_width=destcrop.size.width;
	xform.crop_height=destcrop.size.height;
	xform.crop_xoffset_set=xform.crop_yoffset_set=JCROP_POS;
	xform.crop_width_set=xform.crop_height_set=JCROP_POS;
	xform.transform=transform_table[orient];
	xform.trim=FALSE; // trimming was handled earlier
	xform.crop=TRUE;

	struct jpeg_decompress_struct src={0};
	struct jpeg_compress_struct dest={0};
	struct jpeg_error_mgr srcerr,desterr;
	struct XeeJPEGSource srcsrc;
	jvirt_barray_ptr *src_coef_arrays;
	jvirt_barray_ptr *dest_coef_arrays;
	FILE *fh=NULL;

	src.err=XeeJPEGErrorManager(&srcerr);
	dest.err=XeeJPEGErrorManager(&desterr);

	@try
	{
		jpeg_create_decompress(&src);
		jpeg_create_compress(&dest);

		[[self handle] seekToFileOffset:0];
		src.src=XeeJPEGSourceManager(&srcsrc,[self handle]);

		jpeg_save_markers(&src,JPEG_COM,0xffff);
		for(int i=0;i<16;i++) jpeg_save_markers(&src,JPEG_APP0+i,0xffff);

		jpeg_read_header(&src,TRUE);

		// Any space needed by a transform option must be requested before
		// jpeg_read_coefficients so that memory allocation will be done right.
		jtransform_request_workspace(&src,&xform);

		// Read source file as DCT coefficients
		src_coef_arrays=jpeg_read_coefficients(&src);

		// Initialize destination compression parameters from source values
		jpeg_copy_critical_parameters(&src,&dest);

		// Adjust destination parameters if required by transform options;
		// also find out which set of coefficient arrays will hold the output.
		dest_coef_arrays=jtransform_adjust_parameters(&src,&dest,src_coef_arrays,&xform);

		// /*Close input file and*/ open output file.
//		fh=fopen([tmppath fileSystemRepresentation],"wb");
		fh=fopen([path fileSystemRepresentation],"wb");
		if(!fh) @throw @"Couldn't open destination file";
		jpeg_stdio_dest(&dest,fh);

		// Start compressor (note no image data is actually written here)
		jpeg_write_coefficients(&dest,dest_coef_arrays);

		// Handle APP and COM markers
		for(jpeg_saved_marker_ptr marker=src.marker_list;marker;marker=marker->next)
		{
			// Reject duplicate JFIF
			if(dest.write_JFIF_header&&marker->marker==JPEG_APP0&&
			marker->data_length>=5&&GETJOCTET(marker->data[0])=='J'&&
			GETJOCTET(marker->data[1])=='F'&&GETJOCTET(marker->data[2])=='I'&&
			GETJOCTET(marker->data[3])=='F'&&GETJOCTET(marker->data[4])==0)
			continue;

			// Reject duplicate Adobe
			if(dest.write_Adobe_marker&&marker->marker==JPEG_APP0+14&&
			marker->data_length>=5&&GETJOCTET(marker->data[0])=='A'&&
			GETJOCTET(marker->data[1])=='d'&&GETJOCTET(marker->data[2])=='o'&&
			GETJOCTET(marker->data[3])=='b'&&GETJOCTET(marker->data[4])=='e')
			continue;

			// Modify EXIF
			if(XeeTestJPEGMarker(marker,1,6,"Exif\000"))
			{
				XeeEXIFParser *exif=[[[XeeEXIFParser alloc] initWithBuffer:marker->data+6 length:marker->data_length-6 mutable:YES] autorelease];

				[exif setLong:1 forTag:XeeOrientationTag set:XeeStandardTagSet];

				// Flip axis-dependent values if needed
				if(XeeTransformationIsFlipped(orient))
				{
					XeeRational fpxres=[exif rationalForTag:XeeFocalPlaneXResolution set:XeeStandardTagSet];
					XeeRational fpyres=[exif rationalForTag:XeeFocalPlaneYResolution set:XeeStandardTagSet];
					[exif setRational:fpyres forTag:XeeFocalPlaneXResolution set:XeeStandardTagSet];
					[exif setRational:fpxres forTag:XeeFocalPlaneYResolution set:XeeStandardTagSet];
				}

				int offs=[exif integerForTag:XeeThumbnailOffsetTag set:XeeStandardTagSet];
				if(offs)
				{
					int size=160;
					if([subimages count]>1)
					{
						XeeImage *thumbimage=[subimages objectAtIndex:1];
						size=imax([thumbimage width],[thumbimage height]);
					}

					NSData *thumbdata=[self makeJPEGThumbnailOfSize:size maxBytes:0xffff-6-offs];

					if(thumbdata)
					{
						int newlen=[thumbdata length];
						const uint8_t *newdata=[thumbdata bytes];

						[exif setLong:newlen forTag:XeeThumbnailLengthTag set:XeeStandardTagSet];

						jpeg_write_m_header(&dest,marker->marker,6+offs+newlen);
						for(int i=0;i<offs+6;i++) jpeg_write_m_byte(&dest,marker->data[i]);
						for(int i=0;i<newlen;i++) jpeg_write_m_byte(&dest,newdata[i]);

						continue;
					}
				}
			}

			jpeg_write_marker(&dest,marker->marker,marker->data,marker->data_length);
		}

		// Execute image transformation, if any
		jtransform_execute_transformation(&src,&dest,src_coef_arrays,&xform);

		jpeg_finish_compress(&dest);
		jpeg_finish_decompress(&src);

		res=YES;
	}
	@catch(id e)
	{
		NSLog(@"JPEG lossless saver error: %@",e);
	}

	jpeg_destroy_compress(&dest);
	jpeg_destroy_decompress(&src);
	if(fh) fclose(fh);

/*	if(res)
	{
		[[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
		[[NSFileManager defaultManager] movePath:tmppath toPath:path handler:nil];
	}
	else
	{
		[[NSFileManager defaultManager] removeFileAtPath:tmppath handler:nil];
	}*/

	overwriting=NO;

	return res;
}

@end
