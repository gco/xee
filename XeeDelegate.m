#import "XeeDelegate.h"
#import "XeeController.h"
#import "XeeControllerImageActions.h"
#import "XeeControllerNavigationActions.h"
#import "XeeImage.h"
#import "XeeNSImage.h"
#import "XeePropertiesController.h"

#import "CSKeyboardShortcuts.h"

#import "XeeDirectorySource.h"
#import "XeeArchiveSource.h"
#import "XeePDFSource.h"
#import "XeeSWFSource.h"
#import "XeeClipboardSource.h"

#import "XeeImageIOLoader.h"
#import "XeeQuicktimeLoader.h"
#import "XeeJPEGLoader.h"
#import "XeePNGLoader.h"
#import "XeeGIFLoader.h"
#import "XeePhotoshopLoader.h"
#import "XeePhotoshopPICTLoader.h"
#import "XeeILBMLoader.h"
#import "XeePCXLoader.h"
#import "XeeMayaLoader.h"
#import "XeeDreamcastLoader.h"
#import "XeePNMLoader.h"
#import "XeeXBMLoader.h"
#import "XeeXPMLoader.h"

#import "XeeImageIOSaver.h"
#import "XeeLosslessSaver.h"
#import "XeeExperimentalImage1Saver.h"



XeeDelegate *maindelegate=nil;
BOOL finderlaunch;


@implementation XeeDelegate

-(id)init
{
	if(self=[super init])
	{
		filesopened=NO;
		openediconset=nil;
		prefswindow=nil;
		iconwindow=nil;
		iconfield=nil;

		controllers=[[NSMutableDictionary dictionary] retain];
	}
	return self;
}

