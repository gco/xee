#import "XeeDestinationList.h"
#import "XeeController.h"
#import "XeeDelegate.h"
#import "XeeGraphicsStuff.h"
#import "CSKeyboardShortcuts.h"

#import <Carbon/Carbon.h>



void XeePlayPoof(NSWindow *somewindow);



@implementation XeeDestinationView

-(void)dealloc
{
	[super dealloc];
}

-(void)awakeFromNib
{
	destinations=[XeeDestinationView defaultArray];
	droprow=dropnum=0;
	movemode=NO;
	surpressshortcut=NO;

	[self setDataSource:self];
	[self setDelegate:self];
    [self registerForDraggedTypes:[NSArray arrayWithObjects:@"XeeDestinationPath",NSFilenamesPboardType,nil]];

	[self setDoubleAction:@selector(destinationListClick:)];

	[self setMatchAlgorithm:KFSubstringMatchAlgorithm];
	[self setSearchColumnIdentifiers:[NSSet setWithObject:@"filename"]];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateData:) name:@"XeeDestinationUpdate" object:nil];
}

-(id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(int)row
{
	NSString *ident=[column identifier];

	if(row==0)
	{
		if([ident isEqual:@"filename"]) return NSLocalizedString(@"Choose a folder...",@"Destination list entry for picking a new folder");
		else return nil;
	}
	else
	{
		if([ident isEqual:@"shortcut"]) return [self shortcutForRow:row];
		else
		{
			int index=[self indexForRow:row];
			if(index<0) return nil;
			NSMutableDictionary *dict=[destinations objectAtIndex:index];
			return [dict objectForKey:ident];
		}
	}
}

-(int)numberOfRowsInTableView:(NSTableView *)table
{
	return [destinations count]+1+dropnum;
}



-(void)drawRow:(int)row clipRect:(NSRect)clipRect
{
	int index=[self indexForRow:row];

	if(index>=0&&![self isRowSelected:row])
	{
		NSColor *col=[[destinations objectAtIndex:index] objectForKey:@"color"];

		if(col)
		{
			[col set];
			XeeDrawRoundedBar([self rectOfRow:row]);
		}
	}

	if(row>=droprow&&row<droprow+dropnum)
	{
//		[[[NSColor blueColor] colorWithAlphaComponent:0.2] set];
		[[NSColor colorWithDeviceWhite:0 alpha:0.2] set];
		XeeDrawRoundedBar([self rectOfRow:row]);
	}

	[super drawRow:row clipRect:clipRect];
}

-(NSRect)frameOfCellAtColumn:(int)column row:(int)row
{
	NSRect rect=[self rectOfRow:row];
	rect.size.height-=1;

	if(column==0)
	{
		rect.origin.x+=2;
		rect.origin.y+=1;
		rect.size.width=rect.size.height=16;
		return rect;
	}
	else if(column==1)
	{
		rect.size.width-=20;
		rect.origin.x+=20;

		NSString *shortcut=[self shortcutForRow:row];
		if(shortcut&&!surpressshortcut)
		{
			NSFont *font=[[[self tableColumnWithIdentifier:@"shortcut"] dataCell] font];
			NSDictionary *attrs=[NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName];
			NSSize size=[shortcut sizeWithAttributes:attrs];
			rect.size.width-=size.width+2;
		}

		if(rect.size.width<0) return NSZeroRect;
		else return rect;
	}
	else if(column==2)
	{
		NSString *shortcut=[self shortcutForRow:row];
		if(shortcut&&!surpressshortcut)
		{
			NSFont *font=[[[self tableColumnWithIdentifier:@"shortcut"] dataCell] font];
			NSDictionary *attrs=[NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName];
			NSSize size=[shortcut sizeWithAttributes:attrs];

			rect.origin.x+=rect.size.width-size.width-4;
			rect.origin.y+=2;
			rect.size.width=size.width+4;
			rect.size.height-=2;
			return rect;
		}
		else return NSZeroRect;
	}
	return NSZeroRect;
}




-(void)keyDown:(NSEvent *)event
{
	unichar c=[[event characters] characterAtIndex:0];

	if(c==13||c==3) [[NSApplication sharedApplication] sendAction:@selector(destinationListClick:) to:nil from:self];
	else [super keyDown:event];
}

-(NSMenu*)menuForEvent:(NSEvent *)event
{
	NSPoint clickpoint=[self convertPoint:[event locationInWindow] fromView:nil];
	[self selectRowIndexes:[NSIndexSet indexSetWithIndex:[self rowAtPoint:clickpoint]] byExtendingSelection:NO];

	return [super menuForEvent:event];
}



-(void)mouseDown:(NSEvent *)event
{
	NSPoint clickpoint=[self convertPoint:[event locationInWindow] fromView:nil];
	int row=[self rowAtPoint:clickpoint];
	int index=[self indexForRow:row];

//	if(row>=0) [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

	if(index>=0)
	{
		NSEvent *newevent=[[self window] nextEventMatchingMask:(NSLeftMouseDraggedMask|NSLeftMouseUpMask)
		untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:NO];

		if(newevent&&[newevent type]==NSLeftMouseDragged)
		{
			NSMutableDictionary *dict=[[destinations objectAtIndex:index] retain];
			NSPasteboard *pboard=[NSPasteboard pasteboardWithName:NSDragPboard];
			[pboard declareTypes:[NSArray arrayWithObject:@"XeeDestinationPath"] owner:self];
			[pboard setString:[dict objectForKey:@"path"] forType:@"XeeDestinationPath"];

			NSPoint newpoint=[self convertPoint:[newevent locationInWindow] fromView:nil];
			NSRect rowrect=[self rectOfRow:row];

			if([self selectedRow]==row) [self deselectAll:self];

			NSImage *dragimage=[[[NSImage alloc] initWithSize:rowrect.size] autorelease];

			[dragimage lockFocus];
			[[dict objectForKey:@"icon"] setFlipped:YES];
			NSAffineTransform *trans=[NSAffineTransform transform];
			[trans translateXBy:-rowrect.origin.x yBy:-rowrect.origin.y];
			[trans set];
			surpressshortcut=YES;
			[self drawRow:row clipRect:rowrect];
			surpressshortcut=NO;
			[dragimage unlockFocus];

			NSPoint imgpoint=rowrect.origin;
			imgpoint.y+=rowrect.size.height;

			[destinations removeObjectAtIndex:index];
			droprow=row;
			dropnum=1;

			[[NSCursor arrowCursor] push];

			[self dragImage:dragimage at:imgpoint
			offset:NSMakeSize(newpoint.x-clickpoint.x,newpoint.y-clickpoint.y)
			event:event pasteboard:pboard source:self slideBack:NO];

			[NSCursor pop];
			[dict release];

			return;
		}
	}
	[super mouseDown:event];
}


-(unsigned int)draggingSourceOperationMaskForLocal:(BOOL)local
{
	return NSDragOperationMove|NSDragOperationDelete;
}

-(void)draggedImage:(NSImage *)image endedAt:(NSPoint)point operation:(NSDragOperation)operation
{
	if(operation!=NSDragOperationMove) XeePlayPoof([self window]);

	[XeeDestinationView saveArray];
}

-(NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard=[sender draggingPasteboard];
	int row=[self rowForDropPoint:[self convertPoint:[sender draggingLocation] fromView:nil]];

	if([[pboard types] containsObject:NSFilenamesPboardType])
	{
		NSArray *files=[pboard propertyListForType:NSFilenamesPboardType];

		NSEnumerator *enumerator=[files objectEnumerator];
		NSString *file;
		while(file=[enumerator nextObject])
		{
			FSRef ref;
			if(CFURLGetFSRef((CFURLRef)[NSURL fileURLWithPath:file],&ref))
			{
				Boolean folder,aliased;
				if(!FSResolveAliasFileWithMountFlags(&ref,TRUE,&folder,&aliased,kResolveAliasFileNoUI))
				{
					if(!folder) return NSDragOperationNone;
				}
			}
		}
		[self setDropRow:row num:[files count]];
	}
	else
	{
		[self setDropRow:row num:1];
	}

	if([[pboard types] containsObject:@"XeeDestinationPath"]) [[NSCursor arrowCursor] set];

	return NSDragOperationMove;
}

-(NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
	if(!dropnum) return NSDragOperationNone;

	[self setDropRow:[self rowForDropPoint:[self convertPoint:[sender draggingLocation] fromView:nil]]];
	[self reloadData];
	return NSDragOperationMove;
}

-(void)draggingExited:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard=[sender draggingPasteboard];

	[self setDropRow:0 num:0];

	if([[pboard types] containsObject:@"XeeDestinationPath"]) SetThemeCursor(kThemePoofCursor);

	[self reloadData];
}

