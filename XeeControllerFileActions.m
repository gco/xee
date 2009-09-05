#import "XeeControllerFileActions.h"
#import "XeeImage.h"
#import "XeeImageSource.h"
#import "XeeDestinationList.h"
#import "XeeCollisionPanel.h"
#import "XeeRenamePanel.h"
#import "XeeDelegate.h"
#import "XeeStringAdditions.h"



@implementation XeeController (FileActions)

-(IBAction)revealInFinder:(id)sender
{
	if(![self validateAction:_cmd]) { NSBeep(); return; }

	NSString *filename=[window representedFilename];
	if(!filename) return;

	[[NSWorkspace sharedWorkspace] selectFile:filename inFileViewerRootedAtPath:nil];
}



-(IBAction)renameFileFromMenu:(id)sender
{
	if(![self validateAction:_cmd]) { NSBeep(); return; }

	if(!renamepanel)
	{
		NSNib *nib=[[[NSNib alloc] initWithNibNamed:@"RenamePanel" bundle:nil] autorelease];
		[nib instantiateNibWithOwner:self topLevelObjects:nil];
	}

	[source setActionsBlocked:YES];

	[renamepanel run:fullscreenwindow?nil:window filename:[source filenameOfCurrentImage]
	delegate:self didEndSelector:@selector(renamePanelEnd:returnCode:filename:)];
}

-(void)renamePanelEnd:(XeeRenamePanel *)panel returnCode:(int)res filename:(NSString *)newname 
{
	if(res)
	{
		[self displayPossibleError:[source renameCurrentImageTo:[newname stringByMappingSlashToColon]]];
	}

	[source setActionsBlocked:NO];
}


-(IBAction)deleteFileFromMenu:(id)sender
{
	if([source isCurrentImageRemote]) { [self askAndDelete:sender]; return; }

	if(![self validateAction:_cmd]) { NSBeep(); return; }

	[self setResizeBlockFromSender:sender];
	[self displayPossibleError:[source deleteCurrentImage]];
	[self setResizeBlock:NO];
}

-(IBAction)askAndDelete:(id)sender
{
	if(![self validateAction:_cmd]) { NSBeep(); return; }

	[self setResizeBlockFromSender:sender];

	NSAlert *alert=[[NSAlert alloc] init];

	if([source isCurrentImageRemote])
	{
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Do you want to delete the image file \"%@\"?\nThe file will be removed immediately.",@"Content of the delete confirmation dialog for remote files"),
		[source descriptiveNameOfCurrentImage]]];
		[alert setAlertStyle:NSCriticalAlertStyle];
	}
	else
	{
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Do you want to delete the image file \"%@\"?",@"Content of the delete confirmation dialog"),
		[source descriptiveNameOfCurrentImage]]];
		[alert setIcon:[[[NSImage alloc] initWithContentsOfFile:@"/System/Library/CoreServices/Dock.app/Contents/Resources/trashfull.png"] autorelease]];
	}

	[alert setMessageText:NSLocalizedString(@"Delete File",@"Title of the delete confirmation dialog")];
	[alert addButtonWithTitle:NSLocalizedString(@"Delete",@"Delete button")];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel",@"Cancel button")];

	[source setActionsBlocked:YES];

	if(fullscreenwindow) [self deleteAlertEnd:alert returnCode:[alert runModal] contextInfo:NULL];
	else [alert beginSheetModalForWindow:window modalDelegate:self didEndSelector:@selector(deleteAlertEnd:returnCode:contextInfo:) contextInfo:NULL];

	[self setResizeBlock:NO];
}

-(void)deleteAlertEnd:(NSAlert *)alert returnCode:(int)res contextInfo:(void *)info
{
	if(res==NSAlertFirstButtonReturn) [self displayPossibleError:[source deleteCurrentImage]];

	[source setActionsBlocked:NO];
}



-(IBAction)moveFile:(id)sender
{
	if(![self validateAction:_cmd]) { NSBeep(); return; }
	[self triggerDrawer:XeeMoveMode];
}

-(IBAction)copyFile:(id)sender
{
	if(![self validateAction:_cmd]) { NSBeep(); return; }
	[self triggerDrawer:XeeCopyMode];
}