-(void)awakeFromNib
{
	if(maindelegate) return; // fuck you too, Cocoa.
	maindelegate=self;

	// what the hell? NSTableViews don't get scrollbars unless I do this.
	NSRect frame=[prefswindow frame];
	frame.size.height+=1; [prefswindow setFrame:frame display:YES];

	// remove format prefs on older systems
	if(floor(NSAppKitVersionNumber)<=NSAppKitVersionNumber10_3)
	[prefstabs removeTabViewItem:formattab];

	[XeeImage registerImageClass:[XeeJPEGImage class]];
	[XeeImage registerImageClass:[XeePNGImage class]];
	[XeeImage registerImageClass:[XeeGIFImage class]];
	[XeeImage registerImageClass:[XeePhotoshopImage class]];
	[XeeImage registerImageClass:[XeePhotoshopPICTImage class]];
	[XeeImage registerImageClass:[XeeILBMImage class]];
	[XeeImage registerImageClass:[XeePCXImage class]];
	[XeeImage registerImageClass:[XeeMayaImage class]];
	[XeeImage registerImageClass:[XeeDreamcastImage class]];
	[XeeImage registerImageClass:[XeeDreamcastMultiImage class]];
	[XeeImage registerImageClass:[XeePNMImage class]];
	[XeeImage registerImageClass:[XeeXBMImage class]];
	[XeeImage registerImageClass:[XeeXPMImage class]];
	[XeeImage registerImageClass:[XeeImageIOImage class]];
	[XeeImage registerImageClass:[XeeQuicktimeImage class]];

	[XeeImageSaver registerSaverClass:[XeeLosslessSaver class]];
	[XeeImageSaver registerSaverClass:[XeePNGSaver class]];
	[XeeImageSaver registerSaverClass:[XeeJPEGSaver class]];
	[XeeImageSaver registerSaverClass:[XeeJP2Saver class]];
	[XeeImageSaver registerSaverClass:[XeeTIFFSaver class]];
	[XeeImageSaver registerSaverClass:[XeePhotoshopSaver class]];
	[XeeImageSaver registerSaverClass:[XeeOpenEXRSaver class]];
	[XeeImageSaver registerSaverClass:[XeeGIFSaver class]];
	[XeeImageSaver registerSaverClass:[XeePICTSaver class]];
	[XeeImageSaver registerSaverClass:[XeeBMPSaver class]];
	[XeeImageSaver registerSaverClass:[XeeTGASaver class]];
	[XeeImageSaver registerSaverClass:[XeeSGISaver class]];
	[XeeImageSaver registerSaverClass:[XeeExperimentalImage1Saver class]];

	[[antialiasmenu itemWithTag:[[NSUserDefaults standardUserDefaults] integerForKey:@"antialiasQuality"]] setState:NSOnState];

	CSKeyboardShortcuts *shortcuts=[CSKeyboardShortcuts defaultShortcuts];

	[shortcuts addActionsFromMenu:[[NSApplication sharedApplication] mainMenu]];
	[shortcuts addActions:[NSArray arrayWithObjects:
		[CSAction actionWithTitle:NSLocalizedString(@"Cancel Action or Close Window or Drawer",@"Action name for the keyboard shortcut for cancelling the current action, closing the current window, or drawer")
		selector:@selector(cancel:)],
		[CSAction actionWithTitle:NSLocalizedString(@"Confirm Action",@"Action name for the keyboard shortcut for confirming the current action")
		selector:@selector(confirm:)],
		[CSAction actionWithTitle:NSLocalizedString(@"Delete After Confirmation",@"Action name for the keyboard shortcut for deleting the current image (after a confirmation dialog)")
		selector:@selector(askAndDelete:)],
		actions[0]=[CSAction actionWithTitle:NSLocalizedString(@"Copy to Destination #1",@"Action name for the keyboard shortcut for copying to entry 1 in the destination list")
		selector:@selector(copyToDestination1:)],
		actions[1]=[CSAction actionWithTitle:NSLocalizedString(@"Copy to Destination #2",@"Action name for the keyboard shortcut for copying to entry 2 in the destination list")
		selector:@selector(copyToDestination2:)],
		actions[2]=[CSAction actionWithTitle:NSLocalizedString(@"Copy to Destination #3",@"Action name for the keyboard shortcut for copying to entry 3 in the destination list")
		selector:@selector(copyToDestination3:)],
		actions[3]=[CSAction actionWithTitle:NSLocalizedString(@"Copy to Destination #4",@"Action name for the keyboard shortcut for copying to entry 4 in the destination list")
		selector:@selector(copyToDestination4:)],
		actions[4]=[CSAction actionWithTitle:NSLocalizedString(@"Copy to Destination #5",@"Action name for the keyboard shortcut for copying to entry 5 in the destination list")
		selector:@selector(copyToDestination5:)],
		actions[5]=[CSAction actionWithTitle:NSLocalizedString(@"Copy to Destination #6",@"Action name for the keyboard shortcut for copying to entry 6 in the destination list")
		selector:@selector(copyToDestination6:)],
		actions[6]=[CSAction actionWithTitle:NSLocalizedString(@"Copy to Destination #7",@"Action name for the keyboard shortcut for copying to entry 7 in the destination list")
		selector:@selector(copyToDestination7:)],
		actions[7]=[CSAction actionWithTitle:NSLocalizedString(@"Copy to Destination #8",@"Action name for the keyboard shortcut for copying to entry 8 in the destination list")
		selector:@selector(copyToDestination8:)],
		actions[8]=[CSAction actionWithTitle:NSLocalizedString(@"Copy to Destination #9",@"Action name for the keyboard shortcut for copying to entry 9 in the destination list")
		selector:@selector(copyToDestination9:)],
		actions[9]=[CSAction actionWithTitle:NSLocalizedString(@"Copy to Destination #10",@"Action name for the keyboard shortcut for copying to entry 10 in the destination list")
		selector:@selector(copyToDestination10:)],
		actions[10]=[CSAction actionWithTitle:NSLocalizedString(@"Move to Destination #1",@"Action name for the keyboard shortcut for moving to entry 1 in the destination list")
		selector:@selector(moveToDestination1:)],
		actions[11]=[CSAction actionWithTitle:NSLocalizedString(@"Move to Destination #2",@"Action name for the keyboard shortcut for moving to entry 2 in the destination list")
		selector:@selector(moveToDestination2:)],
		actions[12]=[CSAction actionWithTitle:NSLocalizedString(@"Move to Destination #3",@"Action name for the keyboard shortcut for moving to entry 3 in the destination list")
		selector:@selector(moveToDestination3:)],
		actions[13]=[CSAction actionWithTitle:NSLocalizedString(@"Move to Destination #4",@"Action name for the keyboard shortcut for moving to entry 4 in the destination list")
		selector:@selector(moveToDestination4:)],
		actions[14]=[CSAction actionWithTitle:NSLocalizedString(@"Move to Destination #5",@"Action name for the keyboard shortcut for moving to entry 5 in the destination list")
		selector:@selector(moveToDestination5:)],
		actions[15]=[CSAction actionWithTitle:NSLocalizedString(@"Move to Destination #6",@"Action name for the keyboard shortcut for moving to entry 6 in the destination list")
		selector:@selector(moveToDestination6:)],
		actions[16]=[CSAction actionWithTitle:NSLocalizedString(@"Move to Destination #7",@"Action name for the keyboard shortcut for moving to entry 7 in the destination list")
		selector:@selector(moveToDestination7:)],
		actions[17]=[CSAction actionWithTitle:NSLocalizedString(@"Move to Destination #8",@"Action name for the keyboard shortcut for moving to entry 8 in the destination list")
		selector:@selector(moveToDestination8:)],
		actions[18]=[CSAction actionWithTitle:NSLocalizedString(@"Move to Destination #9",@"Action name for the keyboard shortcut for moving to entry 9 in the destination list")
		selector:@selector(moveToDestination9:)],
		actions[19]=[CSAction actionWithTitle:NSLocalizedString(@"Move to Destination #10",@"Action name for the keyboard shortcut for moving to entry 10 in the destination list")
		selector:@selector(moveToDestination10:)],
		[CSAction actionWithTitle:NSLocalizedString(@"Scroll Up",@"Action name for the scroll up key") identifier:@"scrollUp"],
		[CSAction actionWithTitle:NSLocalizedString(@"Scroll Down",@"Action name for the scroll down key") identifier:@"scrollDown"],
		[CSAction actionWithTitle:NSLocalizedString(@"Scroll Left",@"Action name for the scroll left key") identifier:@"scrollLeft"],
		[CSAction actionWithTitle:NSLocalizedString(@"Scroll Right",@"Action name for the scroll right key") identifier:@"scrollRight"],
	nil]];

	[shortcuts addShortcuts:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharCode:27 modifiers:0],nil],
		@"cancel:",
		[NSArray arrayWithObjects:
			[CSKeyStroke keyForCharCode:NSEnterCharacter modifiers:0],
			[CSKeyStroke keyForCharCode:NSCarriageReturnCharacter modifiers:0],
		nil],@"confirm:",
		[NSArray arrayWithObjects:
			[CSKeyStroke keyForCharCode:NSDeleteCharacter modifiers:0],
			[CSKeyStroke keyForCharCode:NSBackspaceCharacter modifiers:0],
		nil],@"askAndDelete:",
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharCode:NSUpArrowFunctionKey modifiers:0],nil],
		@"scrollUp",
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharCode:NSDownArrowFunctionKey modifiers:0],nil],
		@"scrollDown",
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharCode:NSLeftArrowFunctionKey modifiers:0],nil],
		@"scrollLeft",
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharCode:NSRightArrowFunctionKey modifiers:0],nil]
		,@"scrollRight",
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharacter:@"1" modifiers:CSCmd],nil],
		@"copyToDestination1:",
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharacter:@"2" modifiers:CSCmd],nil],
		@"copyToDestination2:",
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharacter:@"3" modifiers:CSCmd],nil],
		@"copyToDestination3:",
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharacter:@"4" modifiers:CSCmd],nil],
		@"copyToDestination4:",
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharacter:@"5" modifiers:CSCmd],nil],
		@"copyToDestination5:",
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharacter:@"6" modifiers:CSCmd],nil],
		@"copyToDestination6:",
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharacter:@"7" modifiers:CSCmd],nil],
		@"copyToDestination7:",
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharacter:@"8" modifiers:CSCmd],nil],
		@"copyToDestination8:",
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharacter:@"9" modifiers:CSCmd],nil],
		@"copyToDestination9:",
		//[NSArray arrayWithObjects:[CSKeyStroke keyForCharacter:@"0" modifiers:CSCmd],nil],
		//@"copyToDestination10:",
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharacter:@"1" modifiers:CSCtrl],nil],
		@"moveToDestination1:",
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharacter:@"2" modifiers:CSCtrl],nil],
		@"moveToDestination2:",
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharacter:@"3" modifiers:CSCtrl],nil],
		@"moveToDestination3:",
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharacter:@"4" modifiers:CSCtrl],nil],
		@"moveToDestination4:",
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharacter:@"5" modifiers:CSCtrl],nil],
		@"moveToDestination5:",
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharacter:@"6" modifiers:CSCtrl],nil],
		@"moveToDestination6:",
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharacter:@"7" modifiers:CSCtrl],nil],
		@"moveToDestination7:",
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharacter:@"8" modifiers:CSCtrl],nil],
		@"moveToDestination8:",
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharacter:@"9" modifiers:CSCtrl],nil],
		@"moveToDestination9:",
		[NSArray arrayWithObjects:[CSKeyStroke keyForCharacter:@"0" modifiers:CSCtrl],nil],
		@"moveToDestination10:",
		[NSArray arrayWithObjects:
			[CSKeyStroke keyForCharCode:NSPageDownFunctionKey modifiers:0],
			[CSKeyStroke keyForCharacter:@" " modifiers:0],
			[CSKeyStroke keyForCharacter:@"." modifiers:0],
			[CSKeyStroke keyForCharacter:@":" modifiers:0],
		nil],@"skipNext:",
		[NSArray arrayWithObjects:
			[CSKeyStroke keyForCharCode:NSPageUpFunctionKey modifiers:0],
			[CSKeyStroke keyForCharacter:@" " modifiers:CSShift],
			[CSKeyStroke keyForCharacter:@"," modifiers:0],
			[CSKeyStroke keyForCharacter:@";" modifiers:0],
		nil],@"skipPrev:",
		[NSArray arrayWithObjects:
			[CSKeyStroke keyForCharCode:NSHomeFunctionKey modifiers:0],
		nil],@"skipFirst:",
		[NSArray arrayWithObjects:
			[CSKeyStroke keyForCharCode:NSEndFunctionKey modifiers:0],
		nil],@"skipLast:",
		[NSArray arrayWithObjects:
			[CSKeyStroke keyForCharCode:NSPageDownFunctionKey modifiers:CSShift],
		nil],@"skip10Forward:",
		[NSArray arrayWithObjects:
			[CSKeyStroke keyForCharCode:NSPageDownFunctionKey modifiers:CSAlt],
		nil],@"skip100Forward:",
		[NSArray arrayWithObjects:
			[CSKeyStroke keyForCharCode:NSPageUpFunctionKey modifiers:CSShift],
		nil],@"skip10Back:",
		[NSArray arrayWithObjects:
			[CSKeyStroke keyForCharCode:NSPageUpFunctionKey modifiers:CSAlt],
		nil],@"skip100Back:",
		[NSArray arrayWithObjects:
			[CSKeyStroke keyForCharacter:@"r" modifiers:0],
		nil],@"skipRandom:",
		[NSArray arrayWithObjects:
			[CSKeyStroke keyForCharacter:@"R" modifiers:0],
		nil],@"skipRandomPrev:",
		[NSArray arrayWithObjects:
			[CSKeyStroke keyForCharacter:@"2" modifiers:0],
		nil],@"frameSkipNext:",
		[NSArray arrayWithObjects:
			[CSKeyStroke keyForCharacter:@"1" modifiers:0],
		nil],@"frameSkipPrev:",
		[NSArray arrayWithObjects:
			[CSKeyStroke keyForCharacter:@"a" modifiers:0],
			[CSKeyStroke keyForCharacter:@"3" modifiers:0],
		nil],@"toggleAnimation:",
		[NSArray arrayWithObjects:
			[CSKeyStroke keyForCharacter:@"+" modifiers:0],
			[CSKeyStroke keyForCharacter:@"=" modifiers:CSCmd],
			[CSKeyStroke keyForCharacter:@"=" modifiers:0],
		nil],@"zoomIn:",
		[NSArray arrayWithObjects:
			[CSKeyStroke keyForCharacter:@"-" modifiers:0],
		nil],@"zoomOut:",
		[NSArray arrayWithObjects:
			[CSKeyStroke keyForCharacter:@"*" modifiers:0],
		nil],@"zoomFit:",
		[NSArray arrayWithObjects:
			[CSKeyStroke keyForCharacter:@"/" modifiers:0],
		nil],@"zoomActual:",
		[NSArray arrayWithObjects:
			[CSKeyStroke keyForCharacter:@"f" modifiers:0],
			[CSKeyStroke keyForCharCode:NSCarriageReturnCharacter modifiers:CSAlt],
		nil],@"fullScreen:",
	nil]];

	[CSKeyboardShortcuts installWindowClass];
}

