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

	uint8 *image;
	uint8 *mask;

	unsigned long palette[256];

	NSMutableArray *ranges;
	NSMutableArray *comments;

	int current_line;

	int clock;
	NSTimer *animationtimer;
}

+(NSArray *)fileTypes;
+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;

-(id)init;
-(void)dealloc;

-(SEL)initLoader;
-(void)deallocLoader;
-(SEL)loadChunk;
-(SEL)startLoadingImage;
-(SEL)loadPaletteImage;
-(SEL)loadRGBImage;

-(void)readRow:(uint8 *)row;
-(void)renderImage;
-(void)addCommentWithLabel:(NSString *)label data:(NSData *)commentdata;

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
