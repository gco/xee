#import "XeeTypes.h"

#import <OpenGL/GL.h>
#import <OpenGL/GLu.h>

@class XeeImage,XeeController,XeeTool;

@interface XeeView:NSOpenGLView
{
	XeeImage *image;
	XeeTool *tool;

	int x,y;
	int width,height;
	int imgwidth,imgheight;
	BOOL invalidated;

	BOOL drawresize,hidecursor,lowquality,inside,clicking;

	NSTimer *scrolltimer;
	BOOL up,down,left,right;
	double prevtime;

	GLuint resizetex;

	id delegate;
}

-(id)initWithFrame:(NSRect)frameRect;
-(void)dealloc;

-(BOOL)acceptsFirstResponder;
-(BOOL)isOpaque;
-(BOOL)isFlipped;

-(void)reshape;

-(void)drawRect:(NSRect)rect;
-(void)drawResizeHandle;

-(void)keyDown:(NSEvent *)event;
-(void)keyUp:(NSEvent *)event;
-(void)mouseDown:(NSEvent *)event;
-(void)mouseUp:(NSEvent *)event;
-(void)mouseDragged:(NSEvent *)event;
-(void)scrollWheel:(NSEvent *)event;

-(void)xeeImageLoadingProgress:(XeeImage *)msgimage;
-(void)xeeImageDidChange:(XeeImage *)msgimage;
-(void)xeeImageSizeDidChange:(XeeImage *)msgimage;
-(void)xeeImagePropertiesDidChange:(XeeImage *)msgimage;

-(void)invalidate;
-(void)invalidateTool;
-(void)invalidateImageAndTool;
-(void)updateCursorForMousePosition:(NSPoint)pos;

-(void)startScrolling;
-(void)stopScrolling;
-(void)scroll:(NSTimer *)timer;

-(NSPoint)focus;
-(void)setFocus:(NSPoint)focus;
-(void)clampCoords;

-(NSRect)imageRect;
-(XeeMatrix)imageToViewTransformMatrix;
-(XeeMatrix)viewToImageTransformMatrix;
-(id)delegate;
-(XeeImage *)image;
-(XeeTool *)tool;

-(void)setDelegate:(id)newdelegate;
-(void)setImage:(XeeImage *)img;
-(void)setTool:(XeeTool *)newtool;
-(void)setImageSize:(NSSize)size;
-(void)setDrawResizeCorner:(BOOL)draw;
-(void)setCursorShouldHide:(BOOL)shouldhide;

-(void)hideCursor;
-(void)copyGLtoQuartz;

@end

@interface NSObject (XeeViewDelegate)

-(void)xeeView:(XeeView *)view imageDidChange:(XeeImage *)image;
-(void)xeeView:(XeeView *)view imageSizeDidChange:(XeeImage *)image;
-(void)xeeView:(XeeView *)view imagePropertiesDidChange:(XeeImage *)image;

@end
