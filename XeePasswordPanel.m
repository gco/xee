#import "XeePasswordPanel.h"


@implementation XeePasswordPanel

-(NSString *)runModalForWindow:(NSWindow *)window
{
	[passwordfield setStringValue:@""];
	[self makeFirstResponder:passwordfield];

	if(window) [NSApp beginSheet:self modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];

	int res=[NSApp runModalForWindow:self];

	if(window) [NSApp endSheet:self];
	[self orderOut:nil];

	if(res) return [passwordfield stringValue];
	else return nil;
}

-(void)cancelClick:(id)sender
{
	[NSApp stopModalWithCode:0];
}

-(void)openClick:(id)sender
{
	[NSApp stopModalWithCode:1];
}

@end
