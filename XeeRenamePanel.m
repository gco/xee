#import "XeeRenamePanel.h"
#import "XeeImage.h"
#import "XeeControllerFileActions.h"



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
