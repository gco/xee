#import "XeeSegmentedItem.h"
#import "XeeController.h"



@implementation XeeSegmentedItem

+(XeeSegmentedItem *)itemWithIdentifier:(NSString *)identifier label:(NSString *)label paletteLabel:(NSString *)pallabel segments:(int)segments
{
	return [[[XeeSegmentedItem alloc] initWithItemIdentifier:identifier label:label paletteLabel:pallabel segments:segments] autorelease];
}

-(id)initWithItemIdentifier:(NSString *)identifier label:(NSString *)label paletteLabel:(NSString *)pallabel segments:(int)segments
{
	if(self=[super initWithItemIdentifier:identifier])
	{
		[self setLabel:label];
		[self setPaletteLabel:pallabel];

		control=[[NSSegmentedControl alloc] init];
		[control setSegmentCount:segments];
		[[control cell] setTrackingMode:NSSegmentSwitchTrackingMomentary];

		if(segments!=1)
		{
			menu=[[NSMenu alloc] init];

			for(int i=0;i<segments;i++)
			[menu addItem:[[[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""] autorelease]];

			NSMenuItem *item=[[[NSMenuItem alloc] initWithTitle:pallabel action:NULL keyEquivalent:@""] autorelease];
			[item setSubmenu:menu];

			[self setMenuFormRepresentation:item];
		}
		else
		{
			NSMenuItem *item=[[[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""] autorelease];
			[self setMenuFormRepresentation:item];
			menu=nil;
		}

		[control setTarget:self];
		[control setAction:@selector(clicked:)];

		actions=malloc(sizeof(SEL)*segments);
	}
	return self;
}

-(void)dealloc
{
	[control release];
	[menu release];

	free(actions);

	[super dealloc];
}

-(void)validate
{
	if([[NSApplication sharedApplication] mainWindow]!=[control window]) [self setEnabled:NO];
	else
	{
		[self setEnabled:YES];

		int count=[control segmentCount];
		for(int i=0;i<count;i++)
		{
			XeeController *controller=(XeeController *)[[control window] delegate];
			[control setEnabled:[controller validateAction:actions[i]] forSegment:i];
		}
	}
}

-(void)setSegment:(int)segment label:(NSString *)label image:(NSImage *)image longLabel:(NSString *)longlabel width:(int)width action:(SEL)action
{
	if(segment<0 || segment>=[control segmentCount]) return;

	[control setLabel:label forSegment:segment];
	[control setImage:image forSegment:segment];
	[control setWidth:width forSegment:segment];
	[[control cell] setToolTip:longlabel forSegment:segment];

	actions[segment]=action;

	NSMenuItem *item;
	if(menu) item=[menu itemAtIndex:segment];
	else item=[self menuFormRepresentation];

	[item setTitle:longlabel];
	[item setImage:image];
	[item setAction:action];
}

-(void)setSegment:(int)segment label:(NSString *)label longLabel:(NSString *)longlabel action:(SEL)action
{
	[self setSegment:segment label:label image:nil longLabel:longlabel width:0 action:action];
}

-(void)setSegment:(int)segment imageName:(NSString *)imagename longLabel:(NSString *)longlabel action:(SEL)action
{
	NSImage *image=[NSImage imageNamed:imagename];
	[self setSegment:segment label:nil image:image longLabel:longlabel width:[image size].width action:action];
}

-(void)setupView
{
	[control sizeToFit];
	[self setView:control];
	[self setMinSize:[control frame].size];
	[self setMaxSize:[control frame].size];
}

-(void)clicked:(id)sender
{
	[[NSApplication sharedApplication] sendAction:actions[[sender selectedSegment]] to:nil from:self];
}

@end



@implementation XeeToolItem

+(XeeSegmentedItem *)itemWithIdentifier:(NSString *)identifier label:(NSString *)label
paletteLabel:(NSString *)pallabel imageName:(NSString *)imagename longLabel:(NSString *)longlabel
action:(SEL)action activeSelector:(SEL)activeselector target:(id)activetarget
{
	return [[[XeeToolItem alloc] initWithItemIdentifier:identifier label:label
	paletteLabel:pallabel imageName:imagename longLabel:longlabel action:action
	activeSelector:activeselector target:activetarget] autorelease];
}

-(id)initWithItemIdentifier:(NSString *)identifier label:(NSString *)label
paletteLabel:(NSString *)pallabel imageName:(NSString *)imagename longLabel:(NSString *)longlabel
action:(SEL)action activeSelector:(SEL)activeselector target:(id)activetarget
{
	if(self=[super initWithItemIdentifier:identifier label:label paletteLabel:pallabel segments:1])
	{
		sel=activeselector;
		target=activetarget;

		[[control cell] setTrackingMode:NSSegmentSwitchTrackingSelectAny];

		[self setSegment:0 imageName:imagename longLabel:longlabel action:action];
		[self setupView];
	}
	return self;
}

-(void)validate
{
	[super validate];

	BOOL active=target&&(BOOL)(int)[target performSelector:sel];

	[control setSelected:active forSegment:0];
//	[[self menuFormRepresentation] setState:active?NSOnState:NSOffState]; // doesn't work?
}

@end



@implementation NSSegmentedCell (AlwaysTextured)

-(BOOL)_isTextured  { return YES; }

@end
