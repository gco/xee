#import <Cocoa/Cocoa.h>

#import <OpenGL/GL.h>
#import <OpenGL/GLu.h>

@class XeeImage,XeeController,XeeTool;

@interface XeeView:NSOpenGLView
{
	XeeImage *image;

	int x,y;
	int width,height;
	int imgwidth,imgheight;
	BOOL invalidated;

	BOOL drawresize,lowquality;

	XeeTool *currtool;

	NSTimer *scrolltimer;
	BOOL up,down,left,right;
	double prevtime;

	GLuint resizetex;

	IBOutlet id delegate;
}

-(id)initWithFrame:(NSRect)frameRect;
-(void)dealloc;

-(void)drawRect:(NSRect)rect;

-(void)reshape;
-(BOOL)acceptsFirstResponder;
-(BOOL)isOpaque;

-(void)keyDown:(NSEvent *)event;
-(void)keyUp:(NSEvent *)event;
-(void)mouseDown:(NSEvent *)event;
-(void)mouseUp:(NSEvent *)event;
-(void)mouseDragged:(NSEvent *)event;

//-(void)resetCursorRects;

-(void)invalidate;
-(void)xeeImageLoadingProgress:(XeeImage *)image;
-(void)xeeImageDidChange:(XeeImage *)image;
-(void)xeeImageSizeDidChange:(XeeImage *)image;
-(void)xeeImagePropertiesDidChange:(XeeImage *)image;

-(XeeImage *)image;

-(void)setDelegate:(id)delegate;
-(void)setImage:(XeeImage *)img;
-(void)setImageSize:(NSSize)size;
-(void)setDrawResizeCorner:(BOOL)draw;

-(void)startScrolling;
-(void)stopScrolling;
-(void)scroll:(NSTimer *)timer;

-(NSPoint)focus;
-(void)setFocus:(NSPoint)focus;
-(void)clampCoords;

-(NSRect)imageRect;
-(NSPoint)viewToPixel:(NSPoint)pos;
-(NSPoint)pixelToView:(NSPoint)pixel;

-(void)setTool:(XeeTool *)tool;
-(XeeTool *)tool;

-(BOOL)isFlipped;
-(void)copyGLtoQuartz;

@end


@interface NSObject (XeeViewDelegate)

-(void)xeeView:(XeeView *)view imageDidChange:(XeeImage *)image;
-(void)xeeView:(XeeView *)view imageSizeDidChange:(XeeImage *)image;
-(void)xeeView:(XeeView *)view imagePropertiesDidChange:(XeeImage *)image;

@end
