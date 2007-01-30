#import "XeeMoveTool.h"
#import "XeeView.h"

@implementation XeeMoveTool

-(void)mouseDraggedTo:(NSPoint)position relative:(NSPoint)relative;
{
	NSPoint focus=[view focus];
	focus.x-=relative.x;
	focus.y-=relative.y;
	[view setFocus:focus];
}

-(NSCursor *)cursor
{
	if(clicking) return [NSCursor closedHandCursor];
	else return [NSCursor openHandCursor];
}

@end
