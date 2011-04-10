#import "XeeCropTool.h"
#import "XeeView.h"
#import "XeeImage.h"
#import "XeeGraphicsStuff.h"
#import "XeeController.h"

#import <OpenGL/GL.h>



static void XeeGLPoint(float x1,float y1);
static void XeeGLHLine(float x1,float y1,float x2);
static void XeeGLVLine(float x1,float y1,float y2);
static void XeeGLRect(float x1,float y1,float x2,float y2);


@implementation XeeCropTool

-(id)initWithView:(XeeView *)ownerview
{
	if(self=[super initWithView:ownerview])
	{
		o=8;
		i=8;

		crop_width=0;
		crop_height=0;

		area=XeeOutsideArea;
		mode=XeeNoCropMode;
	}
	return self;
}

-(void)dealloc
{
	[super dealloc];
}

-(void)end
{
	[[view image] triggerPropertyChangeAction]; 
}

-(void)mouseDownAt:(NSPoint)position
{
	[super mouseDownAt:position];

	[self findAreaForPosition:position];

//	NSPoint p=XeeTransformPoint([view viewToImageTransformMatrix],position);
	NSPoint p=XeeTransformPoint(XeeInverseMatrix([view imageToViewTransformMatrix]),position);

	int x=p.x,y=p.y;

	NSRect crop=XeeTransformRect(
		[view imageToViewTransformMatrix],
		NSMakeRect(crop_x,crop_y,crop_width,crop_height)
	);

	float x1=crop.origin.x;
	float y1=crop.origin.y;
	float x2=x1+crop.size.width;
	float y2=y1+crop.size.height;

	switch(area)
	{
		case XeeOutsideArea:
			crop_x=start_x=x;
			crop_y=start_y=y;
			crop_width=1;
			crop_height=1;
			offs_x=offs_y=0;
			mode=XeeResizeCropMode;
			[view invalidate];
		break;

		case XeeBottomRightArea:
			start_x=crop_x;
			start_y=crop_y;
			offs_x=x2-1-position.x;
			offs_y=y2-1-position.y;
			mode=XeeResizeCropMode;
		break;

		case XeeBottomLeftArea:
			start_x=crop_x+crop_width-1;
			start_y=crop_y;
			offs_x=x1-position.x;
			offs_y=y2-1-position.y;
			mode=XeeResizeCropMode;
		break;

		case XeeTopRightArea:
			start_x=crop_x;
			start_y=crop_y+crop_height-1;
			offs_x=x2-1-position.x;
			offs_y=y1-position.y;
			mode=XeeResizeCropMode;
		break;

		case XeeTopLeftArea:
			start_x=crop_x+crop_width-1;
			start_y=crop_y+crop_height-1;
			offs_x=x1-position.x;
			offs_y=y1-position.y;
			mode=XeeResizeCropMode;
		break;

		case XeeBottomArea:
			start_y=crop_y;
			offs_y=y2-1-position.y;
			mode=XeeVerticalResizeCropMode;
		break;

		case XeeTopArea:
			start_y=crop_y+crop_height-1;
			offs_y=y1-position.y;
			mode=XeeVerticalResizeCropMode;
		break;

		case XeeRightArea:
			start_x=crop_x;
			offs_x=x2-1-position.x;
			mode=XeeHorizontalResizeCropMode;
		break;

		case XeeLeftArea:
			start_x=crop_x+crop_width-1;
			offs_x=x1-position.x;
			mode=XeeHorizontalResizeCropMode;
		break;

		case XeeInsideArea:
			offs_x=crop_x-x;
			offs_y=crop_y-y;
			mode=XeeMoveCropMode;
		break;
	}

	[[view image] triggerPropertyChangeAction]; 
}

-(void)mouseUpAt:(NSPoint)position
{
	[super mouseUpAt:position];

	mode=XeeNoCropMode;

	[self findAreaForPosition:position];
	[view invalidate];
	[[view image] triggerPropertyChangeAction]; 
}