-(BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	if(!dropnum) return NO;

	int row=droprow;
	droprow=0;
	dropnum=0;

	NSPasteboard *pboard=[sender draggingPasteboard];
	int insindex=row-1;

	NSArray *files;
	if([[pboard types] containsObject:NSFilenamesPboardType]) files=[pboard propertyListForType:NSFilenamesPboardType];
	else files=[NSArray arrayWithObject:[pboard stringForType:@"XeeDestinationPath"]];

	NSEnumerator *enumerator=[files objectEnumerator];
	NSString *file;
	while(file=[enumerator nextObject])
	{
		int remindex=[XeeDestinationView findDestination:file];
		if(remindex!=NSNotFound)
		{
			[destinations removeObjectAtIndex:remindex];
			if(remindex<insindex) insindex--;
		}
	}

	[XeeDestinationView addDestinations:files index:insindex];
	[XeeDestinationView saveArray];
	[XeeDestinationView updateTables];

    return YES;
}

-(int)rowForDropPoint:(NSPoint)point
{
	int row=[self rowAtPoint:point];

	if(row==0) return 1;
	else if(row<0||row>[destinations count]) return [destinations count]+1;
	else return row;
}

-(void)setDropRow:(int)row num:(int)num
{
	int sel=[self selectedRow];

	if(sel>=0)
	{
		if(sel>=droprow+dropnum) sel-=dropnum;
		if(sel>=row) sel+=num;
	}

	droprow=row;
	dropnum=num;

	if(sel>=0) [self selectRowIndexes:[NSIndexSet indexSetWithIndex:sel] byExtendingSelection:NO];
}

