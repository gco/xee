#import "XeeView.h"
#import "XeeImage.h"
#import "XeeController.h"
#import "XeeTool.h"
#import "XeeGraphicsStuff.h"
#import "CSKeyboardShortcuts.h"

#import <OpenGL/GL.h>
#import <OpenGL/GLu.h>
#import <Carbon/Carbon.h>



GLuint make_resize_texture();

@interface NSEvent (DeviceDelta)
-(float)deviceDeltaX;
-(float)deviceDeltaY;
@end



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
		tool=nil;

		invalidated=NO;

		drawresize=NO;
		lowquality=NO;
		inside=NO;
		clicking=NO;

		scrolltimer=nil;
		up=down=left=right=NO;

		delegate=nil;

		NSRect bounds=[self bounds];
		width=bounds.size.width;
		height=bounds.size.height;

		[[self openGLContext] makeCurrentContext];
		resizetex=make_resize_texture();

		GLint val=1;
		[[self openGLContext] setValues:&val forParameter:NSOpenGLCPSwapInterval];

		[self registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
	}
	return self;
}

-(void)dealloc
{
	[[self openGLContext] makeCurrentContext];
	glDeleteTextures(1,&resizetex);

	[tool release];

	[image setAnimating:NO];
	[image setDelegate:nil];
	[image release];
	[scrolltimer release];

	[super dealloc];
}

-(void)awakeFromNib
{
	[[self window] setAcceptsMouseMovedEvents:YES];
}


-(BOOL)acceptsFirstResponder { return YES; }

-(BOOL)isOpaque { return YES; }

-(BOOL)isFlipped { return YES; }



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



-(void)drawRect:(NSRect)rect
{
	[[self openGLContext] makeCurrentContext];

	NSRect imgrect=[self imageRect];
	NSRect bounds;

	if(invalidated||!image) // do a full update
	{
		invalidated=NO;
		bounds=imgrect;

		NSString *key;
		if([[self window] isKindOfClass:[XeeFullScreenWindow class]]) key=@"fullScreenBackground";
		else key=@"windowBackground";

		NSColor *clear=[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:key]];
		[clear glSetForClear];

		glClear(GL_COLOR_BUFFER_BIT);
	}
	else // do a partial update while loading an image
	{
		bounds=[image updatedAreaInRect:imgrect];
	}

	// clip bounds to view
	bounds=NSIntersectionRect(bounds,NSMakeRect(0,0,width,height));

	// setup partial view
	glViewport(bounds.origin.x,height-bounds.origin.y-bounds.size.height,bounds.size.width,bounds.size.height);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluOrtho2D(bounds.origin.x,bounds.origin.x+bounds.size.width,bounds.origin.y+bounds.size.height,bounds.origin.y);
	glMatrixMode(GL_MODELVIEW);

	if(image) [image drawInRect:imgrect bounds:bounds lowQuality:lowquality];

	[tool draw];

	if(drawresize) [self drawResizeHandle];

	//[[self openGLContext] flushBuffer];
	glFlush();
}



