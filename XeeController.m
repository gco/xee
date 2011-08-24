#import "XeeController.h"
#import "XeeView.h"
#import "XeeTool.h"
#import "XeeImage.h"
#import "XeeSavePanel.h"
#import "XeeSimpleLayout.h"
#import "XeeStatusBar.h"
#import "XeeSegmentedItem.h"



// XeeController

@implementation XeeController

static float zoomlevels[]={0.03125,0.044,0.0625,0.09,0.125,0.18,0.25,0.35,0.5,0.70,1,1.5,2,3,4,6,8,11,16,23,32};
static int num_zoom=21;

-(id)init
{
	if(self=[super init])
	{
		currimage=nil;
		toolbar=nil;
		toolbaritems=nil;
		toolbaridentifiers=nil;
		defaultidentifiers=nil;

		movetool=nil;
		croptool=nil;

		fullscreenwindow=nil;
		fullscreenview=nil;

		copiedcgimage=NULL;

		blocked=NO;

		undo=[[NSUndoManager alloc] init];
	}
    return self;
}

-(void)dealloc
{
	[currimage release];

	[toolbar release];
	[toolbaritems release];
	[toolbaridentifiers release];
	[defaultidentifiers release];

	[window release];
	[fullscreenwindow release];

	[movetool release];
	[croptool release];

	[undo release];

	CGImageRelease(copiedcgimage);

	[super dealloc];
}

-(void)awakeFromNib
{
	[self setupStatusBar];
	[self setStatusBarHidden:[[NSUserDefaults standardUserDefaults] boolForKey:[@"hideStatusBar." stringByAppendingString:[[self class] description]]]];

	[self updateWindowPosition];

	[self setupToolbarItems];
	if(toolbaritems)
	{
		toolbar=[[NSToolbar alloc] initWithIdentifier:[[self class] description]];
		[toolbar setDelegate:self];
		[toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
		[toolbar setAllowsUserCustomization:YES];
		[toolbar setAutosavesConfiguration:YES];
		[window setToolbar:toolbar];
	}

	movetool=[[XeeMoveTool alloc] initWithView:imageview];
	croptool=[[XeeCropTool alloc] initWithView:imageview];
	[imageview setTool:movetool];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateAllImages:) name:@"XeeUpdateAllImages" object:nil];
}

-(void)dismantle
{
	[self setImage:NULL];
	[self release];
}


-(void)windowWillClose:(NSNotification *)notification
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"XeeFrontImageDidChangeNotification" object:nil];
	[self performSelector:@selector(dismantle) withObject:nil afterDelay:0];
}

-(void)windowDidBecomeMain:(NSNotification *)notification
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"XeeFrontImageDidChangeNotification" object:currimage];
}

-(void)windowDidResignMain:(NSNotification *)notification
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"XeeFrontImageDidChangeNotification" object:nil];
}

-(void)windowDidMove:(NSNotification *)notification
{
	if([notification object]!=window) return;
	[self updateWindowPosition];
}

-(void)windowDidResize:(NSNotification *)notification
{
	if([notification object]!=window) return;
	[self updateWindowPosition];
}

-(void)windowWillMiniaturize:(NSNotification *)notification
{
	if([notification object]!=window) return;
	[imageview copyGLtoQuartz];
	[window setOpaque:NO]; // required to make the Quartz underlay and the window shadow appear correctly
}

-(void)windowDidMiniaturize:(NSNotification *)notification
{
	if([notification object]!=window) return;
	[window setOpaque:YES];
}

-(NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender
{
	return undo;
}



-(void)updateAllImages:(NSNotification *)notification
{
	[imageview invalidate];
}

-(void)xeeView:(XeeView *)view imageDidChange:(XeeImage *)image
{
	[self updateStatusBar];
}

-(void)xeeView:(XeeView *)view imageSizeDidChange:(XeeImage *)image
{
	NSSize newsize=NSMakeSize(zoom*(float)[currimage width],zoom*(float)[currimage height]);

	[self setImageSize:newsize];
	[imageview setFocus:NSMakePoint(0,0)];

	[imageview setNeedsDisplay:YES];
	[self updateStatusBar];
}

-(void)xeeView:(XeeView *)view imagePropertiesDidChange:(XeeImage *)image
{
	if([[NSApplication sharedApplication] keyWindow]==window&&image==currimage)
	[[NSNotificationCenter defaultCenter] postNotificationName:@"XeeFrontImageDidChangeNotification" object:image];
}



-(NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)flag 
{
	return [toolbaritems objectForKey:identifier];
}

-(NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
	return toolbaridentifiers;
}

-(NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
	if(!defaultidentifiers) defaultidentifiers=[[self makeDefaultToolbarItemIdentifiers] retain];
	return defaultidentifiers;
}

-(void)setupToolbarItems
{
	NSArray *items=[self makeToolbarItems];
	if(!items) return;

	NSEnumerator *enumerator;
	NSToolbarItem *item;

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithCapacity:[items count]];

	enumerator=[items objectEnumerator];
	while(item=[enumerator nextObject]) [dict setObject:item forKey:[item itemIdentifier]];
	toolbaritems=[[NSDictionary alloc] initWithDictionary:dict];

	NSMutableArray *array=[NSMutableArray arrayWithCapacity:[items count]+3];

	enumerator=[items objectEnumerator];
	while(item=[enumerator nextObject]) [array addObject:[item itemIdentifier]];
	[array addObject:NSToolbarSeparatorItemIdentifier];
	[array addObject:NSToolbarSpaceItemIdentifier];
	[array addObject:NSToolbarFlexibleSpaceItemIdentifier];
	toolbaridentifiers=[[NSArray alloc] initWithArray:array];
}

