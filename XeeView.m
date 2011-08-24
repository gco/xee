#import "XeeView.h"
#import "XeeImage.h"
#import "XeeController.h"
#import "XeeTool.h"
#import "XeeMisc.h"

#import <OpenGL/GL.h>
#import <OpenGL/GLu.h>
#import <Carbon/Carbon.h>


GLuint make_resize_texture();


@implementation XeeView

-(id)initWithFrame:(NSRect)frameRect
{
	/*NSOpenGLPixelFormatAttribute attrs[]={ 
		NSOpenGLPFANoRecovery,
		NSOpenGLPFADoubleBuffer,
		//NSOpenGLPFAFullScreen,
		NSOpenGLPFAAccelerated,
//		NSOpenGLPFASampleBuffers,1,
//		NSOpenGLPFASamples,1,
		(NSOpenGLPixelFormatAttribute)0};
	NSOpenGLPixelFormat *format=[[[NSOpenGLPixelFormat alloc] initWithAttributes:attrs] autorelease];
*/
	if(self=[super initWithFrame:frameRect/* pixelFormat:format*/])
	{
		image=nil;
		invalidated=NO;

		drawresize=NO;
		lowquality=NO;

		currtool=nil;

		scrolltimer=nil;
		up=down=left=right=NO;

		delegate=nil;

		NSRect bounds=[self bounds];
		width=bounds.size.width;
		height=bounds.size.height;

		[[self openGLContext] makeCurrentContext];
		resizetex=make_resize_texture();

		long val=1;
		[[self openGLContext] setValues:&val forParameter:NSOpenGLCPSwapInterval];

		[self registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
	}
	return self;
}

-(void)dealloc
{
	[[self openGLContext] makeCurrentContext];
	glDeleteTextures(1,&resizetex);

	[image setAnimating:NO];
	[image setDelegate:nil];
	[image release];

	[currtool release];
	[scrolltimer release];

	[super dealloc];
}

-(void)viewDidMoveToWindow
{
	[[self window] setAcceptsMouseMovedEvents:YES];
}

-(void)drawRect:(NSRect)rect
{
	[[self openGLContext] makeCurrentContext];

	NSRect imgrect,bounds;

	if(image) imgrect=[self imageRect];

	if(invalidated||!image) // do a full update
	{
		invalidated=NO;

		bounds=NSMakeRect(0,0,width,height);
		if(image) bounds=NSIntersectionRect(bounds,imgrect);

		NSString *key;
		if([[self window] isKindOfClass:[XeeFullScreenWindow class]]) key=@"fullScreenBackground";
		else key=@"windowBackground";

		NSColor *clear=[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:key]];
		NSColor *clearrgb=[clear colorUsingColorSpaceName:NSDeviceRGBColorSpace];

		glClearColor([clearrgb redComponent],[clearrgb greenComponent],[clearrgb blueComponent],1);
		glClear(GL_COLOR_BUFFER_BIT);
	}
	else // do a partial update while loading an image
	{
		NSRect updated=[image updatedAreaInRect:imgrect];
		bounds=NSIntersectionRect(updated,NSMakeRect(0,0,width,height));
	}

	glViewport(bounds.origin.x,height-bounds.origin.y-bounds.size.height,bounds.size.width,bounds.size.height);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluOrtho2D(bounds.origin.x,bounds.origin.x+bounds.size.width,
	bounds.origin.y+bounds.size.height,bounds.origin.y);
	glMatrixMode(GL_MODELVIEW);

/*	glViewport(0,0,width,height);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluOrtho2D(0,width,height,0);
	glMatrixMode(GL_MODELVIEW);*/

	if(image)
	{
		[image drawInRect:imgrect bounds:bounds lowQuality:lowquality];
		[currtool drawInRect:imgrect];
	}

	if(drawresize)
	{
		glBindTexture(GL_TEXTURE_2D,resizetex);

		glEnable(GL_BLEND);
		glDisable(GL_TEXTURE_RECTANGLE_EXT);
		glEnable(GL_TEXTURE_2D);
		glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);

		float x1=width-16;
		float y1=height-16;
		float x2=width;
		float y2=height;

		glBegin(GL_QUADS);
		glTexCoord2f(0,0);
		glVertex2f(x1,y1);
		glTexCoord2f(1,0);
		glVertex2f(x2,y1);
		glTexCoord2f(1,1);
		glVertex2f(x2,y2);
		glTexCoord2f(0,1);
		glVertex2f(x1,y2);
		glEnd();
	}

	//[[self openGLContext] flushBuffer];
	glFlush();
}

