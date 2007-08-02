#import "XeeCollisionPanel.h"
#import "XeeImage.h"
#import "XeeView.h"
#import "XeeControllerFileActions.h"
#import "XeeStringAdditions.h"



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
	@"Title of the file exists dialog"),[[[destimage filename] lastPathComponent] stringByMappingColonToSlash]]];

	[oldsize setStringValue:[NSString stringWithFormat:@"%d",[destimage fileSize]]];
	[newsize setStringValue:[NSString stringWithFormat:@"%d",[srcimage fileSize]]];

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

	[namefield setStringValue:[[newname lastPathComponent] stringByMappingColonToSlash]];
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

	[srcimage release];
	[destimage release];
	[icon setImage:nil];
}

-(void)renameClick:(id)sender
{
	[[NSApplication sharedApplication] endSheet:self];
	[self orderOut:nil];

	NSString *destination=[[[destimage filename] stringByDeletingLastPathComponent]
	stringByAppendingPathComponent:[[namefield stringValue] stringByMappingSlashToColon]];
	[controller attemptToTransferFile:[srcimage filename] to:destination mode:transfermode];

	[destimage setAnimating:NO];

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