-(NSArray *)makeToolbarItems { return nil; }

-(NSArray *)makeDefaultToolbarItemIdentifiers { return nil; }



-(BOOL)validateMenuItem:(id <NSMenuItem>)item
{
	return [self validateAction:[item action]];
}

-(BOOL)validateAction:(SEL)action
{
	if(action==@selector(saveImage:)) return currimage&&[currimage completed];
	else if(action==@selector(toggleAnimation:)) return currimage&&[currimage animated];
	else if(action==@selector(frameSkipNext:)) return currimage&&[currimage frames]>1;
	else if(action==@selector(frameSkipPrev:)) return currimage&&[currimage frames]>1;
	else if(action==@selector(zoomIn:)) return currimage&&zoom<zoomlevels[num_zoom-1];
	else if(action==@selector(zoomOut:)) return currimage&&zoom>zoomlevels[0];
	else if(action==@selector(zoomActual:)) return currimage&&zoom!=1;
	else if(action==@selector(zoomFit:)) return currimage?YES:NO; //eek, no proper validation
	else if(action==@selector(toggleStatusBar:)) return fullscreenwindow?NO:YES;
	else if(action==@selector(autoRotate:)) return currimage&&[currimage correctOrientation];

	else return YES;
}



-(void)setupStatusBar { }

-(void)updateStatusBar { }

-(void)setStatusBarHidden:(BOOL)hidden
{
	NSRect imageframe=[imageview frame];
	NSRect statusframe=[statusbar frame];

	if([statusbar isHidden])
	{
		if(hidden) return;
		[statusbar setHidden:NO];
		imageframe.size.height-=statusframe.size.height;
		imageframe.origin.y+=statusframe.size.height;
		[imageview setFrame:imageframe];
		[imageview setDrawResizeCorner:NO];
	}
	else
	{
		if(!hidden) return;
		[statusbar setHidden:YES];
		imageframe.size.height+=statusframe.size.height;
		imageframe.origin.y-=statusframe.size.height;
		[imageview setFrame:imageframe];
		[imageview setDrawResizeCorner:YES];
	}
}

-(BOOL)isStatusBarHidden
{
	return [statusbar isHidden];
}

-(IBAction)toggleStatusBar:(id)sender
{
	BOOL newstate=![statusbar isHidden];
	NSEnumerator *enumerator=[[[NSApplication sharedApplication] windows] objectEnumerator];
	NSWindow *win;

	while(win=[enumerator nextObject])
	{
		id delegate=[win delegate];
		if([delegate class]==[self class]) [delegate setStatusBarHidden:newstate];
	}

	[[NSUserDefaults standardUserDefaults] setBool:newstate forKey:[@"hideStatusBar." stringByAppendingString:[[self class] description]]];
}



-(XeeDisplayWindow *)window { return window; }

-(XeeFullScreenWindow *)fullScreenWindow { return fullscreenwindow; }

-(XeeImage *)image { return currimage; }



-(void)setImage:(XeeImage *)image
{
	if(image!=currimage)
	{
		[currimage release];
		currimage=[image retain];
	}

	XeeView *view=fullscreenwindow?fullscreenview:imageview;

	if(currimage)
	{
		[currimage setFrame:0];
		[currimage resetTransformations];

		[view setImage:currimage];
		[self setStandardImageSize];
	}
	else
	{
		[view setImage:nil];
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:@"XeeFrontImageDidChangeNotification" object:currimage];
	[self updateStatusBar];

	[undo removeAllActions];
}

