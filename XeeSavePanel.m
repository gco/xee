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
		NSString *path=[image filename];
		NSString *directory=[path stringByDeletingLastPathComponent];
		NSString *filename=[panel updateExtension:[path lastPathComponent]];

		if([controller fullScreenWindow])
		{
			[panel savePanelDidEnd:panel returnCode:[panel runModalForDirectory:directory file:filename] contextInfo:NULL];
		}
		else
		{
			[panel beginSheetForDirectory:directory file:filename modalForWindow:[controller window]
			modalDelegate:panel didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:)
			contextInfo:nil];
		}
	}
}

-(id)initWithImage:(XeeImage *)img controller:(XeeController *)cont
{
	if(self=[super init])
	{
		textview=nil;
		textfield=nil;
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

-(BOOL)makeFirstResponder:(NSResponder *)responder
{
	if(!textview&&!textfield)
	{
		if(!textview && [responder isKindOfClass:[NSTextView class]]) textview=(NSTextView *)responder;
		else if(!textfield && [responder isKindOfClass:[NSTextField class]]) textfield=(NSTextField *)responder;

		if(textview||textfield) [self performSelector:@selector(selectNamePart) withObject:nil afterDelay:0
		inModes:[NSArray arrayWithObjects:NSDefaultRunLoopMode,NSModalPanelRunLoopMode,nil]];
	}

	return [super makeFirstResponder:responder];
}

-(void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)res contextInfo:(void *)info
{
	if(res==NSOKButton)
	{
		[controller detachBackgroundTaskWithMessage:[NSString stringWithFormat:
		NSLocalizedString(@"Saving as \"%@\"...",@"Message when saving an image as"),
		[[self filename] lastPathComponent]]
		selector:@selector(saveTask) target:self object:nil];
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

	[self setFilenameFieldContents:[self updateExtension:[self filenameFieldContents]]];
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

-(NSString *)filenameFieldContents
{
	if(textview) return [textview string];
	else return [textfield stringValue];
}

-(void)setFilenameFieldContents:(NSString *)filename
{
	if(textview) [textview setString:filename];
	else [textfield setStringValue:filename];
}

-(void)selectNamePart
{
	int length=[[[self filenameFieldContents] stringByDeletingPathExtension] length];
	NSRange range=NSMakeRange(0,length);
	if(textview) [textview setSelectedRange:range];
	else
	{
		[self makeFirstResponder:textfield];
		[[textfield currentEditor] setSelectedRange:range];
	}
}

@end