-(void)mouseMovedTo:(NSPoint)position relative:(NSPoint)relative
{
	int oldarea=area;
	[self findAreaForPosition:position];
	if(oldarea!=area) [view invalidate];
}

-(void)mouseDoubleClickedAt:(NSPoint)position
{
	[self retain]; // The tool gets released in confirm:, so make sure we don't die quite yet.
	[[view delegate] confirm:nil];
	[[view image] triggerPropertyChangeAction]; 
	[self release];
}

-(void)mouseDraggedTo:(NSPoint)position relative:(NSPoint)relative
{
	NSPoint p;
	int x,y;
	int img_w=[[view image] width];
	int img_h=[[view image] height];
	switch(mode)
	{
		case XeeResizeCropMode:
			position.x+=offs_x; position.y+=offs_y;
			p=XeeTransformPoint([view viewToImageTransformMatrix],position);
			x=p.x; y=p.y;

			crop_x=imin(start_x,x);
			crop_y=imin(start_y,y);
			crop_width=iabs(start_x-x)+1;
			crop_height=iabs(start_y-y)+1;

			if(crop_x<0) { crop_width+=crop_x; crop_x=0; }
			if(crop_y<0) { crop_height+=crop_y; crop_y=0; }
			if(crop_x+crop_width>img_w) crop_width=img_w-crop_x;
			if(crop_y+crop_height>img_h) crop_height=img_h-crop_y;

			if(x>=start_x)
			{
				if(y>=start_y) area=XeeBottomRightArea;
				else area=XeeTopRightArea;
			}
			else
			{
				if(y>=start_y) area=XeeBottomLeftArea;
				else area=XeeTopLeftArea;
			}

			[view invalidate];
		break;

		case XeeVerticalResizeCropMode:
			position.y+=offs_y;
			p=XeeTransformPoint([view viewToImageTransformMatrix],position);
			y=p.y;

			crop_y=imin(start_y,y);
			crop_height=iabs(start_y-y)+1;

			if(crop_y<0) { crop_height+=crop_y; crop_y=0; }
			if(crop_y+crop_height>img_h) crop_height=img_h-crop_y;

			[view invalidate];
		break;

		case XeeHorizontalResizeCropMode:
			position.x+=offs_x;
			p=XeeTransformPoint([view viewToImageTransformMatrix],position);
			x=p.x;

			crop_x=imin(start_x,x);
			crop_width=iabs(start_x-x)+1;

			if(crop_x<0) { crop_width+=crop_x; crop_x=0; }
			if(crop_x+crop_width>img_w) crop_width=img_w-crop_x;

			[view invalidate];
		break;

		case XeeMoveCropMode:
			p=XeeTransformPoint([view viewToImageTransformMatrix],position);
			crop_x=p.x+offs_x;
			crop_y=p.y+offs_y;

			if(crop_x<0) crop_x=0;
			if(crop_y<0) crop_y=0;
			if(crop_x+crop_width>img_w) crop_x=img_w-crop_width;
			if(crop_y+crop_height>img_h) crop_y=img_h-crop_height;

			[view invalidate];
		break;
	}

	[[view image] triggerPropertyChangeAction]; 
}

-(void)findAreaForPosition:(NSPoint)position
{
	if(!crop_width) { area=XeeOutsideArea; return; }

	NSRect crop=XeeTransformRect(
		[view imageToViewTransformMatrix],
		NSMakeRect(crop_x,crop_y,crop_width,crop_height)
	);

	float x1=crop.origin.x;
	float y1=crop.origin.y;
	float x2=x1+crop.size.width;
	float y2=y1+crop.size.height;

	BOOL topedge=position.y>=y1-o&&position.y<y1+i;
	BOOL bottomedge=position.y>=y2-i&&position.y<y2+o;
	BOOL leftedge=position.x>=x1-o&&position.x<x1+i;
	BOOL rightedge=position.x>=x2-i&&position.x<x2+o;
	BOOL touching=position.x>=x1-o&&position.x<x2+o&&position.y>=y1-o&&position.y<y2+o;
	BOOL inside=position.x>=x1+i&&position.x<x2-i&&position.y>=y1+i&&position.y<y2-i;

	if(inside) area=XeeInsideArea;
	else if(!touching) area=XeeOutsideArea;
	else if(bottomedge&&rightedge) area=XeeBottomRightArea;
	else if(bottomedge&&leftedge) area=XeeBottomLeftArea;
	else if(topedge&&rightedge) area=XeeTopRightArea;
	else if(topedge&&leftedge) area=XeeTopLeftArea;
	else if(topedge) area=XeeTopArea;
	else if(bottomedge) area=XeeBottomArea;
	else if(leftedge) area=XeeLeftArea;
	else if(rightedge) area=XeeRightArea;
}