-(void)applicationDidFinishLaunching:(NSNotification *)notification
{
	if(!filesopened&&finderlaunch) [self openDocument:self];
}

-(BOOL)application:(NSApplication *)app openFile:(NSString *)filename
{
	filesopened=YES;

	if([[filename pathExtension] isEqual:@"xeeicons"]) // icon set
	{
		NSMutableAttributedString *icons=[[[NSMutableAttributedString alloc] init] autorelease];

		NSEnumerator *enumerator=[[self iconNames] objectEnumerator];
		NSString *iconname;
		while(iconname=[enumerator nextObject])
		{
			NSTextAttachment *attachment=[[[NSTextAttachment alloc] init] autorelease];
			NSCell *cell=(NSCell *)[attachment attachmentCell];
			NSImage *icon=[[[NSImage alloc] initWithContentsOfFile:[filename stringByAppendingPathComponent:iconname]] autorelease];
			[icon setScalesWhenResized:YES];
			[icon setSize:NSMakeSize(48,48)];
			[cell setImage:icon];
			[icons appendAttributedString:[NSMutableAttributedString attributedStringWithAttachment:attachment]];
		}

		if(!iconwindow)
		{
			NSNib *nib=[[[NSNib alloc] initWithNibNamed:@"IconSetWindow" bundle:nil] autorelease];
			[nib instantiateNibWithOwner:self topLevelObjects:nil];
		}


		[iconfield setAttributedStringValue:icons];
		[iconwindow makeKeyAndOrderFront:nil];

//		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];

		openediconset=[filename retain];

		return YES;
	}
	else
	{
		XeeFSRef *ref=[XeeFSRef refForPath:filename],*dirref;

		XeeImageSource *source=nil;
		if([ref isDirectory])
		{
			source=[[[XeeDirectorySource alloc] initWithDirectory:ref] autorelease];
			dirref=ref;
		}
		else
		{
			if(!source)
			{
				source=[[[XeePDFSource alloc] initWithFile:filename] autorelease];
				dirref=nil;
			}

			if(!source)
			{
				source=[[[XeeSWFSource alloc] initWithFile:filename] autorelease];
				dirref=nil;
			}

			if(!source)
			{
				XeeImage *image=[XeeImage imageForRef:ref];
				if(image)
				{
					source=[[[XeeDirectorySource alloc] initWithImage:image] autorelease];
					dirref=[ref parent];
				}
			}

			if(!source)
			{
				source=[[[XeeArchiveSource alloc] initWithArchive:filename] autorelease];
				dirref=nil;
			}

			if(!source)
			{
				source=[[[XeeDirectorySource alloc] initWithRef:ref] autorelease];
				dirref=[ref parent];
			}
		}

		XeeController *controller=[self controllerForDirectory:dirref];
		[controller setImageSource:source];
		[controller autoFullScreen];

		return YES;
	}
}



