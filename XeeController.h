#import <Cocoa/Cocoa.h>

#import "XeeTypes.h"

#define XeeNoMode 0
#define XeeMoveMode 1
#define XeeCopyMode 2

@class XeeImage,XeeView,XeeStatusBar,XeeDisplayWindow,XeeFullScreenWindow;
@class XeeMoveTool,XeeCropTool;

@interface XeeController:NSObject
{
	XeeImage *currimage;
	float zoom;

	int window_focus_x,window_focus_y;
	BOOL blocked;

	NSToolbar *toolbar;
	NSDictionary *toolbaritems;
	NSArray *toolbaridentifiers,*defaultidentifiers;

	XeeFullScreenWindow *fullscreenwindow;
	XeeView *fullscreenview;

	XeeMoveTool *movetool;
	XeeCropTool *croptool;

	NSUndoManager *undo;

	CGImageRef copiedcgimage;

	IBOutlet XeeDisplayWindow *window;
    IBOutlet XeeView *imageview;
    IBOutlet XeeStatusBar *statusbar;
}

-(id)init;
-(void)dealloc;
-(void)awakeFromNib;

-(void)windowWillClose:(NSNotification *)notification;
-(void)windowDidBecomeMain:(NSNotification *)notification;
-(void)windowDidResignMain:(NSNotification *)notification;
-(void)windowWillMiniaturize:(NSNotification *)notification;
-(void)windowDidMiniaturize:(NSNotification *)notification;
-(NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender;

-(void)updateAllImages:(NSNotification *)notification;
-(void)xeeView:(XeeView *)view imageDidChange:(XeeImage *)image;
-(void)xeeView:(XeeView *)view imageSizeDidChange:(XeeImage *)image;
-(void)xeeView:(XeeView *)view imagePropertiesDidChange:(XeeImage *)image;

-(NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)flag;
-(NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar;
-(void)setupToolbarItems;
-(NSArray *)makeToolbarItems;
-(NSArray *)makeDefaultToolbarItemIdentifiers;

-(BOOL)validateMenuItem:(id <NSMenuItem>)item;
-(BOOL)validateAction:(SEL)action;

-(void)setupStatusBar;
-(void)updateStatusBar;
-(void)setStatusBarHidden:(BOOL)hidden;
-(BOOL)isStatusBarHidden;
-(IBAction)toggleStatusBar:(id)sender;

-(XeeDisplayWindow *)window;
-(XeeFullScreenWindow *)fullScreenWindow;
-(XeeImage *)image;

-(void)setImage:(XeeImage *)image;

-(void)setZoom:(float)newzoom;
-(void)setFrame:(int)frame;

-(void)updateWindowPosition;
-(void)setImageSize:(NSSize)size;
-(void)setImageSize:(NSSize)size resetFocus:(BOOL)reset;
-(void)setStandardImageSize;
-(void)setResizeBlock:(BOOL)block;
-(void)setResizeBlockFromSender:(id)sender;
-(BOOL)isResizeBlocked;
-(NSSize)maxViewSize;
-(NSSize)minViewSize;
-(NSRect)availableScreenSpace;

-(IBAction)copy:(id)sender;
-(void)pasteboard:(NSPasteboard *)pboard provideDataForType:(NSString *)type;
-(void)pasteboardChangedOwner:(NSPasteboard *)pboard;

-(IBAction)saveImage:(id)sender;

-(IBAction)frameSkipNext:(id)obj;
-(IBAction)frameSkipPrev:(id)obj;
-(IBAction)toggleAnimation:(id)obj;

-(IBAction)zoomIn:(id)sender;
-(IBAction)zoomOut:(id)sender;
-(IBAction)zoomActual:(id)sender;
-(IBAction)zoomFit:(id)sender;
-(IBAction)setAutoZoom:(id)sender;

-(void)setOrientation:(XeeTransformation)orientation;
-(IBAction)rotateCW:(id)sender;
-(IBAction)rotateCCW:(id)sender;
-(IBAction)rotate180:(id)sender;
-(IBAction)autoRotate:(id)sender;
-(IBAction)rotateActual:(id)sender;
-(IBAction)mirrorHorizontal:(id)sender;
-(IBAction)mirrorVertical:(id)sender;

-(void)setCroppingRect:(NSRect)rect;
-(IBAction)crop:(id)sender;
-(IBAction)losslessCrop:(id)sender;

-(IBAction)fullScreen:(id)sender;

-(IBAction)closeWindowOrDrawer:(id)sender;

@end



@interface XeeWindow:NSWindow
{
}

@end

@interface XeeDisplayWindow:XeeWindow
{
}

@end

@interface XeeFullScreenWindow:XeeWindow
{
}

-(BOOL)canBecomeKeyWindow;

@end
