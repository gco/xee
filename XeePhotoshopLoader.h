#import "XeeMultiImage.h"
#import "XeeBitmapImage.h"

#define XeePhotoshopBitmapMode 0
#define XeePhotoshopGreyscaleMode 1
#define XeePhotoshopIndexedMode 2
#define XeePhotoshopRGBMode 3
#define XeePhotoshopCMYKMode 4
#define XeePhotoshopMultichannelMode 7
#define XeePhotoshopDuotoneMode 8
#define XeePhotoshopLabMode 9



@interface XeePhotoshopImage:XeeMultiImage
{
	int bitdepth,mode,channels;

	SEL loadersel;
	int loaderframe;
}

-(CSHandle *)handleForNumberOfChannels:(int)requiredchannels alpha:(BOOL)alpha;

-(id)init;
-(void)dealloc;
-(SEL)initLoader;

-(int)bitDepth;
-(int)mode;

@end



@interface XeePackbitsHandle:CSHandle
{
	CSHandle *parent;
	int (*readatmost_ptr)(id,SEL,int,void *);
	int rows,bytesperrow;
	off_t pos,totalsize,*offsets;

	int spanleft;
	uint8 spanbyte;
	BOOL literal;
}

-(id)initWithHandle:(CSHandle *)handle rows:(int)numrows bytesPerRow:(int)bpr channel:(int)channel of:(int)numchannels previousSize:(off_t)prevsize;
-(void)dealloc;

-(off_t)offsetInFile;
-(int)readAtMost:(int)num toBuffer:(void *)buffer;

-(off_t)totalSize;

@end

@interface XeeDeltaHandle:CSHandle
{
	CSHandle *parent;
	//int (*readatmost_ptr)(id,SEL,int,void *);
	int cols,depth;
	uint16 curr;
}

-(id)initWithHandle:(CSHandle *)handle depth:(int)bitdepth columns:(int)columns;
-(void)dealloc;

-(off_t)offsetInFile;
-(int)readAtMost:(int)num toBuffer:(void *)buffer;

@end

/*
@interface XeePhotoshopChannel : NSObject
{
    CSFileHandle *fh;
    int rows;
    int cols;
    int inbufsize;
    int compression;
    int depth;
    long long *rowoffs;
    char *inbuf;
}

- (id)initWithFileHandle:(id)fp8 startOffset:(long long)fp12 previousDataSize:(long long)fp20 channel:(int)fp28 of:(int)fp32 rows:(int)fp36 columns:(int)fp40 depth:(int)fp44;
- (void)dealloc;
- (long long)dataSize;
- (int)requiredBufferSize;
- (void)setBuffer:(char *)fp8;
- (void)loadRow:(int)fp8 toBuffer:(char *)fp12 stride:(int)fp16;

@end

@interface XeePhotoshopSubImage : XeeBitmapImage
{
    XeePhotoshopImage *parent;
    NSArray *channelarray;
    int numchannels;
    int bits;
    int mode;
    int compression;
    XeePhotoshopChannel *channels[5];
    int current_line;
    long long *rowoffs;
    char *inbuf;
    char *linebuf;
}

- (id)initWithImage:(id)fp8 width:(int)fp12 height:(int)fp16 depth:(int)fp20 mode:(int)fp24 channels:(id)fp28;
- (void)deallocLoader;
- (SEL)startLoading;
- (SEL)load;
- (void)expandBitmapData:(char *)fp8 toImage:(char *)fp12;
- (void)expandIndexedData:(char *)fp8 toImage:(char *)fp12;
- (void)convertCMYKData:(char *)fp8 toImage:(char *)fp12 stride:(int)fp16;
- (void)convertLabData:(char *)fp8 toImage:(char *)fp12 stride:(int)fp16;
- (void)loadAlphaChannel:(id)fp8 row:(int)fp12 toBuffer:(char *)fp16 alphaIndex:(int)fp20 colorChannels:(int)fp24 stride:(int)fp28;
- (void)setIsPreComposited:(BOOL)fp8;

@end

@interface XeePhotoshopImage : XeeMultiImage
{
    XeePhotoshopSubImage *mainimage;
    char *palette;
    int palsize;
    int actualcolours;
    int transparentindex;
}

+ (id)fileTypes;
- (SEL)identifyFile;
- (void)deallocLoader;
- (SEL)startLoading;
- (SEL)loadMain;
- (void)setFrame:(int)fp8;
- (char *)palette;
- (int)paletteSize;
- (int)actualColours;
- (int)transparentIndex;

@end
*/