-(void)reshape
{
	[[self openGLContext] makeCurrentContext];
	[[self openGLContext] update];

	NSPoint focus=[self focus];

	NSRect bounds=[self bounds];
	width=bounds.size.width;
	height=bounds.size.height;

	invalidated=YES;

	[self setFocus:focus];
}


-(BOOL)acceptsFirstResponder { return YES; }

-(BOOL)isOpaque { return YES; }

-(void)keyDown:(NSEvent *)event
{
	if(![[event characters] length])
	{
		[super keyDown:event];
		return;
	}

	unichar c=[[event characters] characterAtIndex:0];

	if(c==NSUpArrowFunctionKey) up=YES;
	else if(c==NSDownArrowFunctionKey) down=YES;
	else if(c==NSLeftArrowFunctionKey) left=YES;
	else if(c==NSRightArrowFunctionKey) right=YES;
	else [super keyDown:event];

	if(up||down||left||right) [self startScrolling];
}

-(void)keyUp:(NSEvent *)event
{
	if(![[event characters] length])
	{
		[super keyDown:event];
		return;
	}

	unichar c=[[event characters] characterAtIndex:0];

	if(c==NSUpArrowFunctionKey) up=NO;
	else if(c==NSDownArrowFunctionKey) down=NO;
	else if(c==NSLeftArrowFunctionKey) left=NO;
	else if(c==NSRightArrowFunctionKey) right=NO;
	else [super keyUp:event];

	if(!up&&!down&&!left&&!right) [self stopScrolling];
}

-(void)mouseDown:(NSEvent *)event
{
//	[[self window] setAcceptsMouseMovedEvents:YES];
//	[[self window] invalidateCursorRectsForView:self];

	lowquality=YES;

	NSPoint pos=[self convertPoint:[event locationInWindow] fromView:nil];
	[currtool mouseDownAt:pos event:event];
	[[currtool cursorAt:pos dragging:YES] set];
}

-(void)mouseUp:(NSEvent *)event
{
//	[[self window] setAcceptsMouseMovedEvents:NO];
//	[[self window] invalidateCursorRectsForView:self];

	lowquality=NO;

	NSPoint pos=[self convertPoint:[event locationInWindow] fromView:nil];
	[currtool mouseUpAt:pos event:event];
	[[currtool cursorAt:pos dragging:NO] set];

	[self invalidate];
}

-(void)mouseMoved:(NSEvent *)event
{
	NSPoint pos=[self convertPoint:[event locationInWindow] fromView:nil];
	[currtool mouseMovedTo:pos event:event];

	if(NSPointInRect(pos,[self bounds])) [[currtool cursorAt:pos dragging:NO] set];
	else [[NSCursor arrowCursor] set];
}

-(void)mouseDragged:(NSEvent *)event
{
	NSPoint pos=[self convertPoint:[event locationInWindow] fromView:nil];
	[currtool mouseDraggedTo:pos event:event];
	[[currtool cursorAt:pos dragging:YES] set];
}

/*-(void)resetCursorRects
{
	if(width<imgwidth||height<imgheight)
	{
		NSCursor *cursor;
		if([[self window] acceptsMouseMovedEvents]) cursor=[NSCursor closedHandCursor];
		else cursor=[NSCursor openHandCursor];

		if(drawresize)
		{
			NSRect rect1=[self visibleRect];
			NSRect rect2=[self visibleRect];
			rect1.size.width-=15;
			rect2.size.height-=15;
			[self addCursorRect:rect1 cursor:cursor];
			[self addCursorRect:rect2 cursor:cursor];
		}
		else
		{
			[self addCursorRect:[self visibleRect] cursor:cursor];
		}
	}
}*/

/*-(NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	return NSDragOperationGeneric;
}

-(BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard=[sender draggingPasteboard];
	NSArray *files=[pboard propertyListForType:NSFilenamesPboardType];

	[controller loadImage:[files objectAtIndex:0]];

    return YES;
}*/


-(void)invalidate
{
	invalidated=YES;
	[self setNeedsDisplay:YES];
}

-(void)xeeImageLoadingProgress:(XeeImage *)msgimage
{
	[self setNeedsDisplay:YES];
}

-(void)xeeImageDidChange:(XeeImage *)msgimage
{
	[self invalidate];
	[delegate xeeView:self imageDidChange:msgimage];
}

