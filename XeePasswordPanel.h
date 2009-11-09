#import <Cocoa/Cocoa.h>

@class XeeController;

@interface XeePasswordPanel:NSWindow
{
	BOOL sheet;
	IBOutlet XeeController *controller;
	IBOutlet NSSecureTextField *passwordfield;
}

-(NSString *)runModalForWindow:(NSWindow *)window;

-(IBAction)cancelClick:(id)sender;
-(IBAction)openClick:(id)sender;

@end
