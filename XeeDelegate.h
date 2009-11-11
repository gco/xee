#import <Cocoa/Cocoa.h>
#import "XeeFSRef.h"

@class XeeController,XeeKeyboardShortcuts,XeePropertiesController,CSAction;

@interface XeeDelegate:NSObject
{
	NSNib *browsernib;
	BOOL filesopened;

	NSString *openediconset;

	CSAction *actions[20];

	NSMutableDictionary *controllers;

	IBOutlet NSMenu *openmenu;
	IBOutlet NSMenu *editmenu;
	IBOutlet NSMenu *viewmenu;
	IBOutlet NSMenu *sortmenu;
	IBOutlet NSMenu *slideshowmenu;
	IBOutlet NSMenu *antialiasmenu;
	IBOutlet NSMenuItem *copyitem;
	IBOutlet NSMenuItem *pasteitem;
	IBOutlet NSMenuItem *cropitem;
	IBOutlet NSMenuItem *statusitem;
	IBOutlet NSMenuItem *runslidesitem;
	IBOutlet NSMenuItem *otherdelayitem;

	IBOutlet NSWindow *prefswindow;
	IBOutlet NSTabView *prefstabs;
	IBOutlet NSTabViewItem *formattab;

	IBOutlet NSColorWell *imagewell;
	IBOutlet NSColorWell *windowwell;
	IBOutlet NSColorWell *fullscreenwell;

	IBOutlet NSWindow *iconwindow;
	IBOutlet NSTextField *iconfield;

	IBOutlet XeeController *windowcontroller;

	IBOutlet XeePropertiesController *properties;
}


-(void)awakeFromNib;

-(void)applicationDidFinishLaunching:(NSNotification *)notification;

-(BOOL)application:(NSApplication *)app openFile:(NSString *)filename;
-(IBAction)openDocument:(id)sender;

-(void)menuNeedsUpdate:(NSMenu *)menu;
-(BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent *)event target:(id *)target action:(SEL *)action;

-(void)buildOpenMenu:(NSMenu *)menu;
-(void)updateDefaultEditorItem;
-(NSString *)defaultEditor;
-(void)setDefaultEditor:(NSString *)app;
-(IBAction)setDefaultEditorFromMenu:(id)sender;

-(void)updateEditMenu:(NSMenu *)menu;
-(void)updateViewMenu:(NSMenu *)menu;
-(void)updateSortMenu:(NSMenu *)menu;
-(void)updateSlideshowMenu:(NSMenu *)menu;

-(BOOL)validateMenuItem:(NSMenuItem *)item;

-(IBAction)preferences:(id)sender;
-(IBAction)paste:(id)sender;
-(IBAction)getInfo:(id)sender;
-(IBAction)keyboardShortcuts:(id)sender;
-(IBAction)openSupportThread:(id)sender;
-(IBAction)openBugReport:(id)sender;
-(IBAction)openHomePage:(id)sender;

-(IBAction)installIconSet:(id)sender;
-(void)windowWillClose:(NSNotification *)notification;

-(IBAction)setAntialiasing:(id)sender;
-(IBAction)setUpscaling:(id)sender;

-(IBAction)alwaysFullscreenStub:(id)sender;
-(IBAction)loopImagesStub:(id)sender;
-(IBAction)randomOrderStub:(id)sender;
-(IBAction)rememberZoomStub:(id)sender;
-(IBAction)rememberFocusStub:(id)sender;

-(XeeController *)controllerForDirectory:(XeeFSRef *)directory;
-(void)controllerWillExit:(XeeController *)controller;

-(BOOL)xeeFocus;
-(XeeController *)focusedController;
-(NSArray *)iconNames;
-(XeePropertiesController *)propertiesController;
-(CSAction **)copyAndMoveActions;

@end

@interface XeeApplication:NSApplication
{
}

-(void)sendEvent:(NSEvent *)event;

@end


extern XeeDelegate *maindelegate;
