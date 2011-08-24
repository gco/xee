#import <Cocoa/Cocoa.h>

@class XeeView;

@interface XeeTool:NSObject
{
	XeeView *view;
}

-(id)initWithView:(XeeView *)imageview;

-(void)mouseDownAt:(NSPoint)pos event:(NSEvent *)event;
-(void)mouseUpAt:(NSPoint)pos event:(NSEvent *)event;
-(void)mouseMovedTo:(NSPoint)pos event:(NSEvent *)event;
-(void)mouseDraggedTo:(NSPoint)pos event:(NSEvent *)event;

-(NSCursor *)cursorAt:(NSPoint)pos dragging:(BOOL)dragging;

-(void)drawInRect:(NSRect)imgrect;

@end

@interface XeeMoveTool:XeeTool
{
}

-(void)mouseDraggedTo:(NSPoint)pos event:(NSEvent *)event;
-(NSCursor *)cursorAt:(NSPoint)pos dragging:(BOOL)dragging;

@end

@interface XeeCropTool:XeeTool
{
	int x1,y1,x2,y2;
}

-(id)initWithView:(XeeView *)imageview;

-(void)mouseDownAt:(NSPoint)pos event:(NSEvent *)event;
-(void)mouseUpAt:(NSPoint)pos event:(NSEvent *)event;
-(void)mouseDraggedTo:(NSPoint)pos event:(NSEvent *)event;

-(NSCursor *)cursorAt:(NSPoint)pos dragging:(BOOL)dragging;

-(void)drawInRect:(NSRect)imgrect;

-(NSRect)croppingRect;

@end