-(IBAction)copyToDestination1:(id)sender { [self transferToDestination:1 mode:XeeCopyMode]; }
-(IBAction)copyToDestination2:(id)sender { [self transferToDestination:2 mode:XeeCopyMode]; }
-(IBAction)copyToDestination3:(id)sender { [self transferToDestination:3 mode:XeeCopyMode]; }
-(IBAction)copyToDestination4:(id)sender { [self transferToDestination:4 mode:XeeCopyMode]; }
-(IBAction)copyToDestination5:(id)sender { [self transferToDestination:5 mode:XeeCopyMode]; }
-(IBAction)copyToDestination6:(id)sender { [self transferToDestination:6 mode:XeeCopyMode]; }
-(IBAction)copyToDestination7:(id)sender { [self transferToDestination:7 mode:XeeCopyMode]; }
-(IBAction)copyToDestination8:(id)sender { [self transferToDestination:8 mode:XeeCopyMode]; }
-(IBAction)copyToDestination9:(id)sender { [self transferToDestination:9 mode:XeeCopyMode]; }
-(IBAction)copyToDestination10:(id)sender { [self transferToDestination:10 mode:XeeCopyMode]; }

-(IBAction)moveToDestination1:(id)sender { [self transferToDestination:1 mode:XeeMoveMode]; }
-(IBAction)moveToDestination2:(id)sender { [self transferToDestination:2 mode:XeeMoveMode]; }
-(IBAction)moveToDestination3:(id)sender { [self transferToDestination:3 mode:XeeMoveMode]; }
-(IBAction)moveToDestination4:(id)sender { [self transferToDestination:4 mode:XeeMoveMode]; }
-(IBAction)moveToDestination5:(id)sender { [self transferToDestination:5 mode:XeeMoveMode]; }
-(IBAction)moveToDestination6:(id)sender { [self transferToDestination:6 mode:XeeMoveMode]; }
-(IBAction)moveToDestination7:(id)sender { [self transferToDestination:7 mode:XeeMoveMode]; }
-(IBAction)moveToDestination8:(id)sender { [self transferToDestination:8 mode:XeeMoveMode]; }
-(IBAction)moveToDestination9:(id)sender { [self transferToDestination:9 mode:XeeMoveMode]; }
-(IBAction)moveToDestination10:(id)sender { [self transferToDestination:10 mode:XeeMoveMode]; }

-(void)triggerDrawer:(int)mode
{
	int newseg;
	if(mode==XeeCopyMode) newseg=0;
	else newseg=1;

	int state=[drawer state];

	if(state==NSDrawerClosedState||state==NSDrawerClosingState)
	{
		[drawer openOnEdge:NSMaxXEdge];

		NSRect frame=[window frame];
		NSRect visible=[[window screen] visibleFrame];
		float drawerwidth=[drawer contentSize].width+XeeDrawerEdgeWidth;

		// See if the drawer fits on screen, and if not, move and resize to make it fit.
		if(frame.origin.x+frame.size.width+drawerwidth>visible.origin.x+visible.size.width)
		{
			frame.origin.x=visible.origin.x+visible.size.width-frame.size.width-drawerwidth;
			if(frame.origin.x<visible.origin.x)
			{
				frame.size.width+=frame.origin.x;
				frame.origin.x=0;
			}

			[window setFrame:frame display:YES animate:YES];
		}
	}
	else
	{
		if([drawerseg selectedSegment]==newseg) [closebutton performClick:nil];
	}

	[drawerseg setSelectedSegment:newseg];
	[destinationtable switchMode:drawerseg];
}

-(void)drawerWillOpen:(NSNotification *)notification
{
	[window makeFirstResponder:destinationtable];
	[imageview setNextKeyView:destinationtable];
	[[drawer contentView] setNextResponder:window];
}

-(void)drawerDidClose:(NSNotification *)notification
{
	[imageview setNextKeyView:nil];
}

