#import "XeeMultiImage.h"
#import "XeeJPEGUtilities.h"

#include "libjpeg/jpeglib.h"



@class XeeTileImage;

@interface XeeJPEGImage:XeeMultiImage
{
	BOOL jpeg_created;
	struct jpeg_decompress_struct cinfo;
	struct jpeg_error_mgr jerr;
	struct XeeJPEGSource jsrc;

	int mcu_width,mcu_height;

	uint8 *ycbcr_buffers;
	JSAMPLE *y_buf,*cb_buf,*cr_buf;
	JSAMPROW y_lines[16],cb_lines[16],cr_lines[16];
	JSAMPARRAY image[3];

	uint8 *cmyk_buffer;

	uint8 *thumb_ptr;
	int thumb_len;
	CSHandle *thumbhandle;

	XeeTileImage *mainimage;

	BOOL overwriting;
}

+(NSArray *)fileTypes;
+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;

-(SEL)initLoader;
-(void)deallocLoader;
-(SEL)startLoading;
-(SEL)loadRGBOrGrey;
-(SEL)loadCMYK;
-(SEL)loadYUV;
-(SEL)loadThumbnail;

@end
