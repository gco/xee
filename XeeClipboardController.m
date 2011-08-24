#import "XeeClipboardController.h"
#import "XeeStatusBar.h"
#import "XeeImage.h"
#import "XeeSegmentedItem.h"



@implementation XeeClipboardWindow

@end




@implementation XeeClipboardController

-(void)setupStatusBar
{
	zoomcell=[XeeStatusCell statusWithImageNamed:@"zoom" title:@""];
	rescell=[XeeStatusCell statusWithImageNamed:@"size" title:@""];
	colourscell=[XeeStatusCell statusWithImageNamed:@"" title:@""];

	[statusbar addCell:zoomcell priority:3];
	[statusbar addCell:rescell priority:2];
	[statusbar addCell:colourscell priority:1];

	[statusbar setHiddenFrom:0 to:2 values:NO,NO,NO];
}

-(void)updateStatusBar
{
	[zoomcell setTitle:[NSString stringWithFormat:@"%d%%",(int)(zoom*100)]];
	[rescell setTitle:[NSString stringWithFormat:@"%dx%d",[currimage width],[currimage height]]];
	[colourscell setTitle:[currimage depth]];
	[colourscell setImage:[currimage depthIcon]];

	[statusbar setNeedsDisplay:YES];
}

-(NSArray *)makeToolbarItems
{
	XeeSegmentedItem *zoomtool=[XeeSegmentedItem itemWithIdentifier:@"zoom"
	label:NSLocalizedString(@"Zoom",@"Zoom toolbar segment title")
	paletteLabel:NSLocalizedString(@"Zoom",@"Zoom toolbar segment title") segments:4];
	[zoomtool setSegment:0 imageName:@"tool_zoomin" longLabel:NSLocalizedString(@"Zoom In",@"Zoom In toolbar button label") action:@selector(zoomIn:)];
	[zoomtool setSegment:1 imageName:@"tool_zoomout" longLabel:NSLocalizedString(@"Zoom Out",@"Zoom Out toolbar button label") action:@selector(zoomOut:)];
	[zoomtool setSegment:2 imageName:@"tool_zoomactual" longLabel:NSLocalizedString(@"Actual Size",@"Actual Size toolbar button label") action:@selector(zoomActual:)];
	[zoomtool setSegment:3 imageName:@"tool_zoomfit" longLabel:NSLocalizedString(@"Fit On Screen",@"Fit On Screen toolbar button label") action:@selector(zoomFit:)];
	[zoomtool setupView];

	return [NSArray arrayWithObjects:
		zoomtool,
	0];
}

-(NSArray *)makeDefaultToolbarItemIdentifiers
{
	return [NSArray arrayWithObjects:
		@"zoom",
	0];
}

@end
