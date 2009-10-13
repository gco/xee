#import "XeePropertiesController.h"
#import "XeeController.h"
#import "XeeDelegate.h"
#import "XeeImage.h"
#import "XeeGraphicsStuff.h"

#import <XADMaster/XADRegex.h>



@implementation XeePropertiesController

-(void)awakeFromNib
{
	dataarray=nil;

	NSMutableParagraphStyle *sectpara=[[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[sectpara setAlignment:NSRightTextAlignment];
	[sectpara setLineBreakMode:NSLineBreakByTruncatingTail];

	sectionattributes=[[NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont boldSystemFontOfSize:14],NSFontAttributeName,
		sectpara,NSParagraphStyleAttributeName,
	nil] retain];

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
	if(delegate) [[NSNotificationCenter defaultCenter] postNotificationName:@"XeeFrontImageDidChangeNotification" object:delegate];
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
	dataarray=[[[notification object] currentProperties] retain];

	[outlineview reloadData];
	[self restoreCollapsedStatusForArray:dataarray];
}

-(IBAction)doubleClick:(id)sender
{
	XeePropertyItem *item=[outlineview itemAtRow:[outlineview selectedRow]];
	id value=[item value];

	if([value isKindOfClass:[NSArray class]])
	{
		if([outlineview isItemExpanded:item]) [outlineview collapseItem:item];
		else [outlineview expandItem:item];
	}
	else if([value isKindOfClass:[NSURL class]])
	{
		[[NSWorkspace sharedWorkspace] openURL:value];
	}
	else if([value isKindOfClass:[NSString class]])
	{
		if([value matchedByPattern:@"^http://"])
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:value]];
	}
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

	if([item isSubSection] && [view levelForItem:item]==0)
	{
/*		if([identifier isEqual:@"label"]) return [[[NSAttributedString alloc]
		initWithString:[item label] attributes:sectionattributes] autorelease];
		else return nil;*/
		return nil;
	}
	else
	{
		if([identifier isEqual:@"label"]) return [[[NSAttributedString alloc]
		initWithString:[item label] attributes:[item isSubSection]?sectionattributes:labelattributes] autorelease];
		// return [item label];
		else if(![item isSubSection])
		{
			id value=[item value];
			if([value isKindOfClass:[NSDate class]]) return [value descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M" timeZone:nil locale:nil];
			else return value;
		}
		else return nil;
	}
}



-(BOOL)outlineView:(NSOutlineView *)view shouldEditTableColumn:(NSTableColumn *)col item:(XeePropertyItem *)item
{
	return NO;
}

-(float)outlineView:(NSOutlineView *)view heightOfRowByItem:(XeePropertyItem *)item
{
	if([item isSubSection]) return 18;
//	if([item isSubSection]&&[view levelForItem:item]==0) return 18;
//	else if([item isSubSection]&&[view levelForItem:item]==1) return 24;
	else return 16;
}

-(void)outlineViewItemDidCollapse:(NSNotification *)notification
{
	XeePropertyItem *item=[[notification userInfo] objectForKey:@"NSObject"];
	NSString *defname=[NSString stringWithFormat:@"propertyListCollapsed.%@",[item identifier]];
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:defname];
}

-(void)outlineViewItemDidExpand:(NSNotification *)notification
{
	XeePropertyItem *item=[[notification userInfo] objectForKey:@"NSObject"];
	NSString *defname=[NSString stringWithFormat:@"propertyListCollapsed.%@",[item identifier]];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:defname];

//	id value=[item value];
//	if([value isKindOfClass:[NSArray class]]) [self performSelector:@selector(restoreCollapsedStatusForArray:) withObject:value afterDelay:0];
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
			NSString *defname=[NSString stringWithFormat:@"propertyListCollapsed.%@",[item identifier]];
			if([defaults boolForKey:defname]) [outlineview collapseItem:item];
			else [outlineview expandItem:item];
			[self restoreCollapsedStatusForArray:value];
		}
	}
}

@end



// evil hack

@interface NSOutlineView (EvilHack)
-(NSRect)_frameOfOutlineCellAtRow:(int)row;
@end

@implementation XeePropertyOutlineView

-(id)initWithCoder:(NSCoder *)coder
{
	if(self=[super initWithCoder:coder])
	{
		float alpha=[[self backgroundColor] alphaComponent];

		top_normal=[[NSColor colorWithCalibratedWhite:0.95 alpha:alpha] retain];
		bottom_normal=[[NSColor colorWithCalibratedWhite:0.8 alpha:alpha] retain];
		attrs_normal=[[NSDictionary dictionaryWithObjectsAndKeys:
			[NSFont boldSystemFontOfSize:14],NSFontAttributeName,
			[NSColor controlTextColor],NSForegroundColorAttributeName,
		nil] retain];

		top_selected=[[[NSColor alternateSelectedControlColor] blendedColorWithFraction:0.2 ofColor:[NSColor whiteColor]] retain];
		bottom_selected=[[[NSColor alternateSelectedControlColor] blendedColorWithFraction:0.2 ofColor:[NSColor blackColor]] retain];
		attrs_selected=[[NSDictionary dictionaryWithObjectsAndKeys:
			[NSFont boldSystemFontOfSize:14],NSFontAttributeName,
			[NSColor alternateSelectedControlTextColor],NSForegroundColorAttributeName,
		nil] retain];

		[self setAutoresizesOutlineColumn:NO];
	}
	return self;
}

-(void)dealloc
{
	[top_normal release];
	[bottom_normal release];
	[attrs_normal release];
	[top_selected release];
	[bottom_selected release];
	[attrs_selected release];
	[super dealloc];
}

-(void)drawRow:(int)row clipRect:(NSRect)clip
{
	XeePropertyItem *item=[self itemAtRow:row];
	if([item isSubSection] && [self levelForRow:row]==0)
	{
		NSRect rect=[self rectOfRow:row];

		NSColor *top,*bottom;
		NSDictionary *attrs;

		if([self isRowSelected:row])
		{
			top=top_selected;
			bottom=bottom_selected;
			attrs=attrs_selected;
		}
		else
		{
			top=top_normal;
			bottom=bottom_normal;
			attrs=attrs_normal;
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
		[[item label] drawInRect:rect withAttributes:attrs];
	}
	[super drawRow:row clipRect:clip];
}

-(NSRect)frameOfCellAtColumn:(int)column row:(int)row
{
	XeePropertyItem *item=[self itemAtRow:row];

	//if(column<0) return [super frameOfCellAtColumn:-column-1 row:row];
	if([item isSubSection] && [self levelForRow:row]==0)
	{
		return NSZeroRect;
	}
	else if(column==0 && ![item isSubSection])
	{
		NSRect rect=[super frameOfCellAtColumn:column row:row];
		rect.size.width+=rect.origin.x;
		rect.origin.x=0;
		return rect;
	}
	else return [super frameOfCellAtColumn:column row:row];
}

/*-(NSRect)_frameOfOutlineCellAtRow:(int)row;
{
	if([self levelForRow:row]==0)
	{
//		return [super _frameOfOutlineCellAtRow:row];
	NSRect rect=[self frameOfCellAtColumn:-1 row:row];
	rect.size.width=24;
	return rect;
	}
	else
	{
		NSRect rect=[self frameOfCellAtColumn:-2 row:row];
		rect.size.width=24;
		return rect;
	}
//	return [super _frameOfOutlineCellAtRow:row];
}*/

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
