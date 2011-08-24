#import "XeeStatusBar.h"



@implementation XeeStatusBar

-(id)initWithFrame:(NSRect)frame
{
	if(self=[super initWithFrame:frame])
	{
		elements=[[NSMutableArray alloc] initWithCapacity:4];
	}
	return self;
}

-(void)dealloc
{
	[elements release];

	[super dealloc];
}

static int sorter(id el1,id el2,void *context)
{
	float v1=[[el1 objectForKey:@"priority"] floatValue];
	float v2=[[el2 objectForKey:@"priority"] floatValue];
	if(v1<v2) return NSOrderedDescending;
	else if(v1>v2) return NSOrderedAscending;
	else return NSOrderedSame;
}

-(void)drawRect:(NSRect)rect
{
	[super drawRect:rect];

	//NSDrawLightBezel([self frame],rect);

	int borderleft=4;
	int borderright=0;
	int bordertop=2;
	int borderbottom=2;
	int spacing=6;
	int minsize=16;

	NSSize size=[self frame].size;

	NSEnumerator *enumerator;
	NSMutableDictionary *el;
	NSArray *sorted=[elements sortedArrayUsingFunction:sorter context:nil];
	int widthleft=size.width-borderleft-borderright;

	enumerator=[sorted objectEnumerator];

	while(el=[enumerator nextObject])
	{
		NSSize cellsize=[[el objectForKey:@"cell"] cellSize];

		if([[el objectForKey:@"hidden"] boolValue]||widthleft==0)
		{
			[el setObject:[NSNumber numberWithInt:0] forKey:@"width"];
		}
		else if(cellsize.width>widthleft)
		{
			if(widthleft>=minsize) [el setObject:[NSNumber numberWithInt:widthleft] forKey:@"width"];
			else [el setObject:[NSNumber numberWithInt:0] forKey:@"width"];
			widthleft=0;
		}
		else if(widthleft)
		{
			[el setObject:[NSNumber numberWithInt:cellsize.width] forKey:@"width"];
			widthleft-=cellsize.width+spacing;
		}
	}

	NSRect cellrect=NSMakeRect(borderleft,bordertop,0,size.height-bordertop-borderbottom);

	enumerator=[elements objectEnumerator];

	while(el=[enumerator nextObject])
	{
		int width=[[el objectForKey:@"width"] intValue];

		if(width>0)
		{
			cellrect.size.width=width;
			[(NSCell *)[el objectForKey:@"cell"] drawWithFrame:cellrect inView:self];
			cellrect.origin.x+=width+spacing;
		}
	}
}

-(void)addCell:(NSCell *)cell priority:(float)priority
{
	[elements addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
	cell,@"cell",[NSNumber numberWithFloat:priority],@"priority",
	[NSNumber numberWithBool:NO],@"hidden",nil]];
}

-(void)setPriority:(float)priority atIndex:(int)index
{
	[[elements objectAtIndex:index] setObject:[NSNumber numberWithFloat:priority] forKey:@"priority"];
}

-(void)setPriority:(float)priority forCell:(NSCell *)cell
{
	[self setPriority:priority atIndex:[self indexOfCell:cell]];
}

-(void)setHidden:(BOOL)hidden atIndex:(int)index
{
	[[elements objectAtIndex:index] setObject:[NSNumber numberWithBool:hidden] forKey:@"hidden"];
}

-(void)setHidden:(BOOL)hidden forCell:(NSCell *)cell
{
	[self setHidden:hidden atIndex:[self indexOfCell:cell]];
}

-(void)setHiddenFrom:(int)start to:(int)end values:(BOOL)hidden,...
{
	va_list va;
	va_start(va,hidden);

	for(int i=start;i<=end;i++)
	{
		[[elements objectAtIndex:i] setObject:[NSNumber numberWithBool:hidden] forKey:@"hidden"];
		hidden=va_arg(va,int);
	}

	va_end(va);
}

-(int)indexOfCell:(NSCell *)cell
{
	for(int i=0;i<[elements count];i++)
	{
		if([[elements objectAtIndex:i] objectForKey:@"cell"]==cell) return i;
	}

	return NSNotFound;
}

@end



@implementation XeeStatusCell

-(id)initWithImage:(NSImage *)image title:(NSString *)title
{
	if(self=[super init])
	{
		[self setImage:image];
		[self setTitle:title];
		//[self setBordered:NO];

		attributes=[[NSDictionary dictionaryWithObjectsAndKeys:[NSFont labelFontOfSize:0],NSFontAttributeName,nil] retain];
		spacing=2;
	}
	return self;
}

-(void)dealloc
{
	[attributes release];
	[titlestring release];
	[super dealloc];
}

-(void)setTitle:(NSString *)title { [titlestring autorelease]; titlestring=[title retain]; }

-(NSString *)title { return titlestring; }

-(NSSize)cellSize
{
	NSImage *image=[self image];
	NSString *title=[self title];
	NSSize imagesize=[image size];
	NSSize textsize=[title sizeWithAttributes:attributes];

	if(image)
	{
		return NSMakeSize(imagesize.width+spacing+textsize.width,MAX(imagesize.height,textsize.height));
	}
	else
	{
		return textsize;
	}
}

-(void)drawInteriorWithFrame:(NSRect)frame inView:(NSView *)view
{
	NSImage *image=[self image];
	NSString *title=[self title];
	NSSize imagesize=[image size];
	NSSize textsize=[title sizeWithAttributes:attributes];

	if(image)
	{
		[image compositeToPoint:NSMakePoint(frame.origin.x,frame.origin.y+(frame.size.height-imagesize.height)/2) operation:NSCompositeSourceOver];
		[title drawAtPoint:NSMakePoint(frame.origin.x+imagesize.width+spacing,frame.origin.y+(frame.size.height-textsize.height)/2) withAttributes:attributes];
	}
	else
	{
		[title drawAtPoint:NSMakePoint(frame.origin.x,frame.origin.y+(frame.size.height-textsize.height)/2) withAttributes:attributes];
	}
}

+(XeeStatusCell *)statusWithImageNamed:(NSString *)name title:(NSString *)title
{
	return [[[XeeStatusCell alloc] initWithImage:[NSImage imageNamed:name] title:title] autorelease];
}

@end