#import "XeeMultiImage.h"
#import "XeeBitmapImage.h"

#include "libjpeg/jpeglib.h"

@class XeeTileImage;

@interface XeeJPEGImage:XeeMultiImage
{
	BOOL jpeg_created;
	struct jpeg_decompress_struct cinfo;
	struct jpeg_error_mgr jerr;

	struct raw_data
	{
		JSAMPROW y_lines[16],cb_lines[16],cr_lines[16];
		JSAMPARRAY image[3];
		JSAMPLE data[0];
	} *raw;

	XeeTileImage *mainimage;
	void *thumbnail;
	int thumbnail_length,thumbnail_pixelsize;

	int mcu_width,mcu_height;
}

-(SEL)identifyFile;
-(void)deallocLoader;
-(SEL)startLoading;
-(SEL)load;
-(SEL)finishLoading;

-(int)losslessFlags;
-(BOOL)losslessSaveTo:(NSString *)destination flags:(int)flags;

-(CGImageRef)makeRGBThumbnail:(NSData **)dataptr;
-(NSData *)makeJPEGThumbnailWithMaxSize:(int)maxsize;

+(NSArray *)fileTypes;

@end


@interface XeeDirectJPEGImage:XeeBitmapImage
{
}

-(id)initWithBytes:(void *)buffer length:(int)length;

@end