-(void)xeeImageSizeDidChange:(XeeImage *)msgimage
{
	[delegate xeeView:self imageSizeDidChange:msgimage];
}

-(void)xeeImagePropertiesDidChange:(XeeImage *)msgimage
{
	[delegate xeeView:self imagePropertiesDidChange:msgimage];
}



-(XeeImage *)image { return image; }



-(void)setDelegate:(id)newdelegate { delegate=newdelegate; }

-(void)setImage:(XeeImage *)img
{
	if(image!=img)
	{
		[image setAnimating:NO];
		[image setDelegate:nil];
		[image release];
		image=[img retain];
		[image setDelegate:self];
		[image setAnimatingDefault];
	}

	[self invalidate];
}

-(void)setImageSize:(NSSize)size
{
	NSPoint focus=[self focus];

	int oldwidth=imgwidth;
	int oldheight=imgheight;

	imgwidth=size.width;
	imgheight=size.height;

	focus.x*=(float)imgwidth/(float)oldwidth;
	focus.y*=(float)imgheight/(float)oldheight;

	[self setFocus:focus];

	[self invalidate];
}

-(void)setDrawResizeCorner:(BOOL)draw { drawresize=draw; }

-(void)startScrolling
{
	if(!scrolltimer)
	{
		prevtime=XeeGetTime();
		scrolltimer=[[NSTimer scheduledTimerWithTimeInterval:1.0/60.0 target:self selector:@selector(scroll:) userInfo:nil repeats:YES] retain];

		lowquality=YES;
	}
}

-(void)stopScrolling
{
	if(scrolltimer)
	{
		[scrolltimer invalidate];
		[scrolltimer release];
		scrolltimer=nil;

		lowquality=NO;
		[self invalidate];
	}
}

-(void)scroll:(NSTimer *)timer
{
	double time=XeeGetTime();
	double dt=time-prevtime;
	prevtime=time;

	double mult=1.0;

	if(GetCurrentKeyModifiers()&((1<<shiftKeyBit)|(1<<rightShiftKeyBit))) mult=3.0;

	int delta=1500.0*mult*dt;

	int old_x=x,old_y=y;

	if(left) x-=delta;
	if(right) x+=delta;
	if(up) y-=delta;
	if(down) y+=delta;

	[self clampCoords];
	if(x!=old_x||y!=old_y) [self invalidate];
}



-(NSPoint)focus
{
	NSPoint focus;

	if(imgwidth<width) focus.x=width/2;
	else focus.x=x+width/2;

	if(imgheight<height) focus.y=height/2;
	else focus.y=y+height/2;

	return(focus);
}

-(void)setFocus:(NSPoint)focus
{
	int old_x=x,old_y=y;

	x=focus.x-width/2;
	y=focus.y-height/2;

	[self clampCoords];
	if(x!=old_x||y!=old_y) [self invalidate];
}

-(void)clampCoords
{
	if(x>imgwidth-width) x=imgwidth-width;
	if(y>imgheight-height) y=imgheight-height;
	if(x<0) x=0;
	if(y<0) y=0;
}



-(NSRect)imageRect
{
	int draw_x,draw_y;
	if(imgwidth<width) draw_x=(width-imgwidth)/2;
	else draw_x=-x;

	if(imgheight<height) draw_y=(height-imgheight)/2;
	else draw_y=-y;

	return NSMakeRect(draw_x,draw_y,imgwidth,imgheight);
}

-(NSPoint)viewToPixel:(NSPoint)pos
{
	if(!image) return NSZeroPoint;

	NSRect imgrect=[self imageRect];
	XeeTransformationMatrix mtx=XeeTranslationMatrix(-imgrect.origin.x,-imgrect.origin.y);
	mtx=XeeMultiplyMatrices(XeeScalingMatrix(
		(float)[image width]/imgrect.size.width,
		(float)[image height]/imgrect.size.height),mtx);

	return XeeTransformPointWithMatrix(mtx,pos);
}

-(NSPoint)pixelToView:(NSPoint)pixel
{
	if(!image) return NSZeroPoint;

	NSRect imgrect=[self imageRect];
	XeeTransformationMatrix mtx=XeeScalingMatrix(
		imgrect.size.width/(float)[image width],
		imgrect.size.height/(float)[image height]);
	mtx=XeeMultiplyMatrices(XeeTranslationMatrix(imgrect.origin.x,imgrect.origin.y),mtx);

	return XeeTransformPointWithMatrix(mtx,pixel);
}



-(void)setTool:(XeeTool *)tool
{
	[currtool autorelease];
	currtool=[tool retain];
}

