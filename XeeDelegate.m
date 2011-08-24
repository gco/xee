#import "XeeDelegate.h"
#import "XeeController.h"
#import "XeeDirectoryController.h"
#import "XeePropertiesController.h"
#import "XeeKeyboardShortcuts.h"

#import "XeeImageIOLoader.h"
#import "XeeQuicktimeLoader.h"
#import "XeeJPEGLoader.h"
#import "XeePNGLoader.h"
#import "XeeGIFLoader.h"
#import "XeePhotoshopLoader.h"
#import "XeePCXLoader.h"
#import "XeeILBMLoader.h"
#import "XeeMayaLoader.h"

#import "XeeCGImageSaver.h"
#import "XeeLosslessSaver.h"



XeeDelegate *maindelegate=nil;


@implementation XeeDelegate

-(id)init
{
	if(self=[super init])
	{
		filesopened=NO;
		shortcuts=nil;
		openediconset=nil;
		properties=nil;
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
	[XeeImage registerImageClass:[XeeILBMImage class]];
	[XeeImage registerImageClass:[XeePCXImage class]];
	[XeeImage registerImageClass:[XeeMayaImage class]];
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

	[[antialiasmenu itemWithTag:[[NSUserDefaults standardUserDefaults] integerForKey:@"antialiasQuality"]] setState:NSOnState];

	[shortcuts addActionsFromMenu:[[NSApplication sharedApplication] mainMenu]];
	[shortcuts addActions:[NSArray arrayWithObjects:
		[XeeAction actionWithTitle:NSLocalizedString(@"Close window or drawer",@"Action name for the keyboard shortcut for closing the current window, or open drawer")
		selector:@selector(closeWindowOrDrawer:)],
		[XeeAction actionWithTitle:NSLocalizedString(@"Delete after confirmation",@"Action name for the keyboard shortcut for deleting the current image (after a confirmation dialog)")
		selector:@selector(askAndDelete:)],
	0]];
	[shortcuts addShortcuts:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSArray arrayWithObjects:
			[XeeKeyStroke keyForCharCode:27 modifiers:0],
		0],@"closeWindowOrDrawer:",
		[NSArray arrayWithObjects:
			[XeeKeyStroke keyForCharCode:127 modifiers:0],
			[XeeKeyStroke keyForCharCode:63272 modifiers:0],
		0],@"askAndDelete:",
		[NSArray arrayWithObjects:
			[XeeKeyStroke keyForCharCode:NSPageDownFunctionKey modifiers:0],
			[XeeKeyStroke keyForCharacter:@" " modifiers:0],
			[XeeKeyStroke keyForCharacter:@"." modifiers:0],
			[XeeKeyStroke keyForCharacter:@":" modifiers:0],
		0],@"skipNext:",
		[NSArray arrayWithObjects:
			[XeeKeyStroke keyForCharCode:NSPageUpFunctionKey modifiers:0],
			[XeeKeyStroke keyForCharacter:@" " modifiers:XeeShift],
			[XeeKeyStroke keyForCharacter:@"," modifiers:0],
			[XeeKeyStroke keyForCharacter:@";" modifiers:0],
		0],@"skipPrev:",
		[NSArray arrayWithObjects:
			[XeeKeyStroke keyForCharCode:NSHomeFunctionKey modifiers:0],
		0],@"skipFirst:",
		[NSArray arrayWithObjects:
			[XeeKeyStroke keyForCharCode:NSEndFunctionKey modifiers:0],
		0],@"skipLast:",
		[NSArray arrayWithObjects:
			[XeeKeyStroke keyForCharCode:NSPageDownFunctionKey modifiers:XeeShift],
		0],@"skip10Forward:",
		[NSArray arrayWithObjects:
			[XeeKeyStroke keyForCharCode:NSPageDownFunctionKey modifiers:XeeAlt],
		0],@"skip100Forward:",
		[NSArray arrayWithObjects:
			[XeeKeyStroke keyForCharCode:NSPageUpFunctionKey modifiers:XeeShift],
		0],@"skip10Back:",
		[NSArray arrayWithObjects:
			[XeeKeyStroke keyForCharCode:NSPageUpFunctionKey modifiers:XeeAlt],
		0],@"skip100Back:",
		[NSArray arrayWithObjects:
			[XeeKeyStroke keyForCharacter:@"r" modifiers:0],
		0],@"skipRandom:",
		[NSArray arrayWithObjects:
			[XeeKeyStroke keyForCharacter:@"R" modifiers:0],
		0],@"skipRandomPrev:",
		[NSArray arrayWithObjects:
			[XeeKeyStroke keyForCharacter:@"2" modifiers:0],
		0],@"frameSkipNext:",
		[NSArray arrayWithObjects:
			[XeeKeyStroke keyForCharacter:@"1" modifiers:0],
		0],@"frameSkipPrev:",
		[NSArray arrayWithObjects:
			[XeeKeyStroke keyForCharacter:@"3" modifiers:0],
		0],@"toggleAnimation:",
		[NSArray arrayWithObjects:
			[XeeKeyStroke keyForCharacter:@"+" modifiers:0],
			[XeeKeyStroke keyForCharacter:@"=" modifiers:XeeCmd],
			[XeeKeyStroke keyForCharacter:@"=" modifiers:0],
		0],@"zoomIn:",
		[NSArray arrayWithObjects:
			[XeeKeyStroke keyForCharacter:@"-" modifiers:0],
		0],@"zoomOut:",
		[NSArray arrayWithObjects:
			[XeeKeyStroke keyForCharacter:@"*" modifiers:0],
		0],@"zoomFit:",
		[NSArray arrayWithObjects:
			[XeeKeyStroke keyForCharacter:@"/" modifiers:0],
		0],@"zoomActual:",
		[NSArray arrayWithObjects:
			[XeeKeyStroke keyForCharacter:@"f" modifiers:0],
			[XeeKeyStroke keyForCharCode:13 modifiers:XeeAlt],
		0],@"fullScreen:",
	0]];
	[shortcuts installWindowClass];
}

