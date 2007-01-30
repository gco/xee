#import "XeePropertiesController.h"
#import "XeeController.h"
#import "XeeDelegate.h"
#import "XeeImage.h"
#import "XeeGraphicsStuff.h"


@implementation XeePropertiesController

-(void)awakeFromNib
{
	dataarray=nil;

/*	NSMutableParagraphStyle *sectpara=[[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[sectpara setLineBreakMode:NSLineBreakByTruncatingTail];

	sectionattributes=[[NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont boldSystemFontOfSize:14],NSFontAttributeName,
		sectpara,NSParagraphStyleAttributeName,
	nil] retain];*/

	NSMutableParagraphStyle *labelpara=[[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[labelpara setAlignment:NSRightTextAlignment];
	[labelpara setLineBreakMode:NSLineBreakByTruncatingTail];

	labelattributes=[[NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont boldSystemFontOfSize:12],NSFontAttributeName,
		labelpara,NSParagraphStyleAttributeName,
	nil] retain];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(frontImageDidChange:)
	name:@"XeeFrontImageDidChangeNotification" object:nil];

	[outlineview setDoubleAction:@selector(doubleClick:)];
	[outlineview setTarget:self];

	XeeController *delegate=[maindelegate focusedController];
	if(delegate)
	{
		XeeImage *image=[delegate image];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"XeeFrontImageDidChangeNotification" object:image];
	}
}



-(void)toggleVisibility
{
	if([infopanel isVisible])
	{
		[infopanel orderOut:nil];
	}
	else
	{
		[infopanel orderFront:nil];
		XeeController *delegate=[maindelegate focusedController];
		if(delegate) [self setFullscreenMode:[delegate isFullscreen]];
	}
}

-(BOOL)closeIfOpen
{
	if(![infopanel isVisible]) return NO;
	[infopanel performClose:nil];
	return YES;
}

-(void)setFullscreenMode:(BOOL)fullscreen
{
	if(fullscreen)
	{
		[outlineview setBackgroundColor:[[NSColor whiteColor] colorWithAlphaComponent:0.5]];
		[infopanel setOpaque:NO];
	}
	else
	{
		[outlineview setBackgroundColor:[NSColor whiteColor]];
		[infopanel setOpaque:YES];
	}
}



-(void)frontImageDidChange:(NSNotification *)notification
{
	[dataarray release];
	dataarray=[[[notification object] properties] retain];

	[outlineview reloadData];
	[self restoreCollapsedStatusForArray:dataarray];
}

-(IBAction)doubleClick:(id)sender
{
	id item=[outlineview itemAtRow:[outlineview selectedRow]];

	if([outlineview isItemExpanded:item]) [outlineview collapseItem:item];
	else [outlineview expandItem:item];
}



-(BOOL)outlineView:(NSOutlineView *)view isItemExpandable:(XeePropertyItem *)item
{
	if([item isSubSection]) return YES;
	else return NO;
}

-(int)outlineView:(NSOutlineView *)view numberOfChildrenOfItem:(XeePropertyItem *)item
{
	NSArray *children;
	if(!item) children=dataarray;
	else children=[item value];

	if(!children) return 0;
	return [children count];
}

-(id)outlineView:(NSOutlineView *)view child:(int)index ofItem:(XeePropertyItem *)item
{
	NSArray *children;
	if(!item) children=dataarray;
	else children=[item value];

    return [children objectAtIndex:index];
}

-(id)outlineView:(NSOutlineView *)view objectValueForTableColumn:(NSTableColumn *)col byItem:(XeePropertyItem *)item
{
	NSString *identifier=[col identifier];

	if([item isSubSection])
	{
/*		if([identifier isEqual:@"label"]) return [[[NSAttributedString alloc]
		initWithString:[item label] attributes:sectionattributes] autorelease];
		else return nil;*/
		return nil;
	}
	else
	{
		if([identifier isEqual:@"label"]) return [[[NSAttributedString alloc]
		initWithString:[item label] attributes:labelattributes] autorelease];
		// return [item label];
		else return [item value];
	}
}



-(BOOL)outlineView:(NSOutlineView *)view shouldEditTableColumn:(NSTableColumn *)col item:(XeePropertyItem *)item
{
	return NO;
}

-(float)outlineView:(NSOutlineView *)view heightOfRowByItem:(XeePropertyItem *)item
{
	if([item isSubSection]) return 18;
	else
	{
		return 16;
//		if(![item isEqual:[view itemAtRow:[view selectedRow]]]) return 16;

/*		NSString *text=[[item value] description];
		if(!text) return 16;

		NSTableColumn *col=[view tableColumnWithIdentifier:@"value"];
		id cell=[col dataCell];

		[cell setStringValue:text];
		[cell setLineBreakMode:NSLineBreakByWordWrapping];

		float height=[cell cellSizeForBounds:NSMakeRect(0,0,[col width],1000000)].height;
		if(height<16) return 16;
		if(height>96) return 96;
		return height;*/
	}
}

