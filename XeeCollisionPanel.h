#import <Cocoa/Cocoa.h>

#define XeeCollisionCancel 0
#define XeeCollisionReplace 1
#define XeeCollisionRename 2

@class XeeImage,XeeController,XeeView;

@interface XeeCollisionPanel:NSWindow
{
	id enddelegate;
	SEL endselector;

	NSString *destinationpath;
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

-(void)run:(NSWindow *)window sourceImage:(XeeImage *)srcimage size:(off_t)srcsize
date:(NSDate *)srcdate destinationPath:(NSString *)destpath mode:(int)mode
delegate:(id)delegate didEndSelector:(SEL)selector;

-(void)loadThumbnail:(XeeImage *)image;

-(IBAction)cancelClick:(id)sender;
-(IBAction)renameClick:(id)sender;
-(IBAction)replaceClick:(id)sender;
-(void)endWithReturnCode:(int)res path:(NSString *)destination;

-(void)controlTextDidChange:(NSNotification *)notification;

@end
