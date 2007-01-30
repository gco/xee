#import <Cocoa/Cocoa.h>

@class XeeImage,XeeController;

@interface XeeRenamePanel:NSWindow
{
	XeeImage *image;
	BOOL sheet;

	IBOutlet XeeController *controller;
	IBOutlet NSTextField *namefield;
}

-(void)run:(NSWindow *)window image:(XeeImage *)img;
-(IBAction)cancelClick:(id)sender;
-(IBAction)renameClick:(id)sender;

@end
