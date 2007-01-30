#import "XeeStatusBar.h"
#import "XeeGraphicsStuff.h"



@implementation XeeStatusBar

-(id)initWithFrame:(NSRect)frame
{
	if(self=[super initWithFrame:frame])
	{
		cells=[[NSMutableArray array] retain];
		shading=XeeMakeGradient(
		[NSColor colorWithCalibratedWhite:0.95 alpha:1],
		[NSColor colorWithCalibratedWhite:0.7 alpha:1],
		NSMakePoint(0,frame.size.height),NSMakePoint(0,0));
	}
	return self;
}

-(void)dealloc
{
	[cells release];
	CGShadingRelease(shading);

	[super dealloc];
}

-(void)drawRect:(NSRect)rect
{
	[super drawRect:rect];

	if([[self window] isMainWindow])
	{
		NSGraphicsContext *context=[NSGraphicsContext currentContext];
		CGContextDrawShading((CGContextRef)[context graphicsPort],shading);
	}

	int borderleft=4;
	int borderright=12;
	int bordertop=2;
	int borderbottom=2;
	int spacing=6;
	int minsize=16;

	NSSize size=[self frame].size;
	NSRect cellrect=NSMakeRect(borderleft,bordertop,0,size.height-bordertop-borderbottom);
	int widthleft=size.width-borderleft-borderright;

	NSEnumerator *enumerator=[cells objectEnumerator];
	NSCell *cell;
	while(cell=[enumerator nextObject])
	{
		NSSize cellsize=[cell cellSize];

		cellrect.size.width=fminf(cellsize.width,widthleft);

		[[NSGraphicsContext currentContext] saveGraphicsState];
		[[NSBezierPath bezierPathWithRect:cellrect] addClip];
		[cell drawWithFrame:cellrect inView:self];
		[[NSGraphicsContext currentContext] restoreGraphicsState];

		cellrect.origin.x+=cellsize.width+spacing;
		widthleft-=cellsize.width+spacing;

		if(widthleft<minsize) break;
	}
}

-(void)addCell:(NSCell *)cell
{
	[cells addObject:cell];
}

-(void)removeAllCells
{
	[cells removeAllObjects];
}

-(void)addEntry:(NSString *)title
{
	if(title)
	[self addCell:[XeeStatusCell statusWithImageNamed:@"" title:title]];
}

-(void)addEntry:(NSString *)title imageNamed:(NSString *)imagename
{
	if(title||imagename)
	[self addCell:[XeeStatusCell statusWithImageNamed:imagename title:title]];
}

-(void)addEntry:(NSString *)title image:(NSImage *)image
{
	if(title||image)
	{
		XeeStatusCell *cell=[XeeStatusCell statusWithImageNamed:@"" title:title];
		[cell setImage:image];
		[self addCell:cell];
	}
}

@end



@implementation XeeStatusCell

static NSDictionary *attributes;

-(id)initWithImage:(NSImage *)image title:(NSString *)title
{
	if(self=[super init])
	{
		[self setImage:image];
		[self setTitle:title];
		//[self setBordered:NO];

		if(!attributes)
		{
			attributes=[[NSDictionary dictionaryWithObjectsAndKeys:
				[NSFont labelFontOfSize:0],NSFontAttributeName,
			nil] retain];
		}

		spacing=2;
	}
	return self;
}

-(void)dealloc
{
	//[attributes release];
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