-(IBAction)openDocument:(id)sender
{
	NSMutableArray *types=[NSMutableArray array];
	[types addObjectsFromArray:[XeeImage allFileTypes]];
	[types addObjectsFromArray:[XeeArchiveSource fileTypes]];

	NSOpenPanel *panel=[NSOpenPanel openPanel];

	[panel setCanChooseDirectories:YES];

	int res=[panel runModalForTypes:types];

	if(res==NSOKButton)
	{
		[self application:[NSApplication sharedApplication] openFile:[[panel filenames] objectAtIndex:0]];
	}
}



-(void)menuNeedsUpdate:(NSMenu *)menu
{
	if(menu==openmenu) [self buildOpenMenu:menu];
	else if(menu==editmenu) [self updateEditMenu:menu];
	else if(menu==viewmenu) [self updateViewMenu:menu];
	else if(menu==sortmenu) [self updateSortMenu:menu];
	else if(menu==slideshowmenu) [self updateSlideshowMenu:menu];
}

-(BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent *)event target:(id *)target action:(SEL *)action
{
	return NO;
}



/*static int XeeAppCompare(id url1,id url2,void *context)
{
	NSString *app1=[[[url1 path] lastPathComponent] stringByDeletingPathExtension];
	NSString *app2=[[[url2 path] lastPathComponent] stringByDeletingPathExtension];
	return [app1 caseInsensitiveCompare:app2];
}*/

