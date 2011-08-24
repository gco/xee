#import <Cocoa/Cocoa.h>

#import "KFTypeSelectTableView.h"



void XeePlayPoof(NSWindow *somewindow);
double XeeGetTime();



@class XeeImage,XeeDirectoryController,XeeView;

#define XeeCollisionCancel 0
#define XeeCollisionReplace 1
#define XeeCollisionRename 2

@interface XeeCollisionPanel:NSWindow
{
	XeeImage *srcimage,*destimage;
	int transfermode;

	IBOutlet XeeDirectoryController *controller;
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



@interface XeeRenamePanel:NSWindow
{
	XeeImage *image;
	BOOL sheet;

	IBOutlet XeeDirectoryController *controller;
	IBOutlet NSTextField *namefield;
}

-(void)run:(NSWindow *)window image:(XeeImage *)img;
-(IBAction)cancelClick:(id)sender;
-(IBAction)renameClick:(id)sender;

@end



@interface XeeFiletypeListSource:NSObject
{
	NSArray *filetypes;
}

-(int)numberOfRowsInTableView:(NSTableView *)table;
-(id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(int)row;
-(void)tableView:(NSTableView *)table setObjectValue:(id)object forTableColumn:(NSTableColumn *)column row:(int)row;

@end