-(void)outlineViewItemDidCollapse:(NSNotification *)notification
{
	XeePropertyItem *item=[[notification userInfo] objectForKey:@"NSObject"];
	NSString *defname=[NSString stringWithFormat:@"propertyListCollapsed.%@",[item label]];
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:defname];
}

-(void)outlineViewItemDidExpand:(NSNotification *)notification
{
	XeePropertyItem *item=[[notification userInfo] objectForKey:@"NSObject"];
	NSString *defname=[NSString stringWithFormat:@"propertyListCollapsed.%@",[item label]];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:defname];
}

-(NSString *)outlineView:(NSOutlineView *)view toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect
tableColumn:(NSTableColumn *)col item:(XeePropertyItem *)item mouseLocation:(NSPoint)mouse
{
	if([item isSubSection]) return nil;
	if([[col identifier] isEqual:@"label"]) return [item label];
	else return [[item value] description];
}


-(void)restoreCollapsedStatusForArray:(NSArray *)array
{
	NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
	NSEnumerator *enumerator=[array objectEnumerator];
	XeePropertyItem *item;
	while(item=[enumerator nextObject])
	{
		id value=[item value];
		if([value isKindOfClass:[NSArray class]])
		{
			NSString *defname=[NSString stringWithFormat:@"propertyListCollapsed.%@",[item label]];
			if([defaults boolForKey:defname]) [outlineview collapseItem:item];
			else [outlineview expandItem:item];
			[self restoreCollapsedStatusForArray:value];
		}
	}
}

@end



@implementation XeePropertyOutlineView

-(void)drawRow:(int)row clipRect:(NSRect)clip
{
	XeePropertyItem *item=[self itemAtRow:row];
	if([item isSubSection])
	{
		NSRect rect=[self rectOfRow:row];

		NSColor *top,*bottom,*text;

		if([self isRowSelected:row])
		{
			top=[[NSColor alternateSelectedControlColor] blendedColorWithFraction:0.2 ofColor:[NSColor whiteColor]];
			bottom=[[NSColor alternateSelectedControlColor] blendedColorWithFraction:0.2 ofColor:[NSColor blackColor]];
			text=[NSColor alternateSelectedControlTextColor];
		}
		else
		{
/*			unsigned hash=[[item label] hash];
			hash=69069*hash+1327217885;
			hash=69069*hash+1327217885;
			hash=69069*hash+1327217885;
			hash=69069*hash+1327217885;

			float hue=(float)(hash%256)/256.0;

			bottom=[NSColor colorWithCalibratedHue:hue saturation:0.05 brightness:1 alpha:1];
			top=[NSColor colorWithCalibratedHue:hue saturation:0.2 brightness:1 alpha:1];*/
			float alpha=[[self backgroundColor] alphaComponent];
			top=[NSColor colorWithCalibratedWhite:0.95 alpha:alpha];
			bottom=[NSColor colorWithCalibratedWhite:0.8 alpha:alpha];
			text=[NSColor controlTextColor];
		}

		CGShadingRef shading=XeeMakeGradient(top,bottom,
		rect.origin,NSMakePoint(rect.origin.x,rect.origin.y+rect.size.height));

		NSGraphicsContext *context=[NSGraphicsContext currentContext];
		[context saveGraphicsState];

		[context setCompositingOperation:NSCompositeCopy];
		[[NSBezierPath bezierPathWithRect:rect] addClip];
		CGContextDrawShading((CGContextRef)[context graphicsPort],shading);

		[context restoreGraphicsState];

		CFRelease(shading);

		rect.origin.x+=24;
		rect.size.width-=24;
		[[item label] drawInRect:rect withAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
			[NSFont boldSystemFontOfSize:14],NSFontAttributeName,
			text,NSForegroundColorAttributeName,
		nil]];
	}
	[super drawRow:row clipRect:clip];
}

-(NSRect)frameOfCellAtColumn:(int)column row:(int)row
{
	XeePropertyItem *item=[self itemAtRow:row];
	if([item isSubSection])
	{
		return NSZeroRect;
//		if(column!=0) return NSZeroRect;
//		return NSUnionRect([super frameOfCellAtColumn:0 row:row],[super frameOfCellAtColumn:1 row:row]);
	}
	else if(column==0)
	{
		NSRect rect=[super frameOfCellAtColumn:column row:row];
		rect.size.width+=rect.origin.x;
		rect.origin.x=0;
		return rect;
	}
	else return [super frameOfCellAtColumn:column row:row];
}

-(IBAction)copy:(id)sender
{
	int sel=[self selectedRow];
	if(sel<0) { NSBeep(); return; }

	XeePropertyItem *item=[self itemAtRow:sel];
	if(!item||[item isSubSection]) { NSBeep(); return; }

	NSPasteboard *pboard=[NSPasteboard generalPasteboard];
	[pboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType,nil] owner:nil];
	[pboard setString:[NSString stringWithFormat:@"%@ %@",[item label],[item value]]
	forType:NSStringPboardType];
}

@end