-(void)buildOpenMenu:(NSMenu *)menu
{
	while([menu numberOfItems]>2) [menu removeItemAtIndex:2];

	[self updateDefaultEditorItem];

	XeeController *focus=[self focusedController];

	NSString *filename=[focus currentFilename];
	NSArray *apps=[(NSArray *)LSCopyApplicationURLsForURL((CFURLRef)[NSURL fileURLWithPath:filename],kLSRolesEditor) autorelease];
	NSMenu *defmenu=[[[NSMenu alloc] init] autorelease];
	NSString *defeditor=[self defaultEditor];

	NSEnumerator *enumerator=[apps objectEnumerator];
//	NSEnumerator *enumerator=[[apps sortedArrayUsingFunction:XeeAppCompare context:nil] objectEnumerator];
	NSURL *appurl;

	while(appurl=[enumerator nextObject])
	{
		NSString *app=[appurl path];
		NSString *name=[[app lastPathComponent] stringByDeletingPathExtension];
		NSImage *image=[[NSWorkspace sharedWorkspace] iconForFile:app];

		if(![app isEqual:defeditor])
		{
			NSMenuItem *mainitem=[[[NSMenuItem alloc] initWithTitle:name action:@selector(launchAppFromMenu:) keyEquivalent:@""] autorelease];
			[mainitem setImage:image];
			[mainitem setRepresentedObject:app];
			[menu addItem:mainitem];
		}

		NSMenuItem *defitem=[[[NSMenuItem alloc] initWithTitle:name action:@selector(setDefaultEditorFromMenu:) keyEquivalent:@""] autorelease];
		[defitem setImage:image];
		[defitem setRepresentedObject:app];
		if([app isEqual:defeditor]) [defitem setState:NSOnState];
		[defmenu addItem:defitem];
	}

	[menu addItem:[NSMenuItem separatorItem]];

	NSMenuItem *defmenuitem=[[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Set Default Editor",@"Title of the default editor submenu")
	action:@selector(launchApp:) keyEquivalent:@""] autorelease];

	[defmenuitem setSubmenu:defmenu];
	[defmenuitem setAction:@selector(dummy:)];
	[menu addItem:defmenuitem];
}

