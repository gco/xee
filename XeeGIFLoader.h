#import "XeeBitmapImage.h"

#import "libungif/gif_lib.h"

@class XeeGIFFrame,XeeGIFPalette;

@interface XeeGIFImage:XeeBitmapImage
{
	GifFileType *gif;

	NSMutableArray *frames;
	NSMutableArray *comments;

	int background,currframe;
	int frametime,transindex,disposal;
	BOOL backupneeded;
	uint32_t *backup;
	XeeGIFPalette *globalpal;

	int animticks;
	NSTimer *animationtimer;
}

+(NSArray *)fileTypes;
+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;

-(id)init;
-(void)dealloc;

-(SEL)initLoader;
-(void)deallocLoader;
-(SEL)startLoading;
-(SEL)loadRecord;
-(SEL)failLoading;
-(SEL)finishLoading;

-(int)frames;
-(void)setFrame:(int)frame;
-(int)frame;
-(void)animate:(NSTimer *)timer;

-(BOOL)animated;
-(void)setAnimating:(BOOL)animating;
-(void)setAnimatingDefault;
-(BOOL)animating;

-(void)clearImage;
-(int)background;
-(uint32_t *)backup;

@end



@interface XeeGIFFrame:NSObject
{
	int left,top,width,height;
	int time,transparent,disposal;
	XeeGIFPalette *palette;

	unsigned char *data;
}

-(id)initWithWidth:(int)framewidth height:(int)frameheight left:(int)frameleft top:(int)frametop time:(int)frametime transparent:(int)trans disposal:(int)disp palette:(XeeGIFPalette *)pal;
-(void)dealloc;

-(void)draw:(XeeGIFImage *)image;
-(void)dispose:(XeeGIFImage *)image;
-(void)drawAndDispose:(XeeGIFImage *)image;

-(unsigned char *)data;
-(int)time;

@end


@interface XeeGIFPalette:NSObject
{
	uint32_t table[256];
}

-(id)initWithColorMap:(ColorMapObject *)cmap;
-(uint32_t *)table;

@end