-(void)setZoom:(float)newzoom
{
	if(!currimage) return;

	NSSize newsize=NSMakeSize(floor(newzoom*(float)[currimage width]+0.5),floor(newzoom*(float)[currimage height]+0.5));
	[self setImageSize:newsize];

	zoom=newzoom;

	[self updateStatusBar];
}

-(void)setFrame:(int)frame
{
	if(!currimage) return;
	if(frame==[currimage frame]) return;
	if([currimage frames]==0) return;

	[currimage setFrame:frame];
}

-(void)updateWindowPosition
{
	NSRect windowframe=[window frame];
	window_focus_x=windowframe.origin.x+windowframe.size.width/2;
	window_focus_y=windowframe.origin.y+windowframe.size.height/2;
}

-(void)setImageSize:(NSSize)size { [self setImageSize:size resetFocus:NO]; }

-(void)setImageSize:(NSSize)size resetFocus:(BOOL)reset
{
	XeeView *view=fullscreenwindow?fullscreenview:imageview;

	[view setImageSize:size];
	if(reset) [view setFocus:NSMakePoint(0,0)];

	if([self isResizeBlocked])
	{
		[self setResizeBlock:NO];
		return;
	}

	if(fullscreenwindow) return;

	NSRect screenframe=[self availableScreenSpace];
	NSRect windowframe=[window frame];
	NSSize viewsize=[imageview bounds].size;
	NSSize minsize=[self minViewSize];

	if(size.width<minsize.width) size.width=minsize.width;
	if(size.height<minsize.height) size.height=minsize.height;

	int borderwidth=windowframe.size.width-viewsize.width;
	int borderheight=windowframe.size.height-viewsize.height;
	int win_width=size.width+borderwidth;
	int win_height=size.height+borderheight;

	if(win_width>screenframe.size.width) win_width=screenframe.size.width;
	if(win_height>screenframe.size.height) win_height=screenframe.size.height;

	int focus_x=window_focus_x;
	int focus_y=window_focus_y;
	int win_x=window_focus_x-win_width/2;
	int win_y=window_focus_y-win_height/2;

	if(win_x<screenframe.origin.x) win_x=screenframe.origin.x;
	if(win_y<screenframe.origin.y) win_y=screenframe.origin.y;
	if(win_x+win_width>screenframe.origin.x+screenframe.size.width) win_x=screenframe.origin.x+screenframe.size.width-win_width;
	if(win_y+win_height>screenframe.origin.y+screenframe.size.height) win_y=screenframe.origin.y+screenframe.size.height-win_height;

//	int width=win_width-borderwidth;
//	int height=win_height-borderheight;
//	[imageview setFocus:focus];

	[window setFrame:NSMakeRect(win_x,win_y,win_width,win_height) display:YES];
	[window invalidateCursorRectsForView:imageview]; // just to make sure

	if(reset) [view setFocus:NSMakePoint(0,0)];

	window_focus_x=focus_x; // make sure we remember the old position
	window_focus_y=focus_y;
}

-(void)setStandardImageSize
{
	NSSize maxsize=[self maxViewSize];

	BOOL shrink=[[NSUserDefaults standardUserDefaults] boolForKey:@"shrinkToFit"];
	BOOL enlarge=[[NSUserDefaults standardUserDefaults] boolForKey:@"enlargeToFit"];

	float horiz_zoom=maxsize.width/(float)[currimage width];
	float vert_zoom=maxsize.height/(float)[currimage height];
	float min_zoom=horiz_zoom<vert_zoom?horiz_zoom:vert_zoom;

	zoom=1;
	if(shrink&&min_zoom<1) zoom=min_zoom;
	if(enlarge&&min_zoom>1) zoom=min_zoom;

	NSSize newsize=NSMakeSize(zoom*(float)[currimage width],zoom*(float)[currimage height]);

	[self setImageSize:newsize resetFocus:YES];
}

-(void)setResizeBlock:(BOOL)block { blocked=block; }

-(void)setResizeBlockFromSender:(id)sender
{
	if(sender&&[sender isKindOfClass:[NSToolbarItem class]]) [self setResizeBlock:YES];
	else [self setResizeBlock:NO];
}

-(BOOL)isResizeBlocked
{
	switch([[NSUserDefaults standardUserDefaults] integerForKey:@"windowResizing"])
	{
		case 1: return blocked;
		case 2: return YES;
		default: return NO;
	}
}

-(NSSize)maxViewSize
{
	if(fullscreenwindow)
	{
		return [fullscreenwindow frame].size;
	}
	else if([self isResizeBlocked])
	{
		return [imageview bounds].size;
	}
	else
	{
		NSSize screensize=[self availableScreenSpace].size;
		NSSize windowsize=[window frame].size;
		NSSize viewsize=[imageview bounds].size;

		return NSMakeSize(screensize.width-windowsize.width+viewsize.width,screensize.height-windowsize.height+viewsize.height);
	}
}

