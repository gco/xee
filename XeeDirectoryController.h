#import <Cocoa/Cocoa.h>

#import "XeeController.h"

#define XeeNoMode 0
#define XeeMoveMode 1
#define XeeCopyMode 2



@class XeeImage,XeeView,XeeCollisionPanel,XeeRenamePanel,XeeStatusCell;



@interface XeeDirectoryController:XeeController
{
	NSString *directory;
	NSMutableArray *dircontents;

	NSRecursiveLock *loadlock;
	BOOL loader_running;
	BOOL exiting;

	XeeImage *previmage,*nextimage;
	int previndex,currindex,nextindex;

	XeeImage *loadingimage;

	int *randomlist;

	int drawer_mode;

	XeeStatusCell *filescell,*zoomcell,*framescell,*rescell,*colourscell,*filesizecell,*formatcell,*filenamecell,*datecell,*messagecell,*errorcell;

    IBOutlet NSDrawer *drawer;
	IBOutlet NSSegmentedControl *drawerseg;
	IBOutlet NSTableView *table;
	IBOutlet NSButton *closebutton;
	IBOutlet XeeCollisionPanel *collisionpanel;
	IBOutlet XeeRenamePanel *renamepanel;
}

-(id)init;
-(void)dealloc;
-(void)windowWillClose:(NSNotification *)notification;
-(NSRect)availableScreenSpace;
-(NSSize)minViewSize;

-(BOOL)loadImage:(NSString *)filename;

-(void)displayImage:(int)index next:(int)next;
-(XeeImage *)imageAtIndex:(int)index;
-(void)setCurrentImage:(XeeImage *)image index:(int)index;
-(void)setPreviousImage:(XeeImage *)image index:(int)index;
-(void)setNextImage:(XeeImage *)image index:(int)index;

-(void)reloadImage;

-(void)imageLoader:(id)nothing;
-(void)launchLoader;

-(void)setupStatusBar;
-(void)updateStatusBar;

-(void)sortFiles;
-(int)findFile:(NSString *)filename;
-(int)findNextFile:(NSString *)filename;
-(void)removeFile:(NSString *)filename;
-(void)insertFile:(NSString *)filename;

-(NSDrawer *)drawer;
-(NSString *)directory;
-(NSString *)currentFilename;

-(IBAction)skipNext:(id)sender;
-(IBAction)skipPrev:(id)sender;
-(IBAction)skipFirst:(id)sender;
-(IBAction)skipLast:(id)sender;
-(IBAction)skip10Forward:(id)sender;
-(IBAction)skip100Forward:(id)sender;
-(IBAction)skip10Back:(id)sender;
-(IBAction)skip100Back:(id)sender;
-(void)skipToFile:(NSString *)filename;
-(void)skip:(int)step;

-(IBAction)skipRandom:(id)sender;
-(IBAction)skipRandomPrev:(id)sender;
-(void)buildRandomList;
-(void)freeRandomList;

-(IBAction)revealInFinder:(id)sender;

-(IBAction)renameFileFromMenu:(id)sender;
-(void)renameFile:(NSString *)filename to:(NSString *)newname;

-(IBAction)deleteFileFromMenu:(id)sender;
-(IBAction)askAndDelete:(id)sender;
-(void)deleteAlertEnd:(NSAlert *)alert returnCode:(int)res contextInfo:(NSString *)filename;
-(void)deleteFile:(NSString *)filename;

-(IBAction)moveFile:(id)sender;
-(IBAction)copyFile:(id)sender;
-(void)triggerDrawer:(int)mode;
-(void)drawerDidClose:(NSNotification *)notification;
-(void)destinationListClick:(id)sender;
-(void)destinationPanelEnd:(NSOpenPanel *)panel returnCode:(int)res contextInfo:(NSString *)filename;
-(void)attemptToTransferFile:(NSString *)filename to:(NSString *)destination mode:(int)mode;
-(void)transferFile:(NSString *)filename to:(NSString *)destination mode:(int)mode;

-(void)playSound:(NSString *)filename;
-(void)actuallyPlaySound:(NSString *)filename;

/*-(IBAction)jpegAutoRotate:(id)sender;
-(IBAction)jpegRotateCW:(id)sender;
-(IBAction)jpegRotateCCW:(id)sender;
-(IBAction)jpegRotate180:(id)sender;
-(IBAction)jpegFlipHorizontal:(id)sender;
-(IBAction)jpegFlipVertical:(id)sender;

-(void)jpegTransform:(NSString *)option;*/

-(IBAction)launchAppFromMenu:(id)sender;
-(IBAction)launchDefaultEditor:(id)sender;

-(IBAction)closeWindowOrDrawer:(id)sender;

-(void)errorMessage:(NSString *)title text:(NSString *)text;

-(NSArray *)makeToolbarItems;
-(NSArray *)makeDefaultToolbarItemIdentifiers;

-(BOOL)validateAction:(SEL)action;

+(void)initialize;
+(NSArray *)controllers;

-(void)scrollWheel:(NSEvent *)event;

@end



@interface XeeDirectoryWindow:XeeDisplayWindow
{
	IBOutlet XeeDirectoryController *controller;
}

@end