-(void)dummy:(id)sender {}

-(void)updateDefaultEditorItem
{
	NSString *defeditor=[self defaultEditor];
	NSMenuItem *item=[openmenu itemAtIndex:0];

	if(defeditor)
	{
		[item setTitle:[[defeditor lastPathComponent] stringByDeletingPathExtension]];
		[item setImage:[[NSWorkspace sharedWorkspace] iconForFile:defeditor]];
	}
	else
	{
		[item setTitle:NSLocalizedString(@"No Default Editor Selected",@"Default editor menu title when no default editor has been selected")];
		[item setImage:nil];
	}
}

-(NSString *)defaultEditor
{
	NSString *defeditorid=[[NSUserDefaults standardUserDefaults] stringForKey:@"defaultEditor"];
	if(defeditorid) return [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:defeditorid];
	return nil;
}

-(void)setDefaultEditor:(NSString *)app
{
	[[NSUserDefaults standardUserDefaults] setObject:[[NSBundle bundleWithPath:app] bundleIdentifier] forKey:@"defaultEditor"];
}

-(IBAction)setDefaultEditorFromMenu:(id)sender
{
	[self setDefaultEditor:[sender representedObject]];
}



-(void)updateEditMenu:(NSMenu *)menu
{
	if([self xeeFocus])
	{
		[copyitem setTitle:NSLocalizedString(@"Copy Image",@"Alternate Copy menuitem for images")];
		[pasteitem setTitle:NSLocalizedString(@"Show Clipboard",@"Alternate Paste menuitem for images")];
	}
	else
	{
		[copyitem setTitle:NSLocalizedString(@"Copy",@"Copy button and menuitem")];
		[pasteitem setTitle:NSLocalizedString(@"Paste",@"Paste menuitem")];
	}

	XeeController *focus=[self focusedController];
	if([focus isCropping]) [cropitem setState:NSOnState];
	else [cropitem setState:NSOffState];
}

-(void)updateViewMenu:(NSMenu *)menu
{
	XeeController *focus=[self focusedController];
	if(focus)
	{
		[statusitem setTitle:[focus isStatusBarHidden]?
		NSLocalizedString(@"Show Status Bar",@"Menu item text for showing the status bar"):
		NSLocalizedString(@"Hide Status Bar",@"Menu item text for hiding the status bar")];
	}
}

-(void)updateSortMenu:(NSMenu *)menu
{
	int sortorder=0;

	XeeController *controller=[self focusedController];
	if(controller) sortorder=[[controller imageSource] sortOrder];

	int num=[sortmenu numberOfItems];
	for(int i=0;i<num;i++)
	{
		NSMenuItem *item=[sortmenu itemAtIndex:i];
		if([item tag]==sortorder) [item setState:NSOnState];
		else [item setState:NSOffState];
	}
	
}

-(void)updateSlideshowMenu:(NSMenu *)menu
{
	int slidedelay=[[NSUserDefaults standardUserDefaults] integerForKey:@"slideshowDelay"];

	BOOL found=NO;

	int num=[slideshowmenu numberOfItems];
	for(int i=0;i<num;i++)
	{
		NSMenuItem *item=[slideshowmenu itemAtIndex:i];
		if([item action]==@selector(setSlideshowDelay:))
		if([item tag]==slidedelay)
		{
			[item setState:NSOnState];
			found=YES;
		}
		else [item setState:NSOffState];
	}

	if(found)
	{
		[otherdelayitem setState:NSOffState];
		[otherdelayitem setTitle:NSLocalizedString(@"Other...","Menu item for other delay in slideshow menu when not selected")];
	}
	else
	{
		[otherdelayitem setState:NSOnState];
		[otherdelayitem setTitle:[NSString stringWithFormat:
		NSLocalizedString(@"Other (%d Seconds)...","Menu item for other delay in slideshow menu when selected"),
		slidedelay]];
	}

	XeeController *focus=[self focusedController];
	if(focus&&[focus isSlideshowRunning])
	[runslidesitem setState:NSOnState];
	else [runslidesitem setState:NSOffState];
}


