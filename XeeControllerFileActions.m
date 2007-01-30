#import "XeeControllerFileActions.h"
#import "XeeImage.h"
#import "XeeImageSource.h"
#import "XeeDestinationList.h"
#import "XeeCollisionPanel.h"
#import "XeeRenamePanel.h"
#import "XeeDelegate.h"



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

	[renamepanel run:fullscreenwindow?nil:window image:currimage];
}

-(void)renameFile:(NSString *)filename to:(NSString *)newname
{
	if([filename isEqual:newname]) return;

	if([[NSFileManager defaultManager] fileExistsAtPath:newname])
	{
		[self errorMessage:NSLocalizedString(@"Couldn't rename file",@"Title of the rename error dialog")
		text:[NSString stringWithFormat:NSLocalizedString(@"The file \"%@\" could not be renamed because another file with the same name already exists.",@"Content of the rename collision dialog"),
		[filename lastPathComponent]]];
	}
	else
	{
		if([[NSFileManager defaultManager] movePath:filename toPath:newname handler:nil])
		{
			// success, let kqueue update list
		}
		else
		{
			[self errorMessage:NSLocalizedString(@"Couldn't rename file",@"Title of the rename error dialog")
			text:[NSString stringWithFormat:NSLocalizedString(@"The file \"%@\" could not be renamed.",@"Content of the rename error dialog"),
			[filename lastPathComponent]]];
		}
	}
}


-(IBAction)deleteFileFromMenu:(id)sender
{
	if(![self validateAction:_cmd]) { NSBeep(); return; }

	[self setResizeBlockFromSender:sender];
	[self deleteFile:[self currentFilename]];
	[self setResizeBlock:NO];
}

-(IBAction)askAndDelete:(id)sender
{
	if(![self validateAction:_cmd]) { NSBeep(); return; }

	[self setResizeBlockFromSender:sender];

	NSString *filename=[[self currentFilename] retain];
	NSAlert *alert=[[NSAlert alloc] init];

	[alert setMessageText:NSLocalizedString(@"Delete File",@"Title of the delete confirmation dialog")];
	[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Do you want to delete the image file \"%@\"?",@"Content of the delete confirmation dialog"),[filename lastPathComponent]]];
	[alert addButtonWithTitle:NSLocalizedString(@"Delete",@"Delete button")];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel",@"Cancel button")];
	[alert setIcon:[[[NSImage alloc] initWithContentsOfFile:@"/System/Library/CoreServices/Dock.app/Contents/Resources/trashfull.png"] autorelease]];

	if(fullscreenwindow) [self deleteAlertEnd:alert returnCode:[alert runModal] contextInfo:[filename retain]];
	else  [alert beginSheetModalForWindow:window modalDelegate:self didEndSelector:@selector(deleteAlertEnd:returnCode:contextInfo:) contextInfo:[filename retain]];

	[self setResizeBlock:NO];
}

-(void)deleteAlertEnd:(NSAlert *)alert returnCode:(int)res contextInfo:(NSString *)filename
{
	if(res==NSAlertFirstButtonReturn)
	{
		[self deleteFile:filename];
	}
	[filename release];
}

