#import "XeeRenamePanel.h"
#import "XeeImage.h"
#import "XeeControllerFileActions.h"
#import "XeeStringAdditions.h"


@implementation XeeRenamePanel

-(void)run:(NSWindow *)window filename:(NSString *)filename
delegate:(id)delegate didEndSelector:(SEL)selector
{
	enddelegate=delegate;
	endselector=selector;

	[namefield setStringValue:filename];

	if(window)
	{
		sheet=YES;
		[NSApp beginSheet:self modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
	}
	else
	{
		sheet=NO;
		[self makeKeyAndOrderFront:nil];
	}

	[self makeFirstResponder:namefield];
	[[namefield currentEditor] setSelectedRange:NSMakeRange(0,[[filename stringByDeletingPathExtension] length])];
}

-(void)cancelClick:(id)sender
{
	[self endWithReturnCode:0 filename:nil];
}

-(void)renameClick:(id)sender
{
	[self endWithReturnCode:1 filename:[namefield stringValue]];
}

-(void)endWithReturnCode:(int)res filename:(NSString *)newname
{
	if(sheet) [NSApp endSheet:self];
	[self orderOut:nil];

	NSInvocation *invocation=[NSInvocation invocationWithMethodSignature:[enddelegate methodSignatureForSelector:endselector]];
	[invocation setSelector:endselector];
	[invocation setArgument:&self atIndex:2];
	[invocation setArgument:&res atIndex:3];
	[invocation setArgument:&newname atIndex:4];

	[invocation invokeWithTarget:enddelegate];
}

@end
