#import "XeeController.h"
#import "XeeControllerImageActions.h"
#import "XeeDelegate.h"
#import "XeeView.h"
#import "XeeImage.h"
#import "XeeImageSource.h"
#import "XeeStatusBar.h"
#import "XeeSegmentedItem.h"
#import "XeeClipboardSource.h"
#import "XeePropertiesController.h"
#import "XeeMoveTool.h"
#import "XeeCropTool.h"

#import <Carbon/Carbon.h>

extern float XeeZoomLevels[];
extern int XeeNumberOfZoomLevels;

static NSMutableArray *controllers=nil;



// XeeController

@implementation XeeController

+(void)initialize
{
	if(!controllers) controllers=[[NSMutableArray array] retain];
}

+(NSArray *)controllers { return controllers; }



-(id)init
{
	if(self=[super init])
	{
		source=nil;
		currimage=nil;

		blocked=awake=NO;
		drawer_mode=XeeNoMode;

		movetool=nil;
		croptool=nil;

		toolbaritems=nil;
		toolbaridentifiers=nil;
		undo=[[NSUndoManager alloc] init];

		fullscreenwindow=nil;

		slideshowtimer=nil;

		copiedcgimage=NULL;

		tasks=[[NSMutableArray array] retain];

		renamepanel=nil;
		collisionpanel=nil;
		delaypanel=nil;

		[controllers addObject:self];
	}
    return self;
}

-(void)dealloc
{
	[source release];
	[currimage release];

	[movetool release];

	[toolbaritems release];
	[toolbaridentifiers release];
	[undo release];

	[window release];
	[fullscreenwindow release];

	CGImageRelease(copiedcgimage);

	[tasks release];

	[drawer release];
	[renamepanel release];
	[collisionpanel release];
	[delaypanel release];

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[super dealloc];
}

-(void)awakeFromNib
{
	if(awake) return;
	awake=YES;

	movetool=[[XeeMoveTool toolForView:imageview] retain];
	[imageview setTool:movetool];

	[[NSNotificationCenter defaultCenter] addObserver:self
	selector:@selector(setStatusBarHiddenNotification:)
	name:@"XeeSetStatusBarHiddenNotification" object:nil];

	NSToolbar *toolbar=[[[NSToolbar alloc] initWithIdentifier:@"BrowserToolbar"] autorelease];
	[toolbar setDelegate:self];
	[toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	[self setupToolbarItems];
	[window setToolbar:toolbar];

	[self setStatusBarHidden:[[NSUserDefaults standardUserDefaults] boolForKey:@"hideStatusBar"]];

	[self updateWindowPosition];
}



-(void)dismantle
{
	// kill slideshow timer
	[slideshowtimer invalidate];
	[slideshowtimer release];
	slideshowtimer=nil;

	statusbar=nil; // inhibit useless updates
	[self setImage:nil];
	[self release];
}

-(void)windowWillClose:(NSNotification *)notification
{
	if([notification object]!=window) return; // ignore messages from the fullscreen window
	[controllers removeObject:self];

	[source stop];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"XeeFrontImageDidChangeNotification" object:nil];
	[self performSelector:@selector(dismantle) withObject:nil afterDelay:0];
}

-(void)windowDidBecomeMain:(NSNotification *)notification
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"XeeFrontImageDidChangeNotification" object:currimage];
	[statusbar setNeedsDisplay:YES];
}

