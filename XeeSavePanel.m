#import "XeeSavePanel.h"
#import "XeeImageSaver.h"
#import "XeeImage.h"
#import "XeeController.h"
#import "XeeSimpleLayout.h"



@implementation XeeSavePanel

+(void)runSavePanelForImage:(XeeImage *)image controller:(XeeController *)controller
{
	XeeSavePanel *panel=[[[XeeSavePanel alloc] initWithImage:image controller:controller] autorelease];

	if(!panel)
	{
		NSAlert *alert=[[[NSAlert alloc] init] autorelease];
		[alert setMessageText:NSLocalizedString(@"Problem Saving Image",@"Error title when failing to find an image saver module that works")];
		[alert setInformativeText:NSLocalizedString(@"Xee is unable to save this image. Please run Xee on Mac OS X 10.4 or higher for full functionality.",@"Error text when failing to find an image saver module that works")];
		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert addButtonWithTitle:NSLocalizedString(@"OK","OK Button")];
		[alert beginSheetModalForWindow:[controller window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
	}
	else
	{
		if([controller fullScreenWindow]) [panel runModal];
		else [panel beginSheetForWindow:[controller window]];
	}
}


-(id)initWithImage:(XeeImage *)img controller:(XeeController *)cont
{
	if(self=[super init])
	{
		textview=nil;
		image=[img retain];
		controller=[cont retain];
		formats=nil;
		view=nil;

		wasanimating=[image animating];
		[image setAnimating:NO];

		savers=[[XeeImageSaver saversForImage:image] retain];

		if(![savers count]) { [self release]; return nil; }

		NSMutableArray *pages=[NSMutableArray arrayWithCapacity:[savers count]];
		NSMutableArray *names=[NSMutableArray arrayWithCapacity:[savers count]];
		NSEnumerator *enumerator=[savers objectEnumerator];
		XeeImageSaver *saver;
		int def=0;

		while(saver=[enumerator nextObject])
		{
			id control=[saver control];
			if(!control) control=[NSNull null];
			[pages addObject:control];
			[names addObject:[saver format]];
		}

		formats=[[[XeeSLPages alloc] initWithTitle:NSLocalizedString(@"Format:",@"Format popup for saving images") pages:pages names:names defaultValue:def] autorelease];
		view=[[[XeeSimpleLayout alloc] initWithControl:formats] autorelease];
		[view setDelegate:self];

		NSView *superview=[[[NSView alloc] initWithFrame:[view frame]] autorelease];
		[superview addSubview:view];

		[self setAccessoryView:superview];
	}
	return self;
}

-(void)dealloc
{
	[image release];
	[controller release];
	[savers release];
	[formats release];
	[view release];

	[super dealloc];
}

-(void)beginSheetForWindow:(NSWindow *)window
{
	NSString *path=[image filename];
	NSString *directory=[path stringByDeletingLastPathComponent];
	NSString *filename=[self updateExtension:[path lastPathComponent]];

	[self beginSheetForDirectory:directory file:filename modalForWindow:window
	modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:)
	contextInfo:nil];

	id first=[self firstResponder];
	if([first class]==[NSTextView class]) textview=first;

	[self selectNamePart];
}

-(void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)res contextInfo:(void *)info
{
	if(res==NSOKButton)
	{
		[controller detachBackgroundTaskWithMessage:[NSString stringWithFormat:
		NSLocalizedString(@"Saving as \"%@\"...",@"Message when saving an image as"),
		[[self filename] lastPathComponent]]
		selector:@selector(saveTask) target:self];
	}

	[image setAnimating:wasanimating];
}

-(void)saveTask
{
	NSString *filename=[self filename];

	int page=[formats value];
	if([(XeeImageSaver *)[savers objectAtIndex:page] save:filename])
	{
		NSApplication *app=[NSApplication sharedApplication];
		[[app delegate] application:app openFile:filename];
	}
	else
	{
		NSAlert *alert=[[[NSAlert alloc] init] autorelease];
		[alert setMessageText:NSLocalizedString(@"Image saving failed",@"Title of the file saving failure dialog")];
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Couldn't save the file \"%@\".",
		@"Content of the file saving failure dialog"),[filename lastPathComponent]]];
		[alert addButtonWithTitle:NSLocalizedString(@"OK",@"OK button")];
		[alert runModal];
	}
}

-(void)xeeSLUpdated:(XeeSimpleLayout *)alsoview
{
	NSSavePanel *panel=(NSSavePanel *)[view window];

	[textview setString:[self updateExtension:[textview string]]];
	[self selectNamePart];

	NSView *superview=[[[NSView alloc] initWithFrame:[view frame]] autorelease];
	[view retain];
	[view removeFromSuperview];
	[superview addSubview:view];
	[view release];

	[panel setAccessoryView:superview];
}

-(NSString *)updateExtension:(NSString *)filename
{
	NSString *extension=[[savers objectAtIndex:[formats value]] extension];

	if(filename&&[filename length])
	return [[filename stringByDeletingPathExtension] stringByAppendingPathExtension:extension];
	else return @"";
}

-(void)selectNamePart
{
	[textview setSelectedRange:NSMakeRange(0,[[[textview string] stringByDeletingPathExtension] length])];
}

@end