-(XeeKeyboardShortcuts *)shortcuts { return shortcuts; }



-(void)applicationDidFinishLaunching:(NSNotification *)notification
{
	if(!filesopened) [self openDocument:self];
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
		[iconfield setAttributedStringValue:icons];
		[iconwindow makeKeyAndOrderFront:nil];

//		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];

		openediconset=[filename retain];

		return YES;
	}
	else
	{
		int windowmode=[[NSUserDefaults standardUserDefaults] integerForKey:@"windowOpening"];

		switch(windowmode)
		{
			case 0: // single window
			{
				NSArray *controllers=[XeeDirectoryController controllers];

				if([controllers count]>0)
				{
					XeeDirectoryController *controller=[controllers objectAtIndex:0];

					[[controller window] makeKeyAndOrderFront:self];
					return [controller loadImage:filename];
				}
			}
			break;

			case 1:
			{
				NSString *directory=[filename stringByDeletingLastPathComponent];
				NSArray *controllers=[XeeDirectoryController controllers];
				NSEnumerator *enumerator=[controllers objectEnumerator];
				XeeDirectoryController *controller;

				while(controller=[enumerator nextObject])
				{
					if([[controller directory] isEqual:directory])
					{
						[[controller window] makeKeyAndOrderFront:self];
						return [controller loadImage:filename];
					}
				}
			}
			break;

			case 2:
				// fall through
			break;
		}

		XeeDirectoryController *controller=[self newDirectoryWindow];
		return [controller loadImage:filename];
	}
}

-(IBAction)openDocument:(id)sender
{
	NSOpenPanel *panel=[NSOpenPanel openPanel];

	[panel setCanChooseDirectories:YES];

	int res=[panel runModalForTypes:[XeeImage fileTypes]];

	if(res==NSOKButton)
	{
		[self application:[NSApplication sharedApplication] openFile:[[panel filenames] objectAtIndex:0]];
	}
}

-(XeeDirectoryController *)newDirectoryWindow
{
	if(!directorynib) directorynib=[[NSNib alloc] initWithNibNamed:@"XeeDirectoryWindow" bundle:nil];
	return [self instantiateWindowFromNib:directorynib];
}

-(XeeController *)newClipboardWindow
{
	if(!clipboardnib) clipboardnib=[[NSNib alloc] initWithNibNamed:@"XeeClipboardWindow" bundle:nil];

	return [self instantiateWindowFromNib:clipboardnib];
}

-(id)instantiateWindowFromNib:(NSNib *)nib
{
	windowcontroller=nil;
	[nib instantiateNibWithOwner:self topLevelObjects:nil];

	[[windowcontroller window] makeKeyAndOrderFront:self];

	return windowcontroller;
}



-(void)menuNeedsUpdate:(NSMenu *)menu
{
	if(menu==openmenu) [self buildOpenMenu:menu];
	else if(menu==editmenu) [self updateEditMenu:menu];
	else if(menu==viewmenu) [self updateViewMenu:menu];
}

-(BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent *)event target:(id *)target action:(SEL *)action
{
	return NO;
}

static int appcomp(id url1,id url2,void *context)
{
	NSString *app1=[[[url1 path] lastPathComponent] stringByDeletingPathExtension];
	NSString *app2=[[[url2 path] lastPathComponent] stringByDeletingPathExtension];
	return [app1 caseInsensitiveCompare:app2];
}

-(void)buildOpenMenu:(NSMenu *)menu
{
	while([menu numberOfItems]>2) [menu removeItemAtIndex:2];

	[self updateDefaultEditorItem];

	NSWindow *window=[[NSApplication sharedApplication] keyWindow];
	if(!window) return;

	NSString *filename=[[window delegate] currentFilename];
	NSArray *apps=[(NSArray *)LSCopyApplicationURLsForURL((CFURLRef)[NSURL fileURLWithPath:filename],kLSRolesEditor) autorelease];
	NSMenu *defmenu=[[[NSMenu alloc] init] autorelease];
	NSString *defeditor=[self defaultEditor];

	NSEnumerator *enumerator=[apps objectEnumerator];
//	NSEnumerator *enumerator=[[apps sortedArrayUsingFunction:appcomp context:nil] objectEnumerator];
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
}