-(void)windowDidResignMain:(NSNotification *)notification
{
	if(fullscreenwindow) return; // ignore messages when switching to and from the fullscreen window
	[[NSNotificationCenter defaultCenter] postNotificationName:@"XeeFrontImageDidChangeNotification" object:nil];
	[statusbar setNeedsDisplay:YES];
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

-(NSUndoManager *)windowWillReturnUndoManager:(NSNotification *)notification
{
	return undo;
}

-(void)setStatusBarHiddenNotification:(NSNotification *)notification
{
	[self setStatusBarHidden:[[notification object] boolValue]];
	[self setZoom:zoom]; // well, better than not doing it, I guess
}



static BOOL HasAppleMouse()
{
	io_iterator_t iterator;
	if(IORegistryCreateIterator(kIOMasterPortDefault,kIOServicePlane,kIORegistryIterateRecursively,&iterator)!=KERN_SUCCESS) return NO;

	io_registry_entry_t entry;
	while(entry=IOIteratorNext(iterator))
	{
		io_name_t name;
		IORegistryEntryGetName(entry,name);
		if(!strcmp(name,"Apple Optical USB Mouse")) return YES;
	}
	return NO;
}

-(void)scrollWheel:(NSEvent *)event
{
	if([[NSUserDefaults standardUserDefaults] integerForKey:@"scrollWheelFunction"]==0)
	{
		static BOOL apple=NO;
		static time_t lastcheck=0;

		time_t t=time(NULL);
		if(t-lastcheck>10)
		{
			lastcheck=t;
			apple=HasAppleMouse();
		}

		int step=[event deltaY]>0?-1:1;

		if(apple)
		{
			static const NSTimeInterval delay=0.25;
			static NSTimeInterval starttime;
			static NSTimeInterval prevtime=0;
			static int steps;
			NSTimeInterval currtime=[event timestamp];

			if(currtime-prevtime>delay)
			{
				starttime=currtime;
				steps=0;
				[source skip:step];
			}
			else if(currtime-starttime<delay)
			{
				steps+=step;
			}
			else
			{
				[source skip:step+steps];
				steps=0;
			}

			prevtime=currtime;
		}
		else [source skip:step];


/*		float step=-[event deltaY];
		float sensitivity=[[NSUserDefaults standardUserDefaults] floatForKey:@"scrollSensitivity"];

		scrollpos+=step/sensitivity;

		float end=[source numberOfImages]-0.25;
		if(scrollpos<0.25) scrollpos=0.25;
		if(scrollpos>end) scrollpos=end;

		int newindex;
		if(step<0) newindex=(int)(scrollpos+0.25);
		else newindex=(int)(scrollpos-0.25);

		float oldscrollpos=scrollpos;
		[source skip:newindex-[source indexOfCurrentImage]];
		scrollpos=oldscrollpos;*/
	}
}



-(void)xeeImageSource:(XeeImageSource *)msgsource imageDidChange:(XeeImage *)image
{
	NSString *filename=[source representedFilename];
	if(filename) [window setTitleWithRepresentedFilename:filename];
	else [window setTitle:@"Xee"];

	[self setImage:image];
	[self updateStatusBar];
}

-(void)xeeImageSource:(XeeImageSource *)source imageListDidChange:(int)num
{
	[self updateStatusBar];
}

-(void)xeeView:(XeeView *)view imageDidChange:(XeeImage *)image
{
	[self updateStatusBar]; // should this be handled by PropertiesDidChange?
}

-(void)xeeView:(XeeView *)view imageSizeDidChange:(XeeImage *)image
{
	NSSize newsize=NSMakeSize(zoom*(float)[currimage width],zoom*(float)[currimage height]);
	[self setImageSize:newsize];

	[imageview setTool:movetool];
	[imageview setFocus:NSMakePoint(0,0)];
	[imageview setNeedsDisplay:YES];
	//[self updateStatusBar]; // should do a PropertiesDidChange too!
}

-(void)xeeView:(XeeView *)view imagePropertiesDidChange:(XeeImage *)image
{
	if([[NSApplication sharedApplication] keyWindow]==window)
	[[NSNotificationCenter defaultCenter] postNotificationName:@"XeeFrontImageDidChangeNotification" object:currimage];

	NSString *filename=[source representedFilename];
	if(filename) [window setTitleWithRepresentedFilename:filename];
	else [window setTitle:@"Xee"];

	[self updateStatusBar];
}



-(XeeImageSource *)imageSource { return source; }

-(NSWindow *)window { return window; }

-(XeeFullScreenWindow *)fullScreenWindow { return fullscreenwindow; }

-(XeeImage *)image { return currimage; }

-(NSDrawer *)drawer { return drawer; }

-(NSString *)currentFilename // should probably be removed
{
	return [currimage filename];
}

-(BOOL)isFullscreen { return fullscreenwindow?YES:NO; }



-(void)setImageSource:(XeeImageSource *)newsource
{
	if(source==newsource) return;

	[source setDelegate:nil];
	[source stop];
	[source release];
	source=[newsource retain];
	[source setDelegate:self];
	[source pickCurrentImage];

	[self setDrawerEnableState];
}

-(void)setImage:(XeeImage *)image
{
	if(image!=currimage)
	{
		[currimage release];
		currimage=[image retain];
	}

	if(currimage)
	{
		[currimage setFrame:0];
		[currimage resetTransformations];
		[imageview setTool:movetool];
		[imageview setImage:currimage];
		[self setStandardImageSize];
	}
	else
	{
		[imageview setImage:nil];
	}

	NSWindow *keywin=[[NSApplication sharedApplication] keyWindow];
	if(keywin==window||keywin==fullscreenwindow)
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
	[[NSUserDefaults standardUserDefaults] setFloat:zoom forKey:@"savedZoom"];

	[self updateStatusBar];
}

-(void)setFrame:(int)frame
{
	if(!currimage) return;
	if(frame==[currimage frame]) return;
	if([currimage frames]==0) return;

	if(frame<0) frame=0;
	if(frame>=[currimage frames]) frame=[currimage frame]-1;

	[imageview setTool:movetool];
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
	[imageview setImageSize:size];
	if(reset) [imageview setFocus:NSMakePoint(0,0)];

	if([self isResizeBlocked]) return;

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

	if(reset) [imageview setFocus:NSMakePoint(0,0)];

	window_focus_x=focus_x; // make sure we remember the old position
	window_focus_y=focus_y;
}

-(void)setStandardImageSize
{
	NSSize maxsize=[self maxViewSize];

	BOOL shrink=[[NSUserDefaults standardUserDefaults] boolForKey:@"shrinkToFit"];
	BOOL enlarge=[[NSUserDefaults standardUserDefaults] boolForKey:@"enlargeToFit"];
	BOOL remember=[[NSUserDefaults standardUserDefaults] boolForKey:@"rememberZoom"];
	float savedzoom=[[NSUserDefaults standardUserDefaults] floatForKey:@"savedZoom"];

	float horiz_zoom=maxsize.width/(float)[currimage width];
	float vert_zoom=maxsize.height/(float)[currimage height];
	float min_zoom=fminf(horiz_zoom,vert_zoom);

	if(remember) zoom=savedzoom;
	else zoom=1;

	if(shrink&&min_zoom<zoom) zoom=min_zoom;
	if(enlarge&&min_zoom>zoom) zoom=min_zoom;

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
	NSSize size=NSMakeSize(256,128);

	if([drawer state]==NSDrawerOpenState)
	{
		int drawerheight=[destinationtable numberOfRows]*19;
		drawerheight+=[drawer leadingOffset];
		drawerheight+=[drawer trailingOffset];
		drawerheight+=19; // uh-huh, right...
		if(size.height<drawerheight) size.height=drawerheight;
	}
	return size;
}

-(NSRect)availableScreenSpace
{
	NSRect rect=[[window screen] visibleFrame];
	if([drawer state]==NSDrawerOpenState) rect.size.width-=[drawer contentSize].width+6;
	return rect;
}



-(void)errorMessage:(NSString *)title text:(NSString *)text
{
	NSAlert *alert=[[[NSAlert alloc] init] autorelease];

	[alert setMessageText:title];
	[alert setInformativeText:text];
	[alert addButtonWithTitle:NSLocalizedString(@"OK","OK button")];

	[alert beginSheetModalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

-(void)detachBackgroundTaskWithMessage:(NSString *)message selector:(SEL)selector target:(id)target
{
	NSDictionary *task=[NSDictionary dictionaryWithObjectsAndKeys:
		message,@"message",
		[NSValue valueWithPointer:selector],@"selector",
		target,@"target",
	nil];
	[tasks addObject:task];
	[NSThread detachNewThreadSelector:@selector(detachBackgroundTask:) toTarget:self withObject:task];
	[self updateStatusBar];
}

-(void)detachBackgroundTask:(NSDictionary *)task
{
	NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

	[[task objectForKey:@"target"] performSelector:[[task objectForKey:@"selector"] pointerValue]];
	[tasks performSelectorOnMainThread:@selector(removeObject:) withObject:task waitUntilDone:YES];
	[self performSelectorOnMainThread:@selector(updateStatusBar) withObject:nil waitUntilDone:NO];

	[pool release];
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
	return [NSArray arrayWithObjects:
		@"skip",@"end",@"zoom",@"anim",NSToolbarFlexibleSpaceItemIdentifier,@"auto",@"rotate",
	nil];
}

-(void)setupToolbarItems
{
	NSArray *items=[self makeToolbarItems];
	if(!items) return;

	NSEnumerator *enumerator;
	NSToolbarItem *item;

	[toolbaritems release];
	[toolbaridentifiers release];

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithCapacity:[items count]];
	enumerator=[items objectEnumerator];
	while(item=[enumerator nextObject]) [dict setObject:item forKey:[item itemIdentifier]];
	toolbaritems=[[NSDictionary dictionaryWithDictionary:dict] retain];

	NSMutableArray *array=[NSMutableArray arrayWithCapacity:[items count]+3];
	enumerator=[items objectEnumerator];
	while(item=[enumerator nextObject]) [array addObject:[item itemIdentifier]];
	[array addObject:NSToolbarSeparatorItemIdentifier];
	[array addObject:NSToolbarSpaceItemIdentifier];
	[array addObject:NSToolbarFlexibleSpaceItemIdentifier];
	toolbaridentifiers=[[NSArray arrayWithArray:array] retain];
}

-(NSArray *)makeToolbarItems
{
	NSMutableArray *array=[NSMutableArray array];

	XeeSegmentedItem *navitool=[XeeSegmentedItem itemWithIdentifier:@"navi"
	label:NSLocalizedString(@"Navigation",@"Navigation toolbar segment title")
	paletteLabel:NSLocalizedString(@"Navigation",@"Navigation toolbar segment title") segments:4];
	[navitool setSegment:0 imageName:@"tool_first" longLabel:NSLocalizedString(@"First Image",@"First Image toolbar button label") action:@selector(skipFirst:)];
	[navitool setSegment:1 imageName:@"tool_prev" longLabel:NSLocalizedString(@"Previous Image",@"Previous Image toolbar button label") action:@selector(skipPrev:)];
	[navitool setSegment:2 imageName:@"tool_next" longLabel:NSLocalizedString(@"Next Image",@"Next Image toolbar button label") action:@selector(skipNext:)];
	[navitool setSegment:3 imageName:@"tool_last" longLabel:NSLocalizedString(@"Last Image",@"Last Image toolbar button label") action:@selector(skipLast:)];
	[navitool setupView];
	[array addObject:navitool];

	XeeSegmentedItem *skiptool=[XeeSegmentedItem itemWithIdentifier:@"skip"
	label:NSLocalizedString(@"Prev Next",@"Prev/Next toolbar segment label")
	paletteLabel:NSLocalizedString(@"Prev/Next",@"Prev/Next toolbar segment title") segments:2];
	[skiptool setSegment:0 imageName:@"tool_prev" longLabel:NSLocalizedString(@"Previous Image",@"Previous Image toolbar button label") action:@selector(skipPrev:)];
	[skiptool setSegment:1 imageName:@"tool_next" longLabel:NSLocalizedString(@"Next Image",@"Next Image toolbar button label") action:@selector(skipNext:)];
	[skiptool setupView];
	[array addObject:skiptool];

	XeeSegmentedItem *endtool=[XeeSegmentedItem itemWithIdentifier:@"end"
	label:NSLocalizedString(@"First Last",@"First/Last toolbar segment label")
	paletteLabel:NSLocalizedString(@"First/Last",@"First/Last toolbar segment title") segments:2];
	[endtool setSegment:0 imageName:@"tool_first" longLabel:NSLocalizedString(@"First Image",@"First Image toolbar button label") action:@selector(skipFirst:)];
	[endtool setSegment:1 imageName:@"tool_last" longLabel:NSLocalizedString(@"Last Image",@"Last Image toolbar button label") action:@selector(skipLast:)];
	[endtool setupView];
	[array addObject:endtool];

	XeeSegmentedItem *zoomtool=[XeeSegmentedItem itemWithIdentifier:@"zoom"
	label:NSLocalizedString(@"Zoom",@"Zoom toolbar segment title")
	paletteLabel:NSLocalizedString(@"Zoom",@"Zoom toolbar segment title") segments:4];
	[zoomtool setSegment:0 imageName:@"tool_zoomin" longLabel:NSLocalizedString(@"Zoom In",@"Zoom In toolbar button label") action:@selector(zoomIn:)];
	[zoomtool setSegment:1 imageName:@"tool_zoomout" longLabel:NSLocalizedString(@"Zoom Out",@"Zoom Out toolbar button label") action:@selector(zoomOut:)];
	[zoomtool setSegment:2 imageName:@"tool_zoomactual" longLabel:NSLocalizedString(@"Actual Size",@"Actual Size toolbar button label") action:@selector(zoomActual:)];
	[zoomtool setSegment:3 imageName:@"tool_zoomfit" longLabel:NSLocalizedString(@"Fit On Screen",@"Fit On Screen toolbar button label") action:@selector(zoomFit:)];
	[zoomtool setupView];
	[array addObject:zoomtool];

	XeeSegmentedItem *animtool=[XeeSegmentedItem itemWithIdentifier:@"anim"
	label:NSLocalizedString(@"Animation",@"Animation toolbar segment label")
	paletteLabel:NSLocalizedString(@"Animation And Frames",@"Animation toolbar segment title") segments:3];
	[animtool setSegment:0 imageName:@"tool_anim" longLabel:NSLocalizedString(@"Toggle Animation",@"Toggle Animation toolbar button label") action:@selector(toggleAnimation:)];
	[animtool setSegment:1 imageName:@"tool_nextframe" longLabel:NSLocalizedString(@"Next Frame",@"Next Frame toolbar button label") action:@selector(frameSkipNext:)];
	[animtool setSegment:2 imageName:@"tool_prevframe" longLabel:NSLocalizedString(@"Previous Frame",@"Previous toolbar button label") action:@selector(frameSkipPrev:)];
	[animtool setupView];
	[array addObject:animtool];

	XeeSegmentedItem *autotool=[XeeSegmentedItem itemWithIdentifier:@"auto"
	label:NSLocalizedString(@"Auto Orientation",@"Auto orientation toolbar segment label")
	paletteLabel:NSLocalizedString(@"Automatic Orientation",@"Auto orientation toolbar segment title") segments:1];
	[autotool setSegment:0 imageName:@"tool_autorot" longLabel:NSLocalizedString(@"Automatic Orientation",@"Automatic Orientation toolbar button label") action:@selector(autoRotate:)];
	[autotool setupView];
	[array addObject:autotool];

	XeeSegmentedItem *rotatetool=[XeeSegmentedItem itemWithIdentifier:@"rotate"
	label:NSLocalizedString(@"Rotation",@"Rotation segment label")
	paletteLabel:NSLocalizedString(@"Rotation",@"Rotation toolbar segment title") segments:3];
	[rotatetool setSegment:0 imageName:@"tool_cw" longLabel:NSLocalizedString(@"Rotate Clockwise",@"Rotate Clockwise toolbar button label") action:@selector(rotateCW:)];
	[rotatetool setSegment:1 imageName:@"tool_ccw" longLabel:NSLocalizedString(@"Rotate Counter-clockwise",@"Rotate Counter-clockwise toolbar button label") action:@selector(rotateCCW:)];
	[rotatetool setSegment:2 imageName:@"tool_flip" longLabel:NSLocalizedString(@"Rotate 180",@"Rotate 180 toolbar button label") action:@selector(rotate180:)];
	[rotatetool setupView];
	[array addObject:rotatetool];

	XeeSegmentedItem *croppingtool=[XeeToolItem itemWithIdentifier:@"crop"
	label:NSLocalizedString(@"Crop",@"Cropping segment label")
	paletteLabel:NSLocalizedString(@"Crop Tool",@"Cropping toolbar segment title")
	imageName:@"tool_crop"
	longLabel:NSLocalizedString(@"Crop Tool",@"Crop Tool toolbar button label")
	action:@selector(crop:) activeSelector:@selector(isCropping) target:self];
	[array addObject:croppingtool];

	XeeSegmentedItem *deletetool=[XeeSegmentedItem itemWithIdentifier:@"delete"
	label:@"" paletteLabel:NSLocalizedString(@"Delete file",@"Delete file toolbar segment title") segments:1];
	[deletetool setSegment:0 label:NSLocalizedString(@"Delete",@"Delete file toolbar button")
	longLabel:NSLocalizedString(@"Delete file",@"Delete file toolbar button label") action:@selector(askAndDelete:)];
	[deletetool setupView];
	[array addObject:deletetool];

	XeeSegmentedItem *renametool=[XeeSegmentedItem itemWithIdentifier:@"rename"
	label:@"" paletteLabel:NSLocalizedString(@"Rename file",@"Rename file toolbar segment title") segments:1];
	[renametool setSegment:0 label:NSLocalizedString(@"Rename",@"Rename file toolbar button")
	longLabel:NSLocalizedString(@"Rename file",@"Rename file toolbar button label") action:@selector(renameFileFromMenu:)];
	[renametool setupView];
	[array addObject:renametool];

	XeeSegmentedItem *copytool=[XeeSegmentedItem itemWithIdentifier:@"copy"
	label:@"" paletteLabel:NSLocalizedString(@"File Handling",@"Copy/move toolbar segment title") segments:2];
	[copytool setSegment:0 label:NSLocalizedString(@"Copy file",@"Copy file toolbar button label")
	longLabel:NSLocalizedString(@"Copy",@"Copy file toolbar button") action:@selector(copyFile:)];
	[copytool setSegment:1 label:NSLocalizedString(@"Move file",@"Move file toolbar button label")
	longLabel:NSLocalizedString(@"Move",@"Move file toolbar button") action:@selector(moveFile:)];
	[copytool setupView];
	[array addObject:copytool];

	return array;
}



-(BOOL)validateMenuItem:(id <NSMenuItem>)item
{
	return [self validateAction:[item action]];
}

-(BOOL)validateAction:(SEL)action
{
	int count=[source numberOfImages];
	int curr=[source indexOfCurrentImage];
	int capabilities=[source capabilities];
	BOOL wrap=[[NSUserDefaults standardUserDefaults] boolForKey:@"wrapImageBrowsing"];

	if(action==@selector(toggleStatusBar:)) return fullscreenwindow?NO:YES;

	else if(action==@selector(save:)) return currimage&&![currimage needsLoading]&&[currimage isTransformed]&&
	([currimage losslessSaveFlags]&(XeeCanSaveLosslesslyFlag|XeeNotActuallyLosslessFlag))==XeeCanSaveLosslesslyFlag;
	else if(action==@selector(saveAs:)) return currimage&&![currimage needsLoading];
	else if(action==@selector(toggleAnimation:)) return currimage&&[currimage animated];
	else if(action==@selector(frameSkipNext:)||
			action==@selector(frameSkipPrev:)) return currimage&&[currimage frames]>1;
	else if(action==@selector(zoomIn:)) return currimage&&zoom<XeeZoomLevels[XeeNumberOfZoomLevels-1];
	else if(action==@selector(zoomOut:)) return currimage&&zoom>XeeZoomLevels[0];
	else if(action==@selector(zoomActual:)) return currimage&&zoom!=1;
	else if(action==@selector(zoomFit:)) return currimage?YES:NO; //eek, no proper validation
	else if(action==@selector(rotateCW:)||
			action==@selector(rotateCCW:)||
			action==@selector(rotate180:)||
			action==@selector(rotateActual:)||
			action==@selector(mirrorHorizontal:)||
			action==@selector(mirrorVertical:)||
			action==@selector(crop:)) return currimage?YES:NO;
	else if(action==@selector(autoRotate:)) return currimage&&[currimage correctOrientation]!=XeeUnknownTransformation;

	else if(action==@selector(skipNext:)||
			action==@selector(skip10Forward:)||
			action==@selector(skip100Forward:)||
			action==@selector(skipLast:)) return count>1&&(curr!=count-1||wrap);
	else if(action==@selector(skipPrev:)||
			action==@selector(skip10Back:)||
			action==@selector(skip100Back:)||
			action==@selector(skipFirst:)) return count>1&&(curr!=0||wrap);
	else if(action==@selector(skipRandom:)||
			action==@selector(skipRandomPrev:)) return count>1;
	else if(action==@selector(setSortOrder:)) return capabilities&XeeSortingCapable;

	else if(action==@selector(revealInFinder:)) return [window representedFilename]?YES:NO;
	else if(action==@selector(renameFileFromMenu:)) return currimage&&(capabilities&XeeRenamingCapable);
	else if(action==@selector(deleteFileFromMenu:)||
			action==@selector(askAndDelete:)) return currimage&&(capabilities&XeeDeletionCapable);
	else if(action==@selector(moveFile:)) return currimage&&(capabilities&XeeMovingCapable)&&!fullscreenwindow;
	else if(action==@selector(copyFile:)) return currimage&&(capabilities&XeeCopyingCapable)&&!fullscreenwindow;
	else if(action==@selector(launchAppFromMenu:)) return currimage&&[currimage filename];
	else if(action==@selector(launchDefaultEditor:)) return currimage&&[currimage filename]&&[maindelegate defaultEditor];

	else return YES;
}



-(void)updateStatusBar
{
	[statusbar removeAllCells];

	if(!currimage)
	{
		if([source indexOfCurrentImage]==NSNotFound)
		{
/*			if(![source numberOfImages])
			[statusbar addEntry:NSLocalizedString(@"No images available",@"Status bar message when no images are available")
			imageNamed:@"message"];
			else*/
			[statusbar addEntry:NSLocalizedString(@"No images available",@"Status bar message when no images are available")
			imageNamed:@"message"];
		}
		else
		{
			if([source capabilities]&XeeNavigationCapable) [statusbar addEntry:
			[NSString stringWithFormat:@"%d/%d",[source indexOfCurrentImage]+1,[source numberOfImages]]
			image:[source icon]];

			[statusbar addEntry:[NSString stringWithFormat:
			NSLocalizedString(@"Couldn't display file \"%@\".",@"Statusbar message when image loading fails to even identify a file"),
			[source descriptiveNameOfCurrentImage]] imageNamed:@"error"];
		}

		[statusbar setNeedsDisplay:YES];
		return;
	}

	if([source capabilities]&XeeNavigationCapable) [statusbar addEntry:
	[NSString stringWithFormat:@"%d/%d",[source indexOfCurrentImage]+1,[source numberOfImages]]
	image:[source icon]];

	[statusbar addEntry:
	[NSString stringWithFormat:@"%d%%",(int)(zoom*100)]
	imageNamed:@"zoom"];

	if([currimage frames]>1) [statusbar addEntry:
	[NSString stringWithFormat:@"%d/%d",[currimage frame]+1,[currimage frames]]
	imageNamed:@"frames"];

	[statusbar addEntry:
	[NSString stringWithFormat:@"%dx%d",[currimage width],[currimage height]]
	imageNamed:@"size"];

	[statusbar addEntry:[currimage depth] image:[currimage depthIcon]];

	if([currimage filename])
	{
		[statusbar addEntry:[currimage descriptiveFileSize] imageNamed:@"filesize"];
		[statusbar addEntry:[currimage descriptiveDate]];
		[statusbar addEntry:[currimage format] image:[currimage icon]];
	}

	if([tasks count]) [statusbar addEntry:[[tasks objectAtIndex:0] objectForKey:@"message"] imageNamed:@"message"];

	else if([currimage failed]) [statusbar addEntry:[NSString stringWithFormat:
	NSLocalizedString(@"Error loading image \"%@\".",@"Statusbar message when image loading fails"),
	[source descriptiveNameOfCurrentImage]] imageNamed:@"error"];

	else if([currimage needsLoading]) [statusbar addEntry:[NSString stringWithFormat:
	NSLocalizedString(@"Loading \"%@\"...",@"Statusbar message while loading"),
	[source descriptiveNameOfCurrentImage]] imageNamed:@"message"];

	else [statusbar addEntry:[source descriptiveNameOfCurrentImage]];

	[statusbar setNeedsDisplay:YES];
}

-(void)setStatusBarHidden:(BOOL)hidden
{
	NSRect imageframe=[imageview frame];
	NSRect statusframe=[statusbar frame];

	if([statusbar isHidden])
	{
		if(hidden) return;
		[statusbar setHidden:NO];
		imageframe.size.height-=statusframe.size.height+1;
		imageframe.origin.y+=statusframe.size.height+1;
		[imageview setFrame:imageframe];
		[imageview setDrawResizeCorner:NO];
	}
	else
	{
		if(!hidden) return;
		[statusbar setHidden:YES];
		imageframe.size.height+=statusframe.size.height+1;
		imageframe.origin.y-=statusframe.size.height+1;
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

	[[NSUserDefaults standardUserDefaults] setBool:newstate forKey:@"hideStatusBar"];

	[[NSNotificationCenter defaultCenter]
	postNotificationName:@"XeeSetStatusBarHiddenNotification"
	object:[NSNumber numberWithBool:newstate]];
}



-(void)setDrawerEnableState
{
	int capabilities=[source capabilities];
	BOOL cancopy=capabilities&XeeCopyingCapable;
	BOOL canmove=capabilities&XeeMovingCapable;

	if(cancopy&&canmove)
	{
		[drawerseg setEnabled:YES forSegment:0];
		[drawerseg setEnabled:YES forSegment:1];
	}
	else if(cancopy)
	{
		[drawerseg setSelectedSegment:0];
		[drawerseg setEnabled:YES forSegment:0];
		[drawerseg setEnabled:NO forSegment:1];
	}
	else if(canmove)
	{
		[drawerseg setSelectedSegment:1];
		[drawerseg setEnabled:NO forSegment:0];
		[drawerseg setEnabled:YES forSegment:1];
	}
	else
	{
		[drawerseg setEnabled:NO forSegment:0];
		[drawerseg setEnabled:NO forSegment:1];
		[drawer close];
	}
}



-(IBAction)fullScreen:(id)sender
{
	if(!fullscreenwindow)
	{
		fullscreenwindow=[[XeeFullScreenWindow alloc] initWithContentRect:[[window screen] frame]
		styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES];
		[fullscreenwindow setDelegate:self];

		[window orderOut:nil];

		savedsuperview=[imageview superview];
		savedframe=[imageview frame];
		[imageview removeFromSuperview];
		[[fullscreenwindow contentView] addSubview:imageview];
		[fullscreenwindow makeFirstResponder:imageview];

		[imageview setFrame:[[fullscreenwindow contentView] bounds]];
		[fullscreenwindow setFrame:[[window screen] frame] display:NO];

		NSMenu *menu=[[NSApplication sharedApplication] mainMenu];
		[[menu itemAtIndex:0] setTitle:@"Xee"]; // eek, hack!
		[imageview setMenu:menu];

		[[maindelegate propertiesController] setFullscreenMode:YES];
		SetSystemUIMode(kUIModeAllHidden,kUIOptionAutoShowMenuBar);

		[self setStandardImageSize];
		[fullscreenwindow makeKeyAndOrderFront:nil];
	}
	else
	{
		[fullscreenwindow orderOut:nil];

		[imageview removeFromSuperview];
		[savedsuperview addSubview:imageview];
		[window makeFirstResponder:imageview];

		[imageview setFrame:savedframe];

		[imageview setMenu:nil];

		[[maindelegate propertiesController] setFullscreenMode:NO];
		SetSystemUIMode(kUIModeNormal,0);

		[fullscreenwindow release];
		fullscreenwindow=nil;

		[self setStandardImageSize];
		[window makeKeyAndOrderFront:nil];
	}
}



-(IBAction)confirm:(id)sender
{
	if([self isCropping]) [self crop:nil];
}

-(IBAction)cancel:(id)sender
{
	int state=[drawer state];

	if([self isCropping]) [imageview setTool:movetool];
	else if(fullscreenwindow) [self fullScreen:nil];
	else if([[maindelegate propertiesController] closeIfOpen]) return;
	else if(state==NSDrawerOpenState||state==NSDrawerOpeningState) [closebutton performClick:nil];
	else [[[NSApplication sharedApplication] keyWindow] performClose:nil];
}

@end



@implementation XeeFullScreenWindow

-(BOOL)canBecomeKeyWindow { return YES; }

-(BOOL)canBecomeMainWindow { return YES; }

@end
