#import "XeeTool.h"

#define	XeeOutsideArea 0
#define	XeeInsideArea 1
#define XeeTopLeftArea 2
#define	XeeTopRightArea 3
#define	XeeBottomLeftArea 4
#define	XeeBottomRightArea 5
#define XeeTopArea 6
#define	XeeBottomArea 7
#define	XeeLeftArea 8
#define	XeeRightArea 9

#define	XeeNoCropMode 0
#define	XeeResizeCropMode 1
#define	XeeVerticalResizeCropMode 2
#define	XeeHorizontalResizeCropMode 3
#define	XeeMoveCropMode 4

@interface XeeCropTool:XeeTool
{
	float o,i;

	int crop_x,crop_y,crop_width,crop_height;
	int area,mode;
	int start_x,start_y;
	float offs_x,offs_y;
}

-(id)initWithView:(XeeView *)ownerview;
-(void)dealloc;

-(void)mouseDownAt:(NSPoint)position;
-(void)mouseUpAt:(NSPoint)position;
-(void)mouseDoubleClickedAt:(NSPoint)position;
-(void)mouseMovedTo:(NSPoint)position relative:(NSPoint)relative;
-(void)mouseDraggedTo:(NSPoint)position relative:(NSPoint)relative;
-(void)findAreaForPosition:(NSPoint)position;

-(NSCursor *)cursor;
-(void)draw;

-(NSRect)croppingRect;

@end