-(void)destinationListClick:(id)sender
{
	if(!currimage) return;
	if(fullscreenwindow) return; // just to be safe

	if([drawerseg selectedSegment]==0) drawer_mode=XeeCopyMode;
	else drawer_mode=XeeMoveMode;

	int index=[sender selectedRow];

	if(index==0)
	{
		NSOpenPanel *panel=[NSOpenPanel openPanel];
		[panel setCanChooseDirectories:YES];
		[panel setCanChooseFiles:NO];
		[panel setCanCreateDirectories:YES];
		if(drawer_mode==XeeMoveMode) [panel setPrompt:NSLocalizedString(@"Move",@"Move button")];
		else if(drawer_mode==XeeCopyMode) [panel setPrompt:NSLocalizedString(@"Copy",@"Copy button and menuitem")];

		[source setActionsBlocked:YES];

		[panel beginSheetForDirectory:nil file:nil types:nil modalForWindow:window modalDelegate:self
		didEndSelector:@selector(destinationPanelEnd:returnCode:contextInfo:) contextInfo:NULL];
	}
	else [self transferToDestination:index mode:drawer_mode];
}

-(void)destinationPanelEnd:(NSOpenPanel *)panel returnCode:(int)res contextInfo:(void *)info
{
	if(res==NSOKButton)
	{
		NSString *destdir=[[panel filenames] objectAtIndex:0];
		NSString *destination=[destdir stringByAppendingPathComponent:[source filenameOfCurrentImage]];

		[XeeDestinationView suggestInsertion:destdir];

		[self attemptToTransferCurrentImageTo:destination mode:drawer_mode];
	}
	else
	{
		[source setActionsBlocked:NO];
	}
}

-(void)transferToDestination:(int)index mode:(int)mode
{
	if(mode==XeeCopyMode&&![source canCopyCurrentImage]) { NSBeep(); return; }
	else if(mode==XeeMoveMode&&![source canMoveCurrentImage]) { NSBeep(); return; }

	NSString *path=[destinationtable pathForRow:index];
	if(!path) { NSBeep(); return; }
	NSString *destination=[path stringByAppendingPathComponent:[source filenameOfCurrentImage]];
	[self attemptToTransferCurrentImageTo:destination mode:mode];
}

-(void)attemptToTransferCurrentImageTo:(NSString *)destination mode:(int)mode
{
	if([source isCurrentImageAtPath:destination])
	{
		[self displayErrorMessage:NSLocalizedString(@"File already there",@"Title of the move/copy to same folder dialog")
		text:NSLocalizedString(@"The source and destination locations are the same.",@"Content of the move/copy to same folder dialog")];
		[source setActionsBlocked:NO];
		return;
	}

	NSDictionary *destinfo=[[NSFileManager defaultManager] fileAttributesAtPath:destination traverseLink:YES];
	if(destinfo)
	{
		if(!collisionpanel)
		{
			NSNib *nib=[[[NSNib alloc] initWithNibNamed:@"CollisionPanel" bundle:nil] autorelease];
			[nib instantiateNibWithOwner:self topLevelObjects:nil];
		}

		[source setActionsBlocked:YES];

		[collisionpanel run:fullscreenwindow?nil:window sourceImage:currimage
		size:[source sizeOfCurrentImage] date:[source dateOfCurrentImage]
		destinationPath:destination mode:mode delegate:self
		didEndSelector:@selector(collisionPanelEnd:returnCode:path:mode:)];
	}
	else
	{
//		[self performSelector:@selector() withObject: afterDelay:0];
		[self transferCurrentImageTo:destination mode:mode];
		[source setActionsBlocked:NO];
	}
}

-(void)collisionPanelEnd:(XeeCollisionPanel *)panel returnCode:(int)res path:(NSString *)destination mode:(int)mode
{
	if(res==1)
	{
		[self transferCurrentImageTo:destination mode:mode];
		[source setActionsBlocked:NO];
	}
	else if(res==2)
	{
		[self attemptToTransferCurrentImageTo:destination mode:mode];
	}
	else
	{
		[source setActionsBlocked:NO];
	}
}

-(void)transferCurrentImageTo:(NSString *)destination mode:(int)mode
{
	if(mode==XeeMoveMode) [self displayPossibleError:[source moveCurrentImageTo:destination]];
	else [self displayPossibleError:[source copyCurrentImageTo:destination]];
}




-(IBAction)launchAppFromMenu:(id)sender
{
	if(![self validateAction:_cmd]) { NSBeep(); return; }

	NSString *app=[sender representedObject];
	[self displayPossibleError:[source openCurrentImageInApp:app]];
}

-(IBAction)launchDefaultEditor:(id)sender
{
	if(![self validateAction:_cmd]) { NSBeep(); return; }

	NSString *app=[maindelegate defaultEditor];
	[self displayPossibleError:[source openCurrentImageInApp:app]];
}


@end
