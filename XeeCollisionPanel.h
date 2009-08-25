#import <Cocoa/Cocoa.h>

#define XeeCollisionCancel 0
#define XeeCollisionReplace 1
#define XeeCollisionRename 2

@class XeeImage,XeeController,XeeView;

@interface XeeCollisionPanel:NSWindow
{
	XeeImage *srcimage,*destimage;
	int transfermode;
	BOOL sheet;

	IBOutlet XeeController *controller;
	IBOutlet XeeView *icon;
	IBOutlet NSTextField *titlefield;
	IBOutlet NSTextField *oldsize;
	IBOutlet NSTextField *oldformat;
	IBOutlet NSTextField *olddate;
	IBOutlet NSTextField *newsize;
	IBOutlet NSTextField *newformat;
	IBOutlet NSTextField *newdate;
	IBOutlet NSTextField *namefield;
	IBOutlet NSButton *renamebutton;
	IBOutlet NSButton *replacebutton;
}

-(void)run:(NSWindow *)window source:(XeeImage *)srcimage destination:(XeeImage *)destimage mode:(int)mode;
-(void)loadThumbnail:(XeeImage *)image;
-(IBAction)cancelClick:(id)sender;
-(IBAction)renameClick:(id)sender;
-(IBAction)replaceClick:(id)sender;
-(void)controlTextDidChange:(NSNotification *)notification;

@end
