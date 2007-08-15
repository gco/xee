#import "XeeMultiImage.h"
#import "XeeBitmapImage.h"

@interface XeePhotoshopImage:XeeMultiImage
{
}

-(id)initWithFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;
-(void)dealloc;

-(void)load;

+(NSArray *)fileTypes;

@end

@interface XeePhotoshopSubImage:XeeBitmapImage
{
}

//-(id)initWithFilehandle:(FILE *)fh offset:(size_t)offset ...
-(void)dealloc;

-(void)load;

@end


/*
@interface XeePhotoshopChannel : NSObject
{
    XeeFileHandle *fh;
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