-(NSCursor *)cursor
{
	if(clicking) return nil;

	if(!crop_width||!crop_height) return [NSCursor crosshairCursor];

	switch(area)
	{
		case XeeOutsideArea: return [NSCursor crosshairCursor];
		case XeeInsideArea: return [NSCursor openHandCursor];
		default:
		case XeeTopLeftArea:
		case XeeTopRightArea:
		case XeeBottomLeftArea:
		case XeeBottomRightArea: return [NSCursor arrowCursor];
		case XeeTopArea:
		case XeeBottomArea: return [NSCursor resizeUpDownCursor];
		case XeeLeftArea:
		case XeeRightArea: return [NSCursor resizeLeftRightCursor];
	}
}

-(void)draw
{
	if(!crop_width) return;

	NSRect crop=XeeTransformRect(
		[view imageToViewTransformMatrix],
		NSMakeRect(crop_x,crop_y,crop_width,crop_height)
	);

	float x1=crop.origin.x;
	float y1=crop.origin.y;
	float x2=x1+crop.size.width;
	float y2=y1+crop.size.height;

	NSSize size=[view bounds].size;
	float width=size.width;
	float height=size.height;

	NSColor *selcol=[NSColor alternateSelectedControlColor];
	NSColor *selframecol=[selcol blendedColorWithFraction:0.5 ofColor:[NSColor colorWithDeviceWhite:0.33 alpha:1]];

	glDisable(GL_TEXTURE_RECTANGLE_EXT);
	glDisable(GL_TEXTURE_2D);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);

	#define BACK_COL 0,0,0,0.5
	#define DARK_COL 0.33,0.33,0.33,1
	#define LIGHT_COL 0.67,0.67,0.67,1
	#define HIGHLIGHT_COL 0.9,0.9,0.9,1