-(void)setDropRow:(int)row
{
	[self setDropRow:row num:dropnum];
}

-(void)updateData:(id)notification
{
	[self reloadData];
}


-(IBAction)switchMode:(id)sender
{
	if([sender selectedSegment]==1) movemode=YES;
	else movemode=NO;
	[self reloadData];
}

-(IBAction)openInXee:(id)sender
{
	int index=[self indexForRow:[self selectedRow]];
	if(index<0) return;

	NSString *filename=[[destinations objectAtIndex:index] objectForKey:@"path"];
	[[NSApp delegate] application:NSApp openFile:filename];
}

-(IBAction)openInFinder:(id)sender
{
	int index=[self indexForRow:[self selectedRow]];
	if(index<0) return;

	NSString *filename=[[destinations objectAtIndex:index] objectForKey:@"path"];
	[[NSWorkspace sharedWorkspace] openFile:filename];
}

-(IBAction)removeFromList:(id)sender
{
	int index=[self indexForRow:[self selectedRow]];
	if(index<0) return;

	[destinations removeObjectAtIndex:index];
	[XeeDestinationView updateTables];
	[XeeDestinationView saveArray];
}

-(void)menuNeedsUpdate:(NSMenu *)menu
{
	BOOL enabled=[self selectedRow]==0?NO:YES;
	int count=[menu numberOfItems];

	for(int i=0;i<count;i++) [[menu itemAtIndex:i] setEnabled:enabled];
}



-(int)indexForRow:(int)row
{
	if(row<1) return -1;

	int index;
	if(row>=droprow+dropnum) index=row-dropnum-1;
	else if(row>=droprow) return -1;
	else index=row-1;

	if(index>=[destinations count]) return -1;
	return index;
}

-(NSString *)pathForRow:(int)row
{
	int index=[self indexForRow:row];
	if(index<0) return nil;
	return [[destinations objectAtIndex:index] objectForKey:@"path"];
}

