#import <Cocoa/Cocoa.h>

@class XeeController,XeeDirectoryController,XeeKeyboardShortcuts,XeePropertiesController;

@interface XeeDelegate:NSObject
{
	NSNib *directorynib,*clipboardnib;
	BOOL filesopened;

	NSString *openediconset;

	IBOutlet NSMenu *openmenu;
	IBOutlet NSMenu *editmenu;
	IBOutlet NSMenu *viewmenu;
	IBOutlet NSMenu *antialiasmenu;
	IBOutlet NSMenuItem *copyitem;
	IBOutlet NSMenuItem *pasteitem;
	IBOutlet NSMenuItem *statusitem;

	IBOutlet NSWindow *prefswindow;
	IBOutlet NSTabView *prefstabs;
	IBOutlet NSTabViewItem *formattab;

	IBOutlet NSColorWell *imagewell;
	IBOutlet NSColorWell *windowwell;
	IBOutlet NSColorWell *fullscreenwell;

	IBOutlet NSWindow *iconwindow;
	IBOutlet NSTextField *iconfield;

	IBOutlet XeeController *windowcontroller;
	IBOutlet XeeKeyboardShortcuts *shortcuts;
	IBOutlet XeePropertiesController *properties;
}


-(void)awakeFromNib;

-(XeeKeyboardShortcuts *)shortcuts;

-(void)applicationDidFinishLaunching:(NSNotification *)notification;

-(BOOL)application:(NSApplication *)app openFile:(NSString *)filename;
-(IBAction)openDocument:(id)sender;
-(XeeDirectoryController *)newDirectoryWindow;
-(XeeController *)newClipboardWindow;
-(id)instantiateWindowFromNib:(NSNib *)nib;

-(void)menuNeedsUpdate:(NSMenu *)menu;
-(BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent *)event target:(id *)target action:(SEL *)action;
-(void)buildOpenMenu:(NSMenu *)menu;
-(void)updateDefaultEditorItem;
-(NSString *)defaultEditor;
-(void)setDefaultEditor:(NSString *)app;
-(IBAction)setDefaultEditorFromMenu:(id)sender;
-(void)updateEditMenu:(NSMenu *)menu;
-(void)updateViewMenu:(NSMenu *)menu;
-(BOOL)validateMenuItem:(id <NSMenuItem>)item;
-(BOOL)xeeFocus;

-(IBAction)installIconSet:(id)sender;
-(void)windowWillClose:(NSNotification *)notification;
-(NSArray *)iconNames;

-(BOOL)canPaste;
-(IBAction)paste:(id)sender;
-(IBAction)setAntialiasing:(id)sender;
-(IBAction)getInfo:(id)sender;

-(IBAction)keyboardShortcuts:(id)sender;
-(IBAction)openSupportThread:(id)sender;
-(IBAction)openHomePage:(id)sender;

-(IBAction)dummy:(id)sender;


@end



@interface XeeApplication:NSApplication
{
}

-(void)sendEvent:(NSEvent *)event;

@end


extern XeeDelegate *maindelegate;
