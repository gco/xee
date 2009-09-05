#import "XeeCollisionPanel.h"
#import "XeeImage.h"
#import "XeeView.h"
#import "XeeControllerFileActions.h"
#import "XeeStringAdditions.h"



@implementation XeeCollisionPanel

-(void)run:(NSWindow *)window sourceImage:(XeeImage *)srcimage size:(off_t)srcsize
date:(NSDate *)srcdate destinationPath:(NSString *)destpath mode:(int)mode
delegate:(id)delegate didEndSelector:(SEL)selector
{
	enddelegate=delegate;
	endselector=selector;

	destinationpath=[destpath retain];
	transfermode=mode;

	XeeImage *destimage=[XeeImage imageForFilename:destpath];
	if(destimage)
	{
		float horiz_zoom=128/(float)[destimage width];
		float vert_zoom=128/(float)[destimage height];
		float min_zoom=horiz_zoom<vert_zoom?horiz_zoom:vert_zoom;
		float zoom;

		if(min_zoom<1) zoom=min_zoom;
		else zoom=1;

		[icon setImage:destimage];
		[icon setImageSize:NSMakeSize(zoom*(float)[destimage width],zoom*(float)[destimage height])];
		[NSThread detachNewThreadSelector:@selector(loadThumbnail:) toTarget:self withObject:destimage];
	}
	else
	{
		// TODO: display icon
/*		NSImage *iconimage=[[NSWorkspace sharedWorkspace] iconForFile:destination];
		[iconimage setSize:NSMakeSize(128,128)];
		[icon setImage:[XeeNSImageiconimage];*/
		[icon setImage:nil];
	}

	NSDictionary *destattrs=[[NSFileManager defaultManager] fileAttributesAtPath:destpath traverseLink:YES];

	[titlefield setStringValue:[NSString stringWithFormat:NSLocalizedString(@"The file \"%@\" already exists.",
	@"Title of the file exists dialog"),[[destpath lastPathComponent] stringByMappingColonToSlash]]];

	[oldsize setStringValue:[NSString stringWithFormat:@"%qu",[destattrs fileSize]]];
	[newsize setStringValue:[NSString stringWithFormat:@"%qu",srcsize]];

	[olddate setStringValue:XeeDescribeDate([destattrs fileModificationDate])];
	[newdate setStringValue:XeeDescribeDate(srcdate)];

	if(destimage)
	{
		[oldformat setStringValue:[NSString stringWithFormat:@"%dx%d\n%@ %@",
		[destimage width],[destimage height],[destimage depth],[destimage format]]];
	}
	else [oldformat setStringValue:@""];

	if(srcimage)
	{
		[newformat setStringValue:[NSString stringWithFormat:@"%dx%d\n%@ %@",
		[srcimage width],[srcimage height],[srcimage depth],[srcimage format]]];
	}
	else [newformat setStringValue:@""];

	NSString *newpath;
	NSString *destdir=[destpath stringByDeletingLastPathComponent];
	NSString *destname=[[destpath lastPathComponent] stringByDeletingPathExtension];
	NSString *destext=[destpath pathExtension];
	int n=1;

	do { newpath=[destdir stringByAppendingPathComponent:[[NSString stringWithFormat:@"%@-%d",destname,n++] stringByAppendingPathExtension:destext]]; }
	while([[NSFileManager defaultManager] fileExistsAtPath:newpath]);

	[namefield setStringValue:[[newpath lastPathComponent] stringByMappingColonToSlash]];
	[self makeFirstResponder:namefield];
	[[namefield currentEditor] setSelectedRange:NSMakeRange(0,[[[namefield stringValue] stringByDeletingPathExtension] length])];

	[replacebutton setKeyEquivalent:@"\r"];
	[renamebutton setKeyEquivalent:@""];

	if(window)
	{
		sheet=YES;
		[NSApp beginSheet:self modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
	}
	else
	{
		sheet=NO;
		[self makeKeyAndOrderFront:nil];
	}

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

-(IBAction)cancelClick:(id)sender
{
	[self endWithReturnCode:0 path:nil];
}

-(IBAction)renameClick:(id)sender
{
	[self endWithReturnCode:2 path:[[destinationpath stringByDeletingLastPathComponent]
	stringByAppendingPathComponent:[[namefield stringValue] stringByMappingSlashToColon]]];
}

-(IBAction)replaceClick:(id)sender
{
	[self endWithReturnCode:1 path:destinationpath];
}

-(void)endWithReturnCode:(int)res path:(NSString *)destination
{
	if(sheet) [NSApp endSheet:self];
	[self orderOut:nil];

	[icon setImage:nil];
	[destinationpath autorelease]; // Avoid releasing the destination string when clicking replace

	NSInvocation *invocation=[NSInvocation invocationWithMethodSignature:[enddelegate methodSignatureForSelector:endselector]];
	[invocation setSelector:endselector];
	[invocation setArgument:&self atIndex:2];
	[invocation setArgument:&res atIndex:3];
	[invocation setArgument:&destination atIndex:4];
	[invocation setArgument:&transfermode atIndex:5];

	[invocation invokeWithTarget:enddelegate];
}


-(void)controlTextDidChange:(NSNotification *)notification
{
	[replacebutton setKeyEquivalent:@""];
	[renamebutton setKeyEquivalent:@"\r"];
}

@end
