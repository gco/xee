#import <Cocoa/Cocoa.h>

@class XeeView;

@interface XeeTool:NSObject
{
	XeeView *view;
	BOOL clicking;
}

+(XeeTool *)toolForView:(XeeView *)ownerview;

-(id)initWithView:(XeeView *)view;
-(void)dealloc;

-(void)begin;
-(void)end;

-(void)mouseDownAt:(NSPoint)position;
-(void)mouseUpAt:(NSPoint)position;
-(void)mouseDoubleClickedAt:(NSPoint)position;
-(void)mouseMovedTo:(NSPoint)position relative:(NSPoint)relative;
-(void)mouseDraggedTo:(NSPoint)position relative:(NSPoint)relative;

-(NSCursor *)cursor;
-(void)draw;

@end
