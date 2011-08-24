#import <Cocoa/Cocoa.h>

#import "XeeController.h"



@class XeeStatusCell;



@interface XeeClipboardController:XeeController
{
	XeeStatusCell *zoomcell,*rescell,*colourscell;
}

-(void)setupStatusBar;
-(void)updateStatusBar;

-(NSArray *)makeToolbarItems;
-(NSArray *)makeDefaultToolbarItemIdentifiers;

@end



@interface XeeClipboardWindow:XeeDisplayWindow
{
}

@end