-(NSString *)shortcutForRow:(int)row
{
	if(row==0||row>10) return nil;
	if(row>=droprow&&row<droprow+dropnum) return nil;
	if(row>[destinations count]) return nil;

	CSAction **actions=[maindelegate copyAndMoveActions];
	int index=movemode?row+9:row-1;
	NSArray *shortcuts=[actions[index] shortcuts];
	if([shortcuts count]) return [[shortcuts objectAtIndex:0] description];
	else return nil;
}



+(void)updateTables
{
	[[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:@"XeeDestinationUpdate" object:nil]];
}

+(void)suggestInsertion:(NSString *)directory
{
	if([self findDestination:directory]==NSNotFound)
	[self addDestinations:[NSArray arrayWithObject:directory] index:[[self defaultArray] count]];

	[self updateTables];
	[self saveArray];
}

+(void)addDestinations:(NSArray *)directories index:(int)index
{
	NSMutableArray *destinations=[self defaultArray];
	NSEnumerator *enumerator=[directories reverseObjectEnumerator];
	NSString *directory;
	while(directory=[enumerator nextObject])
	{
		NSString *dirname=[directory lastPathComponent];
		NSImage *icon=[[NSWorkspace sharedWorkspace] iconForFile:directory];
		NSColor *color=[NSColor clearColor];

		NSURL *url=[NSURL fileURLWithPath:directory];

		FSRef fsref;
		FSSpec fsspec;
		CFURLGetFSRef((CFURLRef)url,&fsref);
		FSGetCatalogInfo(&fsref,kFSCatInfoNone,NULL,NULL,&fsspec,NULL);

		IconRef dummyicon;
		SInt16 label;
		RGBColor rgbcol;
		Str255 labelstr;
		if(GetIconRefFromFile(&fsspec,&dummyicon,&label)==noErr)
		{
			ReleaseIconRef(dummyicon);

			if(label)
			if(GetLabel(label,&rgbcol,labelstr)==noErr)
			{
				color=[NSColor colorWithCalibratedRed:rgbcol.red/65280.0 green:rgbcol.green/65280.0 blue:rgbcol.blue/65280.0 alpha:0.2];
			}
		}

		NSDictionary *dict=[NSDictionary dictionaryWithObjectsAndKeys:
		directory,@"path",dirname,@"filename",icon,@"icon",color,@"color",nil];

		if(index<[destinations count]) [destinations insertObject:dict atIndex:index];
		else [destinations addObject:dict];
	}
}

+(int)findDestination:(NSString *)directory
{
	NSMutableArray *destinations=[self defaultArray];

	int count=[destinations count];
	for(int i=0;i<count;i++) if([[[destinations objectAtIndex:i] objectForKey:@"path"] isEqual:directory]) return i;

	return NSNotFound;
}

+(void)loadArray
{
	NSArray *destarray=[[NSUserDefaults standardUserDefaults] objectForKey:@"destinations"];
	[self addDestinations:destarray index:0];
}

+(void)saveArray
{
	NSMutableArray *destinations=[self defaultArray];
	NSMutableArray *array=[NSMutableArray arrayWithCapacity:[destinations count]];

	NSEnumerator *enumerator=[destinations objectEnumerator];
	NSDictionary *destination;
	while(destination=[enumerator nextObject]) [array addObject:[destination objectForKey:@"path"]];

	[[NSUserDefaults standardUserDefaults] setObject:array forKey:@"destinations"];
}

+(NSMutableArray *)defaultArray
{
	static NSMutableArray *def=nil;
	if(!def)
	{
		def=[[NSMutableArray array] retain];
		[self loadArray];
	}

	return def;
}

@end



void XeePlayPoof(NSWindow *somewindow)
{
/*	[[[[NSSound alloc] initWithContentsOfFile:@"/System/Library/Components/CoreAudio.component/Contents/Resources/SystemSounds/dock/poof item off dock.aif"
	byReference:NO] autorelease] play];*/

	NSShowAnimationEffect(NSAnimationEffectDisappearingItemDefault,
	[somewindow convertBaseToScreen:[somewindow mouseLocationOutsideOfEventStream]],
	NSZeroSize,nil,nil,nil);
}
