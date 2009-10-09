//
//  XeeTool.m
//  Xee
//
//  Created by Dag Ågren on 2006-12-12.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "XeeTool.h"


@implementation XeeTool

+(XeeTool *)toolForView:(XeeView *)view
{
	return [[[self alloc] initWithView:view] autorelease];
}

-(id)initWithView:(XeeView *)ownerview
{
	if(self=[super init])
	{
		view=ownerview;
		clicking=NO;
	}
	return self;
}

-(void)dealloc
{
	//[view release];
	[super dealloc];
}

-(void)begin {}

-(void)end {}

-(void)mouseDownAt:(NSPoint)position
{
	clicking=YES;
}

-(void)mouseUpAt:(NSPoint)position;
{
	clicking=NO;
}

-(void)mouseDoubleClickedAt:(NSPoint)position
{
	clicking=YES;
}

-(void)mouseMovedTo:(NSPoint)position relative:(NSPoint)relative {}

-(void)mouseDraggedTo:(NSPoint)position relative:(NSPoint)relative {}

-(NSCursor *)cursor { return nil; }

-(void)draw {}

@end