//	#define LIGHT_COL 0,1,0,0.3
//	#define DARK_COL 1,0,0,0.3

	glBegin(GL_QUADS);

	glColor4f(BACK_COL);

	// Darken area around crop
	XeeGLRect(   0,   0, x1-o,height);
	XeeGLRect(x2+o,   0,width,height);
	XeeGLRect(x1-o,   0, x2+o, y1-o);
	XeeGLRect(x1-o,y2+o, x2+o,height);

	// Darken area between handles
	if(x1+i<x2-i)
	{
		XeeGLRect(x1+i,y1-o,x2-i,y1-2);
		XeeGLRect(x1+i,y2+2,x2-i,y2+o);
	}
	if(y1+i<y2-i)
	{
		XeeGLRect(x1-o,y1+i,x1-2,y2-i);
		XeeGLRect(x2+2,y1+i,x2+o,y2-i);
	}

	// Draw inner edges
	glColor4f(DARK_COL);
	XeeGLHLine(x1-1,y1-1,x2+1);
	XeeGLHLine(x1-1,y2,x2+1);
	XeeGLVLine(x1-1,y1,y2);
	XeeGLVLine(x2,y1,y2);

	// Draw outer edges
	glColor4f(LIGHT_COL);
	XeeGLHLine(x1-2,y1-2,x2+2);
	XeeGLHLine(x1-2,y2+1,x2+2);
	XeeGLVLine(x1-2,y1-1,y2+1);
	XeeGLVLine(x2+1,y1-1,y2+1);

	glEnd();

	for(int n=0;n<4;n++)
	{
		glPushMatrix();

		int cornerarea;
		switch(n)
		{
			case 0: glTranslatef(x1,y1,0); cornerarea=XeeTopLeftArea; break;
			case 1: glTranslatef(x2,y1,0); glRotatef(90,0,0,1); cornerarea=XeeTopRightArea; break;
			case 2: glTranslatef(x2,y2,0); glRotatef(180,0,0,1); cornerarea=XeeBottomRightArea; break;
			case 3: glTranslatef(x1,y2,0); glRotatef(270,0,0,1); cornerarea=XeeBottomLeftArea; break;
		}

		glBegin(GL_QUADS);

		// Draw outer edges of handle
		glColor4f(LIGHT_COL);
		XeeGLVLine(-o,-o,i);
		XeeGLHLine(-o+1,i-1,-2);
		XeeGLHLine(-o+1,-o,i);
		XeeGLVLine(i-1,-o+1,-2);

		// Draw handle highlights
		glColor4f(HIGHLIGHT_COL);
		XeeGLPoint(-o,-o);
		XeeGLPoint(-o,i-1);
		XeeGLPoint(i-1,-o);
		XeeGLPoint(-2,i-1);
		XeeGLPoint(-2,-2);
		XeeGLPoint(i-1,-2);

		// Draw inner edges of handle
		if(cornerarea==area) [selframecol glSet];
		else glColor4f(DARK_COL);
		XeeGLVLine(-o+1,-o+1,i-1);
		XeeGLVLine(-3,-3,i-1);
		XeeGLHLine(-o+2,i-2,-3);

		XeeGLHLine(-o+2,-o+1,i-1);
		XeeGLHLine(-2,-3,i-1);
		XeeGLVLine(i-2,-o+2,-3);

		// Draw highlight
		if(cornerarea==area)
		{
			[selcol glSetWithAlpha:0.5];
			XeeGLRect(-o+2,-o+2,-3,i-2);
			XeeGLRect(-3,-o+2,i-2,-3);
		}

		glEnd();

		glPopMatrix();
	}
}

