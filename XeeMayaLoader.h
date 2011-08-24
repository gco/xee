#import "XeeMultiImage.h"
#import "XeeBitmapImage.h"

@class XeeIFFHandle;

@interface XeeMayaImage:XeeMultiImage
{
	XeeIFFHandle *iff,*subiff;
	XeeBitmapImage *mainimage,*zbufimage;

	int flags,tiles,compression;
	int pixelsize;
	int rgbatiles,zbuftiles;
}

-(SEL)identifyFile;
-(void)deallocLoader;
-(SEL)load;

-(void)readUncompressedAtX:(int)x y:(int)y width:(int)w height:(int)h;
-(void)readRLECompressedAtX:(int)x y:(int)y width:(int)w height:(int)h;
-(void)readRLECompressedTo:(uint8 *)dest num:(int)num stride:(int)stride width:(int)w bytesPerRow:(int)bpr;

+(NSArray *)fileTypes;

@end
