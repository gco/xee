#import "XeeTool.h"
#import "XeeView.h"
#import "XeeImage.h"

@implementation XeeTool

-(id)initWithView:(XeeView *)imageview
{
	if(self=[super init])
	{
		view=imageview;
	}
	return self;
}

-(void)mouseDownAt:(NSPoint)pos event:(NSEvent *)event {}

-(void)mouseUpAt:(NSPoint)pos event:(NSEvent *)event {}

-(void)mouseMovedTo:(NSPoint)pos event:(NSEvent *)event {}

-(void)mouseDraggedTo:(NSPoint)pos event:(NSEvent *)event {}

-(NSCursor *)cursorAt:(NSPoint)pos dragging:(BOOL)dragging { return [NSCursor arrowCursor]; }

-(void)drawInRect:(NSRect)imgrect {}

@end


@implementation XeeMoveTool

-(void)mouseDraggedTo:(NSPoint)pos event:(NSEvent *)event
{
	NSPoint focus=[view focus];
	focus.x-=[event deltaX];
	focus.y-=[event deltaY];
	[view setFocus:focus];
}

-(NSCursor *)cursorAt:(NSPoint)pos dragging:(BOOL)dragging
{
	if(dragging) return [NSCursor closedHandCursor];
	else return [NSCursor openHandCursor];
}

@end


@implementation XeeCropTool

-(id)initWithView:(XeeView *)imageview
{
	if(self=[super initWithView:imageview])
	{
		x1=y1=x2=y2=-1;
	}
	return self;
}

-(void)mouseDownAt:(NSPoint)pos event:(NSEvent *)event
{
	NSPoint pixel=[view viewToPixel:pos];
	x1=x2=pixel.x;
	y1=y2=pixel.y;
	[view invalidate];
}

-(void)mouseUpAt:(NSPoint)pos event:(NSEvent *)event
{
}

-(void)mouseDraggedTo:(NSPoint)pos event:(NSEvent *)event
{
	NSPoint pixel=[view viewToPixel:pos];
	x2=pixel.x;
	y2=pixel.y;
	[view invalidate];
}

-(NSCursor *)cursorAt:(NSPoint)pos dragging:(BOOL)dragging
{
	return [NSCursor crosshairCursor];
}

#define XeeGLQuad(x1,y1,x2,y2) { glVertex2f(x1,y1); glVertex2f(x2,y1); glVertex2f(x2,y2); glVertex2f(x1,y2); }

-(void)drawInRect:(NSRect)imgrect
{
	if(x1>=0)
	{
		NSPoint p1=[view pixelToView:NSMakePoint(fminf(x1,x2),fminf(y1,y2))];
		NSPoint p2=[view pixelToView:NSMakePoint(fmaxf(x1,x2)+1,fmaxf(y1,y2)+1)];

		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);


		int top=p1.y-imgrect.origin.y;
		int bottom=imgrect.origin.y+imgrect.size.height-p2.y;
		int left=p1.x-imgrect.origin.x;
		int right=imgrect.origin.x+imgrect.size.width-p2.x;

		NSPoint tl=imgrect.origin;
		NSPoint br=NSMakePoint(imgrect.origin.x+imgrect.size.width,imgrect.origin.y+imgrect.size.height);

		glColor4f(0,0,0,0.5);
		glBegin(GL_QUADS);

		if(top>0) XeeGLQuad(tl.x,tl.y,br.x,p1.y);
		if(bottom>0) XeeGLQuad(tl.x,p2.y,br.x,br.y);
		if(left>0) XeeGLQuad(tl.x,p1.y,p1.x,p2.y);
		if(right>0) XeeGLQuad(p2.x,p1.y,br.x,p2.y);

		glColor3f(1,1,1);
		XeeGLQuad(p1.x-1,p1.y-1,p2.x+1,p1.y);
		XeeGLQuad(p1.x-1,p2.y,p2.x+1,p2.y+1);
		XeeGLQuad(p1.x-1,p1.y,p1.x,p2.y);
		XeeGLQuad(p2.x,p1.y,p2.x+1,p2.y);

		glEnd();

/*		glColor3f(1,1,1);
		glBegin(GL_LINE_STRIP);
		glVertex2i(p1.x,p1.y);
		glVertex2i(p2.x,p1.y);
		glVertex2i(p2.x,p2.y);
		glVertex2i(p1.x,p2.y);
		glVertex2i(p1.x,p1.y);
		glEnd();*/
	}
}

-(NSRect)croppingRect
{
	NSRect currcrop=[[view image] croppingRect];
	return NSMakeRect(fminf(x1,x2)+currcrop.origin.x,fminf(y1,y2)+currcrop.origin.y,fabsf(x1-x2)+1,fabsf(y1-y2)+1);
}

@end