-(void)drawResizeHandle
{
	// setup a full view
	glViewport(0,0,width,height);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluOrtho2D(0,width,height,0);
	glMatrixMode(GL_MODELVIEW);

	// draw resize handle
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



-(void)keyDown:(NSEvent *)event
{
	CSAction *action=[[CSKeyboardShortcuts defaultShortcuts] actionForEvent:event ignoringModifiers:CSShift];
	if(action)
	{
		NSString *identifier=[action identifier];
		if([identifier isEqual:@"scrollUp"]) up=YES;
		else if([identifier isEqual:@"scrollDown"]) down=YES;
		else if([identifier isEqual:@"scrollLeft"]) left=YES;
		else if([identifier isEqual:@"scrollRight"]) right=YES;
		else [super keyDown:event];
	}
	else [super keyDown:event];

	if(up||down||left||right) [self startScrolling];
}

-(void)keyUp:(NSEvent *)event
{
	CSAction *action=[[CSKeyboardShortcuts defaultShortcuts] actionForEvent:event ignoringModifiers:CSShift];
	if(action)
	{
		NSString *identifier=[action identifier];
		if([identifier isEqual:@"scrollUp"]) up=NO;
		else if([identifier isEqual:@"scrollDown"]) down=NO;
		else if([identifier isEqual:@"scrollLeft"]) left=NO;
		else if([identifier isEqual:@"scrollRight"]) right=NO;
		else [super keyUp:event];
	}
	else [super keyUp:event];

	if(!up&&!down&&!left&&!right) [self stopScrolling];
}

-(void)mouseDown:(NSEvent *)event
{
	NSPoint pos=[self convertPoint:[event locationInWindow] fromView:nil];

	clicking=YES;
	lowquality=YES;

	if([event clickCount]==2) [tool mouseDoubleClickedAt:pos];
	else [tool mouseDownAt:pos];
	[self updateCursorForMousePosition:pos];
}

-(void)mouseUp:(NSEvent *)event
{
	NSPoint pos=[self convertPoint:[event locationInWindow] fromView:nil];

	clicking=NO;
	lowquality=NO;

	[tool mouseUpAt:pos];
	[self updateCursorForMousePosition:pos];

	[self invalidate];
}

-(void)mouseMoved:(NSEvent *)event
{
	NSPoint pos=[self convertPoint:[event locationInWindow] fromView:nil];

	[tool mouseMovedTo:pos relative:NSMakePoint([event deltaX],[event deltaY])];
	[self updateCursorForMousePosition:pos];

	if(hidecursor)
	{
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideCursor) object:nil];
		[self performSelector:@selector(hideCursor) withObject:nil afterDelay:2];
	}
}

-(void)mouseDragged:(NSEvent *)event
{
	NSPoint pos=[self convertPoint:[event locationInWindow] fromView:nil];

	[tool mouseDraggedTo:pos relative:NSMakePoint([event deltaX],[event deltaY])];
	[self updateCursorForMousePosition:pos];
}

-(void)scrollWheel:(NSEvent *)event
{
	if([[NSUserDefaults standardUserDefaults] integerForKey:@"scrollWheelFunction"]==1)
	{
		float dx,dy;
		if(IsSmoothScrollEvent(event))
		{
			dx=[event deviceDeltaX];
			dy=[event deviceDeltaY];
		}
		else
		{
			dx=[event deltaX]*24;
			dy=[event deltaY]*24;
		}
			
		//NSLog(@"scrollwheel: scrollEvent is %i, %f dx, %f dy, %f dx, %f dy", scrollEvent, dx, dy);
		
 		int old_x=x,old_y=y;
		x-=dx;
		y-=dy;
		[self clampCoords];
		if(x!=old_x||y!=old_y) [self invalidateImageAndTool];
	}
}

-(void)xeeImageLoadingProgress:(XeeImage *)msgimage
{
	[self setNeedsDisplay:YES];
}

-(void)xeeImageDidChange:(XeeImage *)msgimage;
{
	[self invalidate];
	[delegate xeeView:self imageDidChange:msgimage];
}

-(void)xeeImageSizeDidChange:(XeeImage *)msgimage;
{
	// cancel tool
	[delegate xeeView:self imageSizeDidChange:msgimage];
}

-(void)xeeImagePropertiesDidChange:(XeeImage *)msgimage;
{
	[delegate xeeView:self imagePropertiesDidChange:msgimage];
}



-(void)invalidate
{
	invalidated=YES;
	[self setNeedsDisplay:YES];
}

-(void)invalidateTool
{
	NSPoint position=[self convertPoint:[[self window] mouseLocationOutsideOfEventStream] fromView:nil];
	if(clicking) [tool mouseDraggedTo:position relative:NSMakePoint(0,0)];
	else [tool mouseMovedTo:position relative:NSMakePoint(0,0)];

	[self updateCursorForMousePosition:position];
}

-(void)invalidateImageAndTool
{
	[self invalidate];
	[self invalidateTool];
}