/*-(void)draw
{
	if(!crop_width) return;

	NSRect crop=XeeTransformRect(
		[view imageToViewTransformMatrix],
		NSMakeRect(crop_x,crop_y,crop_width,crop_height)
	);

	float x1=crop.origin.x;
	float y1=crop.origin.y;
	float x2=x1+crop.size.width;
	float y2=y1+crop.size.height;

	NSSize size=[view bounds].size;
	float width=size.width;
	float height=size.height;

	glDisable(GL_TEXTURE_RECTANGLE_EXT);
	glDisable(GL_TEXTURE_2D);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);

	#define BACK_COL 0,0,0,0.5
	#define DARK_COL 0.67,0.67,0.67,1
	#define LIGHT_COL 0.33,0.33,0.33,1
	#define HIGHLIGHT_COL 0.85,0.85,0.85,1
	//#define LIGHT_COL 0,1,0,0.3
	//#define DARK_COL 1,0,0,0.3

	glBegin(GL_QUADS);

	glColor4f(BACK_COL);

	// Darken area around crop
	XeeGLRect(   0,   0, x1-o,height);
	XeeGLRect(x2+o,   0,width,height);
	XeeGLRect(x1-o,   0, x2+o, y1-o);
	XeeGLRect(x1-o,y2+o, x2+o,height);

	// Darken area between handles
	if(x1+i<x2-i)
	{
		XeeGLRect(x1+i,y1-o,x2-i,y1-2);
		XeeGLRect(x1+i,y2+2,x2-i,y2+o);
	}
	if(y1+i<y2-i)
	{
		XeeGLRect(x1-o,y1+i,x1-2,y2-i);
		XeeGLRect(x2+2,y1+i,x2+o,y2-i);
	}

	// Draw inner edges
	glColor4f(LIGHT_COL);
	XeeGLHLine(x1-1,y1-1,x2+1);
	XeeGLHLine(x1-1,y2,x2+1);
	XeeGLVLine(x1-1,y1,y2);
	XeeGLVLine(x2,y1,y2);

	// Draw outer edges
	glColor4f(DARK_COL);
	if(x1+i<x2-i)
	{
		XeeGLHLine(x1+i,y1-2,x2-i);
		XeeGLHLine(x1+i,y2+1,x2-i);
	}
	if(y1+i<y2-i)
	{
		XeeGLVLine(x1-2,y1+i,y2-i);
		XeeGLVLine(x2+1,y1+i,y2-i);
	}

	glEnd();

	for(int n=0;n<4;n++)
	{
		glPushMatrix();

		int cornerarea;
		switch(n)
		{
			case 0: glTranslatef(x1,y1,0); cornerarea=XeeTopLeftArea; break;
			case 1: glTranslatef(x2,y1,0); glRotatef(90,0,0,1); cornerarea=XeeTopRightArea; break;
			case 2: glTranslatef(x2,y2,0); glRotatef(180,0,0,1); cornerarea=XeeBottomRightArea; break;
			case 3: glTranslatef(x1,y2,0); glRotatef(270,0,0,1); cornerarea=XeeBottomLeftArea; break;
		}

		glBegin(GL_QUADS);

		// Draw inner edges of handle
		glColor4f(LIGHT_COL);
		XeeGLHLine(-1,i-2,-o+1);
		XeeGLVLine(-o+1,i-2,-o+2);
		XeeGLHLine(-o+1,-o+1,i-2);
		XeeGLVLine(i-2,-o+1,-1);

		// Draw handle highlights
		glColor4f(HIGHLIGHT_COL);
		XeeGLPoint(-o+1,i-2);
		XeeGLPoint(-o+1,-o+1);
		XeeGLPoint(i-2,-o+1);
		XeeGLPoint(-1,i-2);
		XeeGLPoint(-1,-1);
		XeeGLPoint(i-2,-1);

		// Draw outer edges of handle
		glColor4f(DARK_COL);
		XeeGLHLine(-1,i-1,-o+1);
		XeeGLVLine(-o,i-1,-o+1);
		XeeGLHLine(-o+1,-o,i-1);
		XeeGLVLine(i-1,-o+1,-1);

		// Darken remaining pixels
		glColor4f(BACK_COL);
		XeeGLPoint(-o,i-1);
		XeeGLPoint(-o,-o);
		XeeGLPoint(i-1,-o);

		// Draw highlight
		if(cornerarea==area)
		{
			[[NSColor alternateSelectedControlColor] glSetWithAlpha:0.5];
			XeeGLRect(-o+2,-o+2,-1,i-2);
			XeeGLRect(-1,-o+2,i-2,-1);
		}

		glEnd();

		glPopMatrix();
	}
}*/

-(NSRect)croppingRect { return NSMakeRect(crop_x,crop_y,crop_width,crop_height); }

@end


static void XeeGLPoint(float x1,float y1)
{
	glVertex2f(x1,y1);
	glVertex2f(x1+1,y1);
	glVertex2f(x1+1,y1+1);
	glVertex2f(x1,y1+1);
}

static void XeeGLHLine(float x1,float y1,float x2)
{
	if(x1>=x2) return;
	glVertex2f(x1,y1);
	glVertex2f(x2,y1);
	glVertex2f(x2,y1+1);
	glVertex2f(x1,y1+1);
}

static void XeeGLVLine(float x1,float y1,float y2)
{
	if(y1>=y2) return;
	glVertex2f(x1,y1);
	glVertex2f(x1+1,y1);
	glVertex2f(x1+1,y2);
	glVertex2f(x1,y2);
}

static void XeeGLRect(float x1,float y1,float x2,float y2)
{
	if(x1>=x2||y1>=y2) return;
	glVertex2f(x1,y1);
	glVertex2f(x2,y1);
	glVertex2f(x2,y2);
	glVertex2f(x1,y2);
}