-(NSSize)minViewSize
{
	return NSMakeSize(256,128);
}

-(NSRect)availableScreenSpace
{
	return [[window screen] visibleFrame];
}




-(IBAction)copy:(id)sender
{
	if(currimage)
	{
		[[NSPasteboard generalPasteboard] declareTypes:
		[NSArray arrayWithObjects:NSTIFFPboardType,NSPICTPboardType,nil] owner:self];
//		[NSArray arrayWithObjects:NSTIFFPboardType,nil] owner:self];

		[self retain];
		copiedcgimage=[currimage makeCGImage];
	}
}

-(void)pasteboard:(NSPasteboard *)pboard provideDataForType:(NSString *)type
{
	// BUG: PS does not read the PICT alpha correctly. Write custom PICT code?
	if(!copiedcgimage) { NSBeep(); return; }

	CFStringRef uti;
	if([type isEqual:NSTIFFPboardType]) uti=kUTTypeTIFF;
	else if([type isEqual:NSPICTPboardType]) uti=kUTTypePICT;
	else return;

	NSMutableData *data=[NSMutableData data];
	if(!data) { NSBeep(); return; }

	CGImageDestinationRef dest=CGImageDestinationCreateWithData((CFMutableDataRef)data,uti,1,NULL);
	if(!dest) { NSBeep(); return; }

	CGImageDestinationAddImage(dest,copiedcgimage,NULL);
	CGImageDestinationFinalize(dest);

	CFRelease(dest);

	if([type isEqual:NSPICTPboardType]) [pboard setData:[data subdataWithRange:NSMakeRange(512,[data length]-512)] forType:type];
	else [pboard setData:data forType:type];
}

-(void)pasteboardChangedOwner:(NSPasteboard *)pboard
{
	CGImageRelease(copiedcgimage);
	copiedcgimage=NULL;
	[self release];
}

-(IBAction)saveImage:(id)sender
{
	if(currimage&&[currimage completed]) [XeeSavePanel runSavePanelForImage:currimage window:fullscreenwindow?nil:window];
}



-(IBAction)frameSkipNext:(id)sender
{
	[self setResizeBlockFromSender:sender];
	if(currimage)
	{
		int frame=[currimage frame];
		int frames=[currimage frames];
		[self setFrame:(frame+1)%frames];
	}
}

-(IBAction)frameSkipPrev:(id)sender
{
	[self setResizeBlockFromSender:sender];
	if(currimage)
	{
		int frame=[currimage frame];
		int frames=[currimage frames];
		[self setFrame:(frame+frames-1)%frames];
	}
}

-(IBAction)toggleAnimation:(id)sender
{
	if(!currimage||![currimage animated]) return;

	[currimage setAnimating:![currimage animating]];
}



-(IBAction)zoomIn:(id)sender
{
	[self setResizeBlockFromSender:sender];

	int i;
	for(i=0;i<num_zoom-1;i++) if(zoomlevels[i]>zoom) break;

	[self setZoom:zoomlevels[i]];
}

-(IBAction)zoomOut:(id)sender
{
	[self setResizeBlockFromSender:sender];

	int i;
	for(i=num_zoom-1;i>0;i--) if(zoomlevels[i]<zoom) break;

	[self setZoom:zoomlevels[i]];
}

-(IBAction)zoomActual:(id)sender
{
	[self setResizeBlockFromSender:sender];

	[self setZoom:1];
}

-(IBAction)zoomFit:(id)sender
{
	[self setResizeBlockFromSender:sender];

	NSSize maxsize=[self maxViewSize];

	float horiz_zoom=maxsize.width/(float)[currimage width];
	float vert_zoom=maxsize.height/(float)[currimage height];

	[self setZoom:horiz_zoom<vert_zoom?horiz_zoom:vert_zoom];
}

-(IBAction)setAutoZoom:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[self setStandardImageSize];
}



-(void)setOrientation:(XeeTransformation)orientation
{
	[[undo prepareWithInvocationTarget:self] setOrientation:[currimage orientation]];
	[currimage setOrientation:orientation];
}

-(IBAction)rotateCW:(id)sender
{
	if(!currimage) return;
	[self setResizeBlockFromSender:sender];
	[self setOrientation:XeeCombineTransformations([currimage orientation],XeeRotateCWTransformation)];
	[undo setActionName:NSLocalizedString(@"Rotate Clockwise",@"Rotate Clockwise undo label")];
}

