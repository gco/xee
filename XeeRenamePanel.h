#import <Cocoa/Cocoa.h>

@class XeeController;

@interface XeeRenamePanel:NSWindow
{
	id enddelegate;
	SEL endselector;
	BOOL sheet;

	IBOutlet XeeController *controller;
	IBOutlet NSTextField *namefield;
}

-(void)run:(NSWindow *)window filename:(NSString *)filename
delegate:(id)delegate didEndSelector:(SEL)selector;

-(IBAction)cancelClick:(id)sender;
-(IBAction)renameClick:(id)sender;
-(void)endWithReturnCode:(int)res filename:(NSString *)newname;

@end