-(BOOL)validateMenuItem:(NSMenuItem *)item
{
	if([item action]==@selector(paste:)) return [XeeClipboardSource canInitWithGeneralPasteboard];
	return YES;
}



-(IBAction)preferences:(id)sender
{
	if(!prefswindow)
	{
		NSNib *nib=[[[NSNib alloc] initWithNibNamed:@"PrefsWindow" bundle:nil] autorelease];
		[nib instantiateNibWithOwner:self topLevelObjects:nil];
	}
	[prefswindow makeKeyAndOrderFront:nil];
}

-(IBAction)paste:(id)sender
{
	XeeClipboardSource *source=[[[XeeClipboardSource alloc] initWithGeneralPasteboard] autorelease];
	if(source)
	{
		XeeController *controller=[self controllerForDirectory:nil];
		[controller setImageSource:source];
	}
}

-(IBAction)getInfo:(id)sender
{
	if(!properties)
	{
		NSNib *nib=[[[NSNib alloc] initWithNibNamed:@"PropertyPanel" bundle:nil] autorelease];
		[nib instantiateNibWithOwner:self topLevelObjects:nil];
	}
	[properties toggleVisibility];
}

-(IBAction)keyboardShortcuts:(id)sender
{
	if(!prefswindow)
	{
		NSNib *nib=[[[NSNib alloc] initWithNibNamed:@"PrefsWindow" bundle:nil] autorelease];
		[nib instantiateNibWithOwner:self topLevelObjects:nil];
	}
	[prefstabs selectTabViewItemAtIndex:1];
	[prefswindow makeKeyAndOrderFront:self];
}

-(IBAction)openSupportThread:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://wakaba.c3.cx/sup/kareha.pl/1132091963/"]];
}

-(IBAction)openBugReport:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://code.google.com/p/xee/issues/entry"]];
}

-(IBAction)openHomePage:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://wakaba.c3.cx/s/apps/xee.html"]];
}

-(IBAction)installIconSet:(id)sender
{
	NSString *resdir=[[NSBundle bundleForClass:[self class]] resourcePath];
	NSEnumerator *enumerator=[[self iconNames] objectEnumerator];
	NSString *iconname;
	while(iconname=[enumerator nextObject])
	{
		NSString *destname=[resdir stringByAppendingPathComponent:iconname];

		if(![[NSFileManager defaultManager] removeFileAtPath:destname handler:nil]
		||![[NSFileManager defaultManager] copyPath:[openediconset stringByAppendingPathComponent:iconname] toPath:destname handler:nil])
		{
			NSAlert *alert=[[[NSAlert alloc] init] autorelease];

			[alert setMessageText:NSLocalizedString(@"Icon Installation Failed",@"Title of the icon installation failure dialog")];
			[alert setInformativeText:NSLocalizedString(@"Couldn't copy the icon files into the application.",@"Content of the icon installation failure dialog")];
			[alert addButtonWithTitle:NSLocalizedString(@"OK","OK button")];

			[alert runModal];
			[iconwindow orderOut:nil];
			return;
		}
	}
	[iconwindow orderOut:nil];
}

-(void)windowWillClose:(NSNotification *)notification
{
	if([notification object]==iconwindow)
	{
		[iconfield setStringValue:@""];
		[openediconset release];
		openediconset=nil;
	}
}



-(IBAction)setAntialiasing:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setInteger:[(NSMenuItem *)sender tag] forKey:@"antialiasQuality"];

	NSMenu *menu=[sender menu];
	int num=[menu numberOfItems];
	for(int i=0;i<num;i++)
	{
		NSMenuItem *item=[menu itemAtIndex:i];
		[item setState:item==sender?NSOnState:NSOffState];
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:@"XeeRefreshImageNotification" object:nil];
}

-(IBAction)setUpscaling:(id)sender
{
	//[[NSUserDefaults standardUserDefaults] setBoolean:[sender state]==NSOnState forKey:@"upsampleImage"];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"XeeRefreshImageNotification" object:nil];
}
-(IBAction)alwaysFullscreenStub:(id)sender { }

-(IBAction)loopImagesStub:(id)sender { }

-(IBAction)randomOrderStub:(id)sender { }

-(IBAction)rememberZoomStub:(id)sender { }

-(IBAction)rememberFocusStub:(id)sender { }



