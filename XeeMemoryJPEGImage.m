#import "XeeMemoryJPEGImage.h"
#import "XeeJPEGUtilities.h"



@implementation XeeMemoryJPEGImage

-(id)initWithBytes:(const void *)bytes length:(int)len
{
	if(self=[super init])
	{
		struct jpeg_decompress_struct cinfo; 
		struct jpeg_error_mgr jerr; 
		struct jpeg_source_mgr src;

		cinfo.err=XeeJPEGErrorManager(&jerr);

		@try
		{
			jpeg_create_decompress(&cinfo);

			cinfo.src=XeeMemoryJPEGSourceManager(&src,bytes,len);

			cinfo.dct_method=JDCT_IFAST;
			jpeg_read_header(&cinfo,TRUE);

			int type;
			if(cinfo.jpeg_color_space==JCS_GRAYSCALE) type=XeeBitmapTypeLuma8;
			else type=XeeBitmapTypeRGB8;

			if(![self allocWithType:type width:cinfo.image_width height:cinfo.image_height])
			@throw @"Out of memory";

			switch(cinfo.jpeg_color_space)
			{
				case JCS_GRAYSCALE: [self setDepthGrey:8]; break;
				case JCS_RGB: [self setDepthRGB:8]; break;
				case JCS_YCbCr:
					[self setDepth:[NSString stringWithFormat:
					@"YCbCr H%dV%d",cinfo.max_h_samp_factor,cinfo.max_v_samp_factor]
					iconName:@"depth_rgb"];
				break;
				case JCS_CMYK: [self setDepthCMYK:8 alpha:NO]; break;
				case JCS_YCCK: [self setDepth:@"YCCK"]; break;
				default: [self setDepth:@"Unknown"]; break;
			}

			[self setFormat:@"JPEG"];

			jpeg_start_decompress(&cinfo);
			for(int i=0;i<height;i++)
			{
				uint8 *row=data+cinfo.output_scanline*bytesperrow;
				jpeg_read_scanlines(&cinfo,&row,1);
			}

			[self setCompleted];

			jpeg_destroy_decompress(&cinfo);
		}
		@catch(id e)
		{
			NSLog(@"XeeDirectJPEGImage creation error: %@",e);
			jpeg_destroy_decompress(&cinfo);
			[self release];
			return nil;
		}
	}
	return self;
}

-(id)initWithData:(NSData *)jpegdata
{
	if(!jpegdata)
	{
		[self release];
		return nil;
	}
	return [self initWithBytes:[jpegdata bytes] length:[jpegdata length]];
}
 
@end
