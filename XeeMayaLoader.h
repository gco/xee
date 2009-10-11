#import "XeeMultiImage.h"

@class XeeIFFHandle,XeeBitmapImage;

@interface XeeMayaImage:XeeMultiImage
{
	XeeIFFHandle *iff,*subiff;
	XeeBitmapImage *mainimage,*zbufimage;
	int flags,bytedepth,tiles,compression;
	int numchannels;
	int rgbatiles,zbuftiles;
}

+(id)fileTypes;
+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;

-(SEL)initLoader;
-(void)deallocLoader;
-(SEL)loadChunk;
-(SEL)startLoadingData;
-(SEL)loadDataChunk;

-(void)readUncompressedAtX:(int)x y:(int)y width:(int)w height:(int)h;
-(void)readRLECompressedAtX:(int)x y:(int)y width:(int)w height:(int)h;
-(void)readRLECompressedTo:(uint8_t *)buf num:(int)num stride:(int)stride width:(int)w bytesPerRow:(int)bprow;

@end