-(IBAction)rotateCCW:(id)sender
{
	if(!currimage) return;
	[self setResizeBlockFromSender:sender];
	[self setOrientation:XeeCombineTransformations([currimage orientation],XeeRotateCCWTransformation)];
	[undo setActionName:NSLocalizedString(@"Rotate Counter-clockwise",@"Rotate Counter-clockwise undo label")];
}

-(IBAction)rotate180:(id)sender
{
	if(!currimage) return;
	[self setResizeBlockFromSender:sender];
	[self setOrientation:XeeCombineTransformations([currimage orientation],XeeRotate180Transformation)];
	[undo setActionName:NSLocalizedString(@"Rotate 180¼",@"Rotate 180¼ undo label")];
}

-(IBAction)autoRotate:(id)sender
{
	if(!currimage) return;
	[self setResizeBlockFromSender:sender];
	[self setOrientation:[currimage correctOrientation]];
	[undo setActionName:NSLocalizedString(@"Automatic Rotation",@"Automatic Rotation undo label")];
}

-(IBAction)rotateActual:(id)sender
{
	if(!currimage) return;
	[self setResizeBlockFromSender:sender];
	[self setOrientation:XeeNoTransformation];
	[undo setActionName:NSLocalizedString(@"Actual Rotation",@"Actual Rotation undo label")];
}

-(IBAction)mirrorHorizontal:(id)sender
{
	if(!currimage) return;
	[self setOrientation:XeeCombineTransformations([currimage orientation],XeeMirrorHorizontalTransformation)];
	[undo setActionName:NSLocalizedString(@"Mirror Horizontal",@"Mirror Horizontal undo label")];
}

-(IBAction)mirrorVertical:(id)sender
{
	if(!currimage) return;
	[self setOrientation:XeeCombineTransformations([currimage orientation],XeeMirrorVerticalTransformation)];
	[undo setActionName:NSLocalizedString(@"Mirror Vertical",@"Mirror Vertical undo label")];
}



-(void)setCroppingRect:(NSRect)rect
{
	[[undo prepareWithInvocationTarget:self] setCroppingRect:[currimage croppingRect]];
	[currimage setCroppingRect:rect];
}

-(IBAction)crop:(id)sender
{
	if([imageview tool]==croptool)
	{
		[self setCroppingRect:[croptool croppingRect]];
		[undo setActionName:NSLocalizedString(@"Crop",@"Cropping undo label")];
		[imageview setTool:movetool];
	}
	else
	{
		[imageview setTool:croptool];
		[imageview invalidate];
	}
}

-(IBAction)losslessCrop:(id)sender
{
}



-(IBAction)fullScreen:(id)sender
{
	if(!fullscreenwindow)
	{
		fullscreenwindow=[[XeeFullScreenWindow alloc] initWithContentRect:[[window screen] frame]
		styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES];
		[fullscreenwindow setDelegate:self];

		fullscreenview=[[[XeeView alloc] initWithFrame:[[fullscreenwindow contentView] bounds]] autorelease];
		[fullscreenview setOpenGLContext:[[[NSOpenGLContext alloc]
		initWithFormat:[NSOpenGLView defaultPixelFormat] shareContext:[imageview openGLContext]] autorelease]];
		[fullscreenview setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];

		NSMenu *menu=[[NSApplication sharedApplication] mainMenu];
		[[menu itemAtIndex:0] setTitle:@"Xee"]; // eek, hack!
		[fullscreenview setMenu:menu];

		[[fullscreenwindow contentView] addSubview:fullscreenview];
		[fullscreenwindow makeFirstResponder:fullscreenview];

		[NSMenu setMenuBarVisible:NO];
		[fullscreenwindow setFrame:[[window screen] frame] display:NO];

		[self setImage:currimage];

		[fullscreenwindow makeKeyAndOrderFront:nil];
		[window orderOut:nil];
	}
	else
	{
		[fullscreenwindow orderOut:nil];
		[fullscreenwindow release];
		fullscreenwindow=nil;
		fullscreenview=nil;

		[NSMenu setMenuBarVisible:YES];

//		[fullscreenview setImage:nil];
		[self setImage:currimage];

		[window makeKeyAndOrderFront:nil];
	}
}

-(IBAction)closeWindowOrDrawer:(id)sender
{
	if(fullscreenwindow) [self fullScreen:nil];
	else [[self window] performClose:nil];
}

@end




@implementation XeeWindow

@end

@implementation XeeDisplayWindow

@end

@implementation XeeFullScreenWindow

-(BOOL)canBecomeKeyWindow
{
	return YES;
}

@end