-(void)updateViewMenu:(NSMenu *)menu
{
	XeeController *controller=[[[NSApplication sharedApplication] keyWindow] delegate];

	if(controller&&[controller isKindOfClass:[XeeController class]])
	{
		[statusitem setTitle:[controller isStatusBarHidden]?
		NSLocalizedString(@"Show Status Bar",@"Menu item text for showing the status bar"):
		NSLocalizedString(@"Hide Status Bar",@"Menu item text for hiding the status bar")];
	}
}

-(BOOL)validateMenuItem:(id <NSMenuItem>)item
{
	if([item action]==@selector(paste:)) return [self canPaste];
	return YES;
}

-(BOOL)xeeFocus
{
	NSWindow *win=[[NSApplication sharedApplication] keyWindow];
	if(!win) return YES;
	if(![win delegate]) return NO;
	if([[win delegate] isKindOfClass:[XeeController class]]) return YES;
	return NO;
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


-(BOOL)canPaste
{
	NSString *type=[[NSPasteboard generalPasteboard] availableTypeFromArray:[NSArray arrayWithObjects:NSTIFFPboardType,NSPICTPboardType,nil]];
	return type?YES:NO;
}

-(IBAction)paste:(id)sender
{
	NSPasteboard *pboard=[NSPasteboard generalPasteboard];
	NSString *type=[pboard availableTypeFromArray:[NSArray arrayWithObjects:NSTIFFPboardType,NSPICTPboardType,nil]];
	XeeImage *image=nil;

	if([type isEqual:NSTIFFPboardType])
	{
		image=[[XeeImageIOImage alloc] initWithPasteboard:pboard];
	}
	else if([type isEqual:NSPICTPboardType])
	{
		CGDataProviderRef provider=CGDataProviderCreateWithCFData((CFDataRef)[pboard dataForType:NSPICTPboardType]);

		if(provider)
		{
			QDPictRef pict=QDPictCreateWithProvider(provider);
			if(pict)
			{
				CGRect rect=QDPictGetBounds(pict);
				int width=CGRectGetWidth(rect);
				int height=CGRectGetHeight(rect);

				XeeBitmapImage *bmimage=[[XeeBitmapImage alloc] initWithType:XeeBitmapTypePremultipliedARGB8 width:width height:height];
				if(bmimage)
				{
					image=bmimage;
					CGContextRef context=[bmimage createContext];
					if(context)
					{
						QDPictDrawToCGContext(context,CGRectMake(0,0,width,height),pict);
						CGContextRelease(context);
						[bmimage setCompleted];
					}
				}
				QDPictRelease(pict);
			}
			CGDataProviderRelease(provider);
		}
	}

	if(image)
	{
		XeeController *controller=[self newClipboardWindow];
		[controller setImage:image];
		[image release];
	}
	else NSBeep();
}

-(IBAction)setAntialiasing:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setInteger:[sender tag] forKey:@"antialiasQuality"];

	NSMenu *menu=[sender menu];
	int num=[menu numberOfItems];
	for(int i=0;i<num;i++)
	{
		NSMenuItem *item=[menu itemAtIndex:i];
		[item setState:item==sender?NSOnState:NSOffState];
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:@"XeeUpdateAllImages" object:nil];
}

-(IBAction)getInfo:(id)sender
{
	if(!properties)
	{
		NSNib *nib=[[NSNib alloc] initWithNibNamed:@"PropertyPanel" bundle:nil];
		[nib instantiateNibWithOwner:self topLevelObjects:nil];
	}

	[properties show];
}



-(IBAction)keyboardShortcuts:(id)sender
{
	[prefstabs selectTabViewItemAtIndex:1];
	[prefswindow makeKeyAndOrderFront:self];
}

-(IBAction)openSupportThread:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://wakaba.c3.cx/sup/kareha.pl/1132091963/"]];
}

-(IBAction)openHomePage:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://wakaba.c3.cx/"]];
}



-(IBAction)dummy:(id)sender { }



@end



@implementation XeeApplication

-(void)sendEvent:(NSEvent *)event
{
	if([event type]==NSScrollWheel)
	{
		NSWindow *window=[self keyWindow];
		NSPoint mouse=[NSEvent mouseLocation];

//		if(NSPointInRect(mouse,[window frame])) goto keiji;

		NSEnumerator *enumerator=[[window drawers] objectEnumerator];
		NSDrawer *drawer;

		while(drawer=[enumerator nextObject])
		{
			if(NSPointInRect(mouse,[[[drawer contentView] window] frame])) goto keiji;
		}

		if([[window delegate] respondsToSelector:@selector(scrollWheel:)]) [[window delegate] scrollWheel:event];
	}

	keiji:
	[super sendEvent:event];
}

@end