-(XeeTool *)tool { return currtool; }



-(BOOL)isFlipped { return YES; }

static const void *get_byte_pointer(void *bitmap) { return bitmap; }

-(void)copyGLtoQuartz
{
	int bytesperrow=width*4;
    void *bitmap=malloc(bytesperrow*height);

	[[self openGLContext] makeCurrentContext];

    glFinish(); // finish any pending OpenGL commands
	glPushAttrib(GL_ALL_ATTRIB_BITS);

	//glPixelStorei(GL_PACK_SWAP_BYTES, 0);
	//glPixelStorei(GL_PACK_LSB_FIRST, 0);
	//glPixelStorei(GL_PACK_IMAGE_HEIGHT, 0);
	glPixelStorei(GL_PACK_ALIGNMENT,4); // force 4-byte alignment from RGBA framebuffer
	glPixelStorei(GL_PACK_ROW_LENGTH,0);
	glPixelStorei(GL_PACK_SKIP_PIXELS,0);
	glPixelStorei(GL_PACK_SKIP_ROWS,0);

	glReadPixels(0,0,width,height,GL_BGRA,GL_UNSIGNED_INT_8_8_8_8_REV,bitmap);
	glPopAttrib();

    [self lockFocus];

    CGDataProviderDirectAccessCallbacks callbacks={get_byte_pointer,NULL,NULL,NULL};
    CGDataProviderRef provider=CGDataProviderCreateDirectAccess(bitmap,bytesperrow*height,&callbacks);
    CGColorSpaceRef cs=CGColorSpaceCreateDeviceRGB();
    CGImageRef cgimage=CGImageCreate(width,height,8,32,bytesperrow,cs,kCGImageAlphaNoneSkipFirst,provider,NULL,NO,kCGRenderingIntentDefault);

    CGContextRef gc=[[NSGraphicsContext currentContext] graphicsPort];
    CGContextDrawImage(gc,CGRectMake(0,0,width,height),cgimage);

    CGImageRelease(cgimage);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(cs);
    free(bitmap);

	[self unlockFocus];

	[[self window] flushWindow];
}

@end



@implementation NSObject (XeeViewDelegate)

-(void)xeeView:(XeeView *)view imageDidChange:(XeeImage *)image {}
-(void)xeeView:(XeeView *)view imageSizeDidChange:(XeeImage *)image {}
-(void)xeeView:(XeeView *)view imagePropertiesDidChange:(XeeImage *)image {}

@end



#define C0 0x00000000
#define C1 0x25000000
#define C2 0x8a222222
#define C3 0x8bd5d5d5

static unsigned long resize_data[256]=
{
	C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,
	C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,
	C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,
	C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,
	C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C1,C0,
	C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C1,C2,C0,
	C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C1,C2,C3,C0,
	C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C1,C2,C3,C0,C0,
	C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C1,C2,C3,C0,C1,C0,
	C0,C0,C0,C0,C0,C0,C0,C0,C0,C1,C2,C3,C0,C1,C2,C0,
	C0,C0,C0,C0,C0,C0,C0,C0,C1,C2,C3,C0,C1,C2,C3,C0,
	C0,C0,C0,C0,C0,C0,C0,C1,C2,C3,C0,C1,C2,C3,C0,C0,
	C0,C0,C0,C0,C0,C0,C1,C2,C3,C0,C1,C2,C3,C0,C1,C0,
	C0,C0,C0,C0,C0,C1,C2,C3,C0,C1,C2,C3,C0,C1,C2,C0,
	C0,C0,C0,C0,C1,C2,C3,C0,C1,C2,C3,C0,C1,C2,C3,C0,
	C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,C0,
};

GLuint make_resize_texture()
{
	GLuint tex;
	glGenTextures(1,&tex),
	glBindTexture(GL_TEXTURE_2D,tex);

	glPixelStorei(GL_UNPACK_ROW_LENGTH,16);
	glPixelStorei(GL_UNPACK_ALIGNMENT,1);
	glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE,GL_TRUE);
	glPixelStorei(GL_UNPACK_SKIP_PIXELS,0);
	glPixelStorei(GL_UNPACK_SKIP_ROWS,0);
	glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA8,16,16,0,GL_BGRA,GL_UNSIGNED_INT_8_8_8_8_REV,resize_data);

	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP);
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP);
	glTexEnvf(GL_TEXTURE_ENV,GL_TEXTURE_ENV_MODE,GL_REPLACE);

	return tex;
}