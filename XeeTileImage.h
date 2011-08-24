#import "XeeImage.h"
#import "XeeTypes.h"
#import "XeeSampleSet.h"

#import <OpenGL/GL.h>
#import <OpenGL/GLu.h>



typedef void (*XeePixelAccessFunc)(void *datarow,int x,uint8 *pixel,void *context);



@class XeeBitmapTile;

@interface XeeTileImage:XeeImage
{
	byte *data;
	int bytesperrow,pixelsize;
	BOOL premultiplied;

	GLuint textarget,texintformat,texformat,textype;

	XeeSpan completed,uploaded,drawn;

	NSMutableArray *tiles;
	BOOL needsupdate;
	NSOpenGLContext *context;
}

-(id)init;
-(id)initWithFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;
-(void)_initTileImage;
-(void)dealloc;

-(void)setCompleted;
-(void)setCompletedRowCount:(int)count;
-(void)setFirstCompletedRow:(int)first count:(int)count;
-(void)invalidate;

-(NSRect)updatedAreaInRect:(NSRect)rect;

-(void)drawInRect:(NSRect)rect bounds:(NSRect)bounds lowQuality:(BOOL)lowquality;

-(void)allocTexturesRect;
-(void)allocTextures2D;
-(void)uploadTextures;

-(void)drawNormalWithBounds:(NSRect)transbounds;
-(void)drawSampleSet:(XeeSampleSet *)set xScale:(float)x_scale yScale:(float)y_scale bounds:(NSRect)transbounds;
-(void)drawSingleSample:(XeeSamplePoint)sample xScale:(float)xscale yScale:(float)yscale bounds:(NSRect)transbounds;
-(void)drawSamplesOnTextureUnits:(XeeSamplePoint *)samples num:(int)num xScale:(float)xscale yScale:(float)yscale bounds:(NSRect)transbounds;

-(CGImageRef)makeCGImage;
-(int)CGImageBitsPerComponent;
-(int)CGImageBitsPerPixel;
-(CGBitmapInfo)CGImageBitmapInfo;
-(CGColorSpaceRef)CGImageCopyColorSpace;
-(XeePixelAccessFunc)CGImageReadPixelFunc;
-(void *)CGImageReadPixelContext;

-(int)bytesPerRow;
-(void *)data;

@end

@interface XeeBitmapTile:NSObject
{
	int x,y,width,height;

	GLuint tex,textarget,texintformat,textype,texformat;
	int realwidth;
	void *data;

	BOOL created;
	XeeSpan uploaded;

	GLuint lists;
}

-(id)initWithTarget:(GLuint)tt internalFormat:(GLuint)tif
	x:(int)x y:(int)y width:(int)width height:(int)height
	format:(GLuint)tf type:(GLuint)tt data:(void *)d;
-(void)dealloc;

-(void)uploadWithCompletedSpan:(XeeSpan)global_completed;
-(void)invalidate;

-(void)drawWithBounds:(NSRect)bounds minFilter:(GLuint)minfilter;
-(void)drawMultipleWithBounds:(NSRect)bounds minFilter:(GLuint)minfilter num:(int)num;

@end