-(void)deleteFile:(NSString *)filename
{
	if([[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:[filename stringByDeletingLastPathComponent]
	destination:nil files:[NSArray arrayWithObject:[filename lastPathComponent]] tag:nil])
	{
		// success, let kqueue update list
		[self playSound:@"/System/Library/Components/CoreAudio.component/Contents/Resources/SystemSounds/dock/drag to trash.aif"];
	}
	else
	{
		[self errorMessage:NSLocalizedString(@"Couldn't delete file",@"Title of the delete failure dialog")
		text:[NSString stringWithFormat:NSLocalizedString(@"The file \"%@\" could not be deleted.",@"Content of the delet failure dialog"),
		[filename lastPathComponent]]];
	}
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

	NSString *filename=[self currentFilename];
	int index=[sender selectedRow];

	if(index==0)
	{
		NSOpenPanel *panel=[NSOpenPanel openPanel];
		[panel setCanChooseDirectories:YES];
		[panel setCanChooseFiles:NO];
		[panel setCanCreateDirectories:YES];
		if(drawer_mode==XeeMoveMode) [panel setPrompt:NSLocalizedString(@"Move",@"Move button")];
		else if(drawer_mode==XeeCopyMode) [panel setPrompt:NSLocalizedString(@"Copy",@"Copy button and menuitem")];

		[panel beginSheetForDirectory:nil file:nil types:nil modalForWindow:window modalDelegate:self
		didEndSelector:@selector(destinationPanelEnd:returnCode:contextInfo:) contextInfo:[filename retain]];
	}
	else [self transferToDestination:index mode:drawer_mode];
}

-(void)destinationPanelEnd:(NSOpenPanel *)panel returnCode:(int)res contextInfo:(NSString *)filename
{
	if(res==NSOKButton)
	{
		NSString *destdir=[[panel filenames] objectAtIndex:0];
		NSString *destination=[destdir stringByAppendingPathComponent:[filename lastPathComponent]];

		[XeeDestinationView suggestInsertion:destdir];

		[self attemptToTransferFile:filename to:destination mode:drawer_mode];
	}
	[filename release];
}

-(void)transferToDestination:(int)index mode:(int)mode
{
	if(mode==XeeCopyMode&&!([source capabilities]&XeeCopyingCapable)) { NSBeep(); return; }
	else if(mode==XeeMoveMode&&!([source capabilities]&XeeMovingCapable)) { NSBeep(); return; }

	NSString *filename=[self currentFilename];
	NSString *path=[destinationtable pathForRow:index];
	if(!path) { NSBeep(); return; }
	NSString *destination=[path stringByAppendingPathComponent:[filename lastPathComponent]];
	[self attemptToTransferFile:filename to:destination mode:mode];
}

-(void)attemptToTransferFile:(NSString *)filename to:(NSString *)destination mode:(int)mode
{
	if([filename isEqual:destination])
	{
		[self errorMessage:NSLocalizedString(@"File already there",@"Title of the move/copy to same folder dialog")
		text:NSLocalizedString(@"The source and destination locations are the same.",@"Content of the move/copy to same folder dialog")];
	}
	else
	{
		NSDictionary *destinfo=[[NSFileManager defaultManager] fileAttributesAtPath:destination traverseLink:YES];

		if(destinfo)
		{
			if(!collisionpanel)
			{
				NSNib *nib=[[[NSNib alloc] initWithNibNamed:@"CollisionPanel" bundle:nil] autorelease];
				[nib instantiateNibWithOwner:self topLevelObjects:nil];
			}

			XeeImage *destimage=[XeeImage imageForFilename:destination];
			[collisionpanel run:window source:currimage destination:destimage mode:mode];
		}
		else
		{
//		[self performSelector:@selector() withObject: afterDelay:0];
			[self transferFile:filename to:destination mode:mode];
		}
	}
}

-(void)transferFile:(NSString *)filename to:(NSString *)destination mode:(int)mode
{
	if([[NSFileManager defaultManager] fileExistsAtPath:destination])
	{
		[[NSFileManager defaultManager] removeFileAtPath:destination handler:nil];
	}

	if(mode==XeeMoveMode)
	{
		if([[NSFileManager defaultManager] movePath:filename toPath:destination handler:nil])
		{
			// "moved" message in status bar
			[self playSound:@"/System/Library/Components/CoreAudio.component/Contents/Resources/SystemSounds/system/Volume Mount.aif"];
			// success, let kqueue update list
		}
		else
		{
			[self errorMessage:NSLocalizedString(@"Couldn't move file",@"Title of the move failure dialog")
			text:[NSString stringWithFormat:NSLocalizedString(@"The file \"%@\" could not be moved to the folder \"%@\".",@"Content of the move failure dialog"),
			[filename lastPathComponent],[destination stringByDeletingLastPathComponent]]];
		}
	}
	else
	{
		if([[NSFileManager defaultManager] copyPath:filename toPath:destination handler:nil])
		{
			// "copied" message in status bar
			[self playSound:@"/System/Library/Components/CoreAudio.component/Contents/Resources/SystemSounds/system/Volume Mount.aif"];
		}
		else
		{
			[self errorMessage:NSLocalizedString(@"Couldn't copy file",@"Title of the copy failure dialog")
			text:[NSString stringWithFormat:NSLocalizedString(@"The file \"%@\" could not be copied to the folder \"%@\".",@"Content of the copy failure dialog"),
			[filename lastPathComponent],[destination stringByDeletingLastPathComponent]]];
		}
	}
}



-(void)playSound:(NSString *)filename
{
	[self performSelector:@selector(actuallyPlaySound:) withObject:filename afterDelay:0];
}

-(void)actuallyPlaySound:(NSString *)filename
{
	[[[[NSSound alloc] initWithContentsOfFile:filename byReference:NO] autorelease] play];
}



-(IBAction)launchAppFromMenu:(id)sender
{
	if(!currimage) return;

	NSString *filename=[self currentFilename];
	if(!filename) return;

	NSString *app=[sender representedObject];

	[[NSWorkspace sharedWorkspace] openFile:filename withApplication:app];
}

-(IBAction)launchDefaultEditor:(id)sender
{
	if(!currimage) return;

	NSString *filename=[self currentFilename];
	if(!filename) return;

	NSString *app=[maindelegate defaultEditor];
	if(!app) return;

	[[NSWorkspace sharedWorkspace] openFile:filename withApplication:app];
}


@end
