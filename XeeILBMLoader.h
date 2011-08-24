#import "XeeBitmapImage.h"

@class XeeIFFHandle;

@interface XeeILBMImage:XeeBitmapImage
{
	XeeIFFHandle *iff;

	int realwidth,realheight;
	int planes,masking,compression,trans;
	int xasp,yasp,xscale,yscale;
	int rowbytes;

	BOOL ham,ham8,ehb,ocscol,transparency;

	byte *image;
	byte *mask;

	unsigned long palette[256];

	NSMutableArray *ranges;

	int current_line;

	int clock;
	NSTimer *animationtimer;
}

-(SEL)identifyFile;
-(void)deallocLoader;
-(void)dealloc;

-(SEL)startLoading;
-(SEL)load;

-(void)readRow:(byte *)row;
-(void)renderImage;

-(unsigned long *)palette;

-(BOOL)animated;
-(void)setAnimating:(BOOL)animating;
-(BOOL)animating;

+(NSArray *)fileTypes;

@end



@interface XeeILBMRange:NSObject
{
	int num;
	unsigned long *colours;
	int *indexes;

	float interval;
	float next;

	XeeILBMImage *image;
}

-(id)initWithIFF:(XeeIFFHandle *)iff image:(XeeILBMImage *)image;
-(void)dealloc;
-(BOOL)allocBuffers:(int)length;
-(void)setIndexesFrom:(int)start to:(int)end reverse:(BOOL)reverse;
-(void)setup;
-(BOOL)triggerCheck:(float)time;
-(void)cycle;

@end