-(void)updateCursorForMousePosition:(NSPoint)pos
{
	BOOL wasinside=inside;

	if(clicking)
	{
		inside=YES;
	}
	else if(drawresize)
	{
		NSRect rect1=[self bounds];
		NSRect rect2=[self bounds];
		rect1.size.width-=15;
		rect2.size.height-=15;

		inside=NSPointInRect(pos,rect1)||NSPointInRect(pos,rect2);
	}
	else
	{
		inside=NSPointInRect(pos,[self bounds]);
	}

	if(inside) [[tool cursor] set];
	else if(wasinside) [[NSCursor arrowCursor] set];
}


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

	if(GetCurrentKeyModifiers()&shiftKey) mult=3.0;

	int delta=1500.0*mult*dt;

	int old_x=x,old_y=y;

	if(left) x-=delta;
	if(right) x+=delta;
	if(up) y-=delta;
	if(down) y+=delta;

	[self clampCoords];
	if(x!=old_x||y!=old_y) [self invalidateImageAndTool];
}



-(NSPoint)focus
{
	NSPoint focus;

	if(imgwidth<width) focus.x=width/2;
	else focus.x=x+width/2;

	if(imgheight<height) focus.y=height/2;
	else focus.y=y+height/2;

	return focus;
}

-(void)setFocus:(NSPoint)focus
{
	int old_x=x,old_y=y;

	x=focus.x-width/2;
	y=focus.y-height/2;
	[self clampCoords];

	if(x!=old_x||y!=old_y) [self invalidateImageAndTool];
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
	if(image)
	{
		int draw_x,draw_y;
		if(imgwidth<width) draw_x=(width-imgwidth)/2;
		else draw_x=-x;

		if(imgheight<height) draw_y=(height-imgheight)/2;
		else draw_y=-y;

		return NSMakeRect(draw_x,draw_y,imgwidth,imgheight);
	}
	else return NSZeroRect;
}

-(XeeMatrix)imageToViewTransformMatrix
{
	return XeeTransformRectToRectMatrix(NSMakeRect(0,0,[image width],[image height]),[self imageRect]);
}

-(XeeMatrix)viewToImageTransformMatrix
{
	return XeeTransformRectToRectMatrix([self imageRect],NSMakeRect(0,0,[image width],[image height]));
}

-(id)delegate { return delegate; }

-(XeeImage *)image { return image; }

-(XeeTool *)tool { return tool; }



-(void)setDelegate:(id)newdelegate
{
	delegate=newdelegate;
}

-(void)setImage:(XeeImage *)img
{
	[image setAnimating:NO];
	[image setDelegate:nil];

// cancel tool

	if(image!=img)
	{
		[image release];
		image=[img retain];
	}

	[image setDelegate:self];
	[image setAnimatingDefault];

	[self invalidate];
}

-(void)setTool:(XeeTool *)newtool
{
	if(newtool==tool) return;
	XeeTool *oldtool=tool;

	tool=[newtool retain];

	[oldtool end];
	[oldtool release];

	[newtool begin];

	[self invalidateImageAndTool];
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
	[self performSelector:@selector(invalidateTool) withObject:nil afterDelay:0];
}

-(void)setDrawResizeCorner:(BOOL)draw { drawresize=draw; }

-(void)setCursorShouldHide:(BOOL)shouldhide
{
	[NSCursor setHiddenUntilMouseMoves:shouldhide];
	hidecursor=shouldhide;
	if(!hidecursor) [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideCursor) object:nil];
}


-(void)hideCursor
{
	[NSCursor setHiddenUntilMouseMoves:YES];
}

static const void *XeeCopyGLGetBytePointer(void *bitmap) { return bitmap; }

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

	#ifdef __BIG_ENDIAN__
	glReadPixels(0,0,width,height,GL_BGRA,GL_UNSIGNED_INT_8_8_8_8_REV,bitmap);
	#else
	glReadPixels(0,0,width,height,GL_BGRA,GL_UNSIGNED_INT_8_8_8_8,bitmap);
	#endif
	glPopAttrib();

    [self lockFocus];

    CGDataProviderDirectAccessCallbacks callbacks={XeeCopyGLGetBytePointer,NULL,NULL,NULL};
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

static uint32_t resize_data[256]=
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