-(XeeController *)controllerForDirectory:(XeeFSRef *)directory
{
	XeeController *focus=[self focusedController];
	if(focus&&[focus isFullscreen]) return focus;

	XeeController *controller=nil;
	int windowmode=[[NSUserDefaults standardUserDefaults] integerForKey:@"windowOpening"];
	switch(windowmode)
	{
		case 0: // single window
		{
			NSArray *keys=[controllers allKeys];
			if([keys count]>0) controller=[controllers objectForKey:[keys objectAtIndex:0]];
		}
		break;

		case 1:
		{
			if(!directory) break;
			controller=[controllers objectForKey:directory];
		}
		break;
	}

	if(!controller)
	{
		if(!browsernib) browsernib=[[NSNib alloc] initWithNibNamed:@"BrowserWindow" bundle:nil];

		windowcontroller=nil;
		[browsernib instantiateNibWithOwner:self topLevelObjects:nil];
		controller=windowcontroller;

		if(directory) [controllers setObject:controller forKey:directory];

		NSMutableSet *set=[NSMutableSet set];
		NSEnumerator *enumerator=[[NSApp windows] objectEnumerator];
		NSWindow *window;
		while(window=[enumerator nextObject]) if([window frameAutosaveName]) [set addObject:[window frameAutosaveName]];

		window=[controller window];
		int n=1;
		while([set containsObject:[NSString stringWithFormat:@"browserWindow%d",n]]) n++;

		[window setFrameAutosaveName:[NSString stringWithFormat:@"browserWindow%d",n]];
	}

	[[controller window] makeKeyAndOrderFront:self];

	return controller;
}

-(void)controllerWillExit:(XeeController *)controller
{
	NSArray *keys=[controllers allKeysForObject:controller];
	if(keys) [controllers removeObjectsForKeys:keys];
}


-(BOOL)xeeFocus
{
	NSWindow *win=[[NSApplication sharedApplication] keyWindow];
	if(!win) return YES;
	if(![win delegate]) return NO;
	if([[win delegate] isKindOfClass:[XeeController class]]) return YES;
	return NO;
}

-(XeeController *)focusedController
{
	id delegate=[[[NSApplication sharedApplication] mainWindow] delegate];
	if([delegate isKindOfClass:[XeeController class]]) return delegate;
	else return nil;
}

-(NSArray *)iconNames
{
	return [NSArray arrayWithObjects:
		@"Xee.icns",@"bmp.icns",@"crw.icns",@"dng.icns",
		@"exr.icns",@"fax.icns",@"fpx.icns",@"gif.icns",
		@"icns.icns",@"ico.icns",@"ilbm.icns",@"jp2.icns",
		@"jpeg.icns",@"pcx.icns",@"pic.icns",@"pict.icns",
		@"png.icns",@"pntg.icns",@"psd.icns",@"qtif.icns",
		@"sgi.icns",@"tga.icns",@"tiff.icns",@"xbm.icns",
	nil];
}

-(XeePropertiesController *)propertiesController { return properties; }

-(CSAction **)copyAndMoveActions { return actions; }

@end



BOOL IsHoveredViewOfClass(NSEvent *event,Class class);

@implementation XeeApplication

-(void)sendEvent:(NSEvent *)event
{
	int type=[event type];
	if(type==NSScrollWheel||type==NSEventTypeBeginGesture||type==NSEventTypeEndGesture||
	type==NSEventTypeMagnify||type==NSEventTypeRotate||type==NSEventTypeSwipe)
	{
		id keydelegate=[[NSApp keyWindow] delegate];
		if(keydelegate && [keydelegate isKindOfClass:[XeeController class]])
		{
			XeeController *controller=keydelegate;

			if(type==NSScrollWheel)
			{
				if(!IsHoveredViewOfClass(event,[NSTableView class]))
				[controller scrollWheel:event];
			}
			else if(type==NSEventTypeBeginGesture)
			{
				[controller beginGestureWithEvent:event];
			}
			else if(type==NSEventTypeEndGesture)
			{
				[controller endGestureWithEvent:event];
			}
			else if(type==NSEventTypeMagnify)
			{
				[controller magnifyWithEvent:event];
			}
			else if(type==NSEventTypeRotate)
			{
				[controller rotateWithEvent:event];
			}
			else if(type==NSEventTypeSwipe)
			{
				[controller swipeWithEvent:event];
			}
		}
	}

	[super sendEvent:event];
}

BOOL IsHoveredViewOfClass(NSEvent *event,Class class)
{
	NSWindow *window=[event window];
	if(window)
	{
		NSView *content=[window contentView];
		NSPoint mouse=[content convertPoint:[window mouseLocationOutsideOfEventStream] fromView:nil];
		NSView *hit=[content hitTest:mouse];

		if(hit&&[hit isKindOfClass:class]) return YES;
	}
	return NO;
}

@end
