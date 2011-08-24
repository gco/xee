#import "XeeMultiImage.h"
#import "XeeBitmapImage.h"
#import "XeeFileHandle.h"

@class XeePhotoshopSubImage,XeePhotoshopChannel;

@interface XeePhotoshopImage:XeeMultiImage
{
	XeePhotoshopSubImage *mainimage;

	uint8 *palette;
	int palsize;
	int actualcolours;
	int transparentindex;
}

-(SEL)identifyFile;
-(void)deallocLoader;

-(SEL)startLoading;
-(SEL)loadMain;

-(uint8 *)palette;
-(int)paletteSize;
-(int)actualColours;
-(int)transparentIndex;

+(NSArray *)fileTypes;

@end

@interface XeePhotoshopSubImage:XeeBitmapImage
{
	XeePhotoshopImage *parent;
	NSArray *channelarray;

	int numchannels,bits,mode,compression;
	XeePhotoshopChannel *channels[5];

	int current_line;
	off_t *rowoffs;
	uint8 *inbuf,*linebuf;
}

-(id)initWithImage:(XeePhotoshopImage *)parentimage width:(int)imgwidth height:(int)imgheight
depth:(int)bitdepth mode:(int)imgmode channels:(NSArray *)imgchannels;
-(void)deallocLoader;

-(SEL)startLoading;
-(SEL)load;

-(void)expandBitmapData:(uint8 *)bitmap toImage:(uint8 *)dest;
-(void)expandIndexedData:(uint8 *)indexed toImage:(uint8 *)dest;
-(void)convertCMYKData:(uint8 *)cmyk toImage:(uint8 *)dest stride:(int)stride;
-(void)convertLabData:(uint8 *)lab toImage:(uint8 *)dest stride:(int)stride;

-(void)loadAlphaChannel:(XeePhotoshopChannel *)channel row:(int)row toBuffer:(uint8 *)buf alphaIndex:(int)alphaindex colorChannels:(int)colorchannels stride:(int)stride;
-(void)setIsPreComposited:(BOOL)precomp;

@end


@interface XeePhotoshopChannel:NSObject
{
	XeeFileHandle *fh;
	int rows,cols,inbufsize,compression,depth;
	off_t *rowoffs;
	uint8 *inbuf;
}

-(id)initWithFileHandle:(XeeFileHandle *)file startOffset:(off_t)startoffs previousDataSize:(off_t)prevsize channel:(int)channel of:(int)channels rows:(int)imgrows columns:(int)imgcols depth:(int)depth;
-(void)dealloc;

-(off_t)dataSize;
-(int)requiredBufferSize;
-(void)setBuffer:(uint8 *)newbuf;

-(void)loadRow:(int)row toBuffer:(uint8 *)dest stride:(int)stride;

@end
