#import "XeeImage.h"
#import "XeeBitmapTile.h"
#import "XeeSampleSet.h"

#import <OpenGL/GL.h>
#import <OpenGL/GLu.h>

typedef void (*XeeReadPixelFunction)(uint8 *row,int x,int pixelsize,uint8 *dest);


@interface XeeTileImage:XeeImage
{
	@public
	uint8 *data;
	int bytesperpixel,bytesperrow;
	@protected
	BOOL freedata,premultiplied;
	GLuint texintformat,texformat,textype;

	XeeSpan completed,uploaded,drawn;

	GLuint textarget;
	NSMutableArray *tiles;
	BOOL needsupdate;
	NSOpenGLContext *context;
}

-(id)init;
-(void)dealloc;

-(void)setData:(uint8 *)pixeldata freeData:(BOOL)willfree width:(int)pixelwidth height:(int)pixelheight
bytesPerPixel:(int)bppixel bytesPerRow:(int)bprow premultiplied:(BOOL)premult
glInternalFormat:(int)intformat glFormat:(int)format glType:(int)type;

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

-(GLuint)magFilter;

-(int)bytesPerRow;
-(uint8 *)data;

-(CGImageRef)createCGImage;
-(int)bitsPerComponentForCGImage;
-(int)bytesPerPixelForCGImage;
-(CGColorSpaceRef)createColorSpaceForCGImage;
-(int)bitmapInfoForCGImage;
-(XeeReadPixelFunction)readPixelFunctionForCGImage;

@end

static inline uint8 *XeeImageDataRow(XeeTileImage *image,int row) { return image->data+row*image->bytesperrow; }
