#import "XeeMisc.h"
#import "XeeImage.h"
#import "XeeView.h"
#import "XeeDirectoryController.h"

#import <sys/time.h>



void XeePlayPoof(NSWindow *somewindow)
{
/*	[[[[NSSound alloc] initWithContentsOfFile:@"/System/Library/Components/CoreAudio.component/Contents/Resources/SystemSounds/dock/poof item off dock.aif"
	byReference:NO] autorelease] play];*/

	NSShowAnimationEffect(NSAnimationEffectDisappearingItemDefault,
	[somewindow convertBaseToScreen:[somewindow mouseLocationOutsideOfEventStream]],
	NSZeroSize,nil,nil,nil);
}

double XeeGetTime()
{
	struct timeval tv;
	gettimeofday(&tv,0);
	return (double)tv.tv_sec+(double)tv.tv_usec/1000000.0;
}




@implementation XeeCollisionPanel

-(void)run:(NSWindow *)window source:(XeeImage *)src destination:(XeeImage *)dest mode:(int)mode;
{
	srcimage=[src retain];
	destimage=[dest retain];
	transfermode=mode;

//	NSImage *iconimage=[[NSWorkspace sharedWorkspace] iconForFile:[destimage filename]];
//	[iconimage setSize:NSMakeSize(128,128)];
//	[icon setImage:iconimage];

	float horiz_zoom=128/(float)[destimage width];
	float vert_zoom=128/(float)[destimage height];
	float min_zoom=horiz_zoom<vert_zoom?horiz_zoom:vert_zoom;
	float zoom;

	if(min_zoom<1) zoom=min_zoom;
	else zoom=1;

	[icon setImage:destimage];
	[icon setImageSize:NSMakeSize(zoom*(float)[destimage width],zoom*(float)[destimage height])];

	[NSThread detachNewThreadSelector:@selector(loadThumbnail:) toTarget:self withObject:destimage];

	[titlefield setStringValue:[NSString stringWithFormat:NSLocalizedString(@"The file \"%@\" already exists.",
	@"Title of the file exists dialog"),[[destimage filename] lastPathComponent]]];

	[oldsize setStringValue:[NSString stringWithFormat:@"%qu",[destimage fileSize]]];
	[newsize setStringValue:[NSString stringWithFormat:@"%qu",[srcimage fileSize]]];

	[oldformat setStringValue:[NSString stringWithFormat:@"%dx%d\n%@ %@",
	[destimage width],[destimage height],[destimage depth],[destimage format]]];
	[newformat setStringValue:[NSString stringWithFormat:@"%dx%d\n%@ %@",
	[srcimage width],[srcimage height],[srcimage depth],[srcimage format]]];

	[olddate setStringValue:[destimage descriptiveDate]];
	[newdate setStringValue:[srcimage descriptiveDate]];

	NSString *newname;
	NSString *destdir=[[destimage filename] stringByDeletingLastPathComponent];
	NSString *destname=[[[destimage filename] lastPathComponent] stringByDeletingPathExtension];
	NSString *destext=[[destimage filename] pathExtension];
	int n=1;

	do { newname=[destdir stringByAppendingPathComponent:[[NSString stringWithFormat:@"%@-%d",destname,n++] stringByAppendingPathExtension:destext]]; }
	while([[NSFileManager defaultManager] fileExistsAtPath:newname]);

	[namefield setStringValue:[newname lastPathComponent]];
	[self makeFirstResponder:namefield];
	[[namefield currentEditor] setSelectedRange:NSMakeRange(0,[[[namefield stringValue] stringByDeletingPathExtension] length])];

	[replacebutton setKeyEquivalent:@"\r"];
	[renamebutton setKeyEquivalent:@""];

	[[NSApplication sharedApplication] beginSheet:self modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

-(void)loadThumbnail:(XeeImage *)image
{
	NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

	[image retain];
	[NSThread setThreadPriority:0.1];
	[image runLoaderForThumbnail];
	[image release];

	[pool release];
}

-(void)cancelClick:(id)sender
{
	[[NSApplication sharedApplication] endSheet:self];
	[self orderOut:nil];

	[destimage setAnimating:NO];
	[destimage setDelegate:nil];

	[srcimage release];
	[destimage release];
	[icon setImage:nil];
}

-(void)renameClick:(id)sender
{
	[[NSApplication sharedApplication] endSheet:self];
	[self orderOut:nil];

	NSString *destination=[[[destimage filename] stringByDeletingLastPathComponent] stringByAppendingPathComponent:[namefield stringValue]];
	[controller attemptToTransferFile:[srcimage filename] to:destination mode:transfermode];

	[destimage setAnimating:NO];
	[destimage setDelegate:nil];

	[srcimage release];
	[destimage release];
	[icon setImage:nil];
}

-(void)replaceClick:(id)sender
{
	[[NSApplication sharedApplication] endSheet:self];
	[self orderOut:nil];

	[controller transferFile:[srcimage filename] to:[destimage filename] mode:transfermode];

	[destimage setAnimating:NO];
	[destimage setDelegate:nil];

	[srcimage release];
	[destimage release];
	[icon setImage:nil];
}

-(void)controlTextDidChange:(NSNotification *)notification
{
	[replacebutton setKeyEquivalent:@""];
	[renamebutton setKeyEquivalent:@"\r"];
}

@end



@implementation XeeRenamePanel

-(void)run:(NSWindow *)window image:(XeeImage *)img
{
	image=[img retain];

	NSString *filename=[[image filename] lastPathComponent];
	[namefield setStringValue:filename];

	if(window)
	{
		sheet=YES;
		[[NSApplication sharedApplication] beginSheet:self modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
	}
	else
	{
		sheet=NO;
		[self makeKeyAndOrderFront:nil];
	}

	[self makeFirstResponder:namefield];
	[[namefield currentEditor] setSelectedRange:NSMakeRange(0,[[filename stringByDeletingPathExtension] length])];
}

-(void)cancelClick:(id)sender
{
	if(sheet) [[NSApplication sharedApplication] endSheet:self];
	[self orderOut:nil];

	[image release];
}

-(void)renameClick:(id)sender
{
	if(sheet) [[NSApplication sharedApplication] endSheet:self];
	[self orderOut:nil];

	NSString *newname=[[[image filename] stringByDeletingLastPathComponent] stringByAppendingPathComponent:[namefield stringValue]];
	[controller renameFile:[image filename] to:newname];

	[image release];
}

@end



@implementation XeeFiletypeListSource:NSObject

-(id)init
{
	if(self=[super init])
	{
		filetypes=nil;
	}
	return self;
}

-(void)dealloc
{
	[filetypes release];
	[super dealloc];
}

-(void)awakeFromNib
{
	NSMutableArray *array=[NSMutableArray array];
	NSArray *types=[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDocumentTypes"];
	NSEnumerator *enumerator=[types objectEnumerator];
	NSDictionary *dict;

	while(dict=[enumerator nextObject])
	{
		NSArray *types=[dict objectForKey:@"LSItemContentTypes"];
		if(types)
		{
			NSString *description=[dict objectForKey:@"CFBundleTypeName"];
			NSString *extensions=[[dict objectForKey:@"CFBundleTypeExtensions"] componentsJoinedByString:@", "];
			NSString *type=[types objectAtIndex:0];
			[array addObject:[NSDictionary dictionaryWithObjectsAndKeys:
				type,@"type",
				description,@"description",
				extensions,@"extensions",
			0]];
		}
	}

	filetypes=[[NSArray alloc] initWithArray:array];
}

-(int)numberOfRowsInTableView:(NSTableView *)table
{
	return [filetypes count];
}

-(id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(int)row
{
	NSString *ident=[column identifier];

	if([ident isEqual:@"enabled"])
	{
		NSString *type=[[filetypes objectAtIndex:row] objectForKey:@"type"];
		NSString *handler=[(id)LSCopyDefaultRoleHandlerForContentType((CFStringRef)type,kLSRolesViewer) autorelease];
		return [NSNumber numberWithBool:[@"cx.c3.xee" isEqual:handler]];
	}
	else
	{
		return [[filetypes objectAtIndex:row] objectForKey:ident];
	}
}

-(void)tableView:(NSTableView *)table setObjectValue:(id)object forTableColumn:(NSTableColumn *)column row:(int)row
{
	NSString *ident=[column identifier];

	if([ident isEqual:@"enabled"])
	{
		NSString *type=[[filetypes objectAtIndex:row] objectForKey:@"type"];

		if([object boolValue])
		{
			NSString *oldhandler=[(id)LSCopyDefaultRoleHandlerForContentType((CFStringRef)type,kLSRolesViewer) autorelease];

			if(oldhandler)
			[[NSUserDefaults standardUserDefaults] setObject:oldhandler forKey:[@"oldHandler." stringByAppendingString:type]];

			LSSetDefaultRoleHandlerForContentType((CFStringRef)type,kLSRolesViewer,(CFStringRef)@"cx.c3.xee");
		}
		else
		{
			NSArray *array=[(id)LSCopyAllRoleHandlersForContentType((CFStringRef)type,kLSRolesViewer|kLSRolesEditor) autorelease];
			NSString *handler=nil;

			NSString *defhandler=[[NSUserDefaults standardUserDefaults] stringForKey:[@"oldHandler." stringByAppendingString:type]];
			if(!defhandler) defhandler=@"com.apple.Preview";

			if([array containsObject:defhandler]) handler=defhandler;
			else if(![[array objectAtIndex:0] isEqual:@"cx.c3.xee"]) handler=[array objectAtIndex:0];
			else if([array count]>1)  handler=[array objectAtIndex:1];
			else NSBeep();

			LSSetDefaultRoleHandlerForContentType((CFStringRef)type,kLSRolesViewer,(CFStringRef)handler);
		}
	}
}

@end
