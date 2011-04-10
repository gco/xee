#import "XeeControllerNavigationActions.h"
#import "XeeImageSource.h"

@implementation XeeController (NavigationActions)

-(IBAction)skipNext:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[source skip:1];
	[self setResizeBlock:NO];
}

-(IBAction)skipPrev:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[source skip:-1];
	[self setResizeBlock:NO];
}

-(IBAction)skipFirst:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[source pickFirstImage];
	[self setResizeBlock:NO];
}

-(IBAction)skipLast:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[source pickLastImage];
	[self setResizeBlock:NO];
}

-(IBAction)skip10Forward:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[source skip:10];
	[self setResizeBlock:NO];
}

-(IBAction)skip100Forward:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[source skip:100];
	[self setResizeBlock:NO];
}

-(IBAction)skip10Back:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[source skip:-10];
	[self setResizeBlock:NO];
}

-(IBAction)skip100Back:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[source skip:-100];
	[self setResizeBlock:NO];
}

-(IBAction)skipRandom:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[source pickNextImageAtRandom];
	[self setResizeBlock:NO];
}

-(IBAction)skipRandomPrev:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[source pickPreviousImageAtRandom];
	[self setResizeBlock:NO];
}



-(IBAction)setSortOrder:(id)sender
{
	[source setSortOrder:[sender tag]];
}



-(IBAction)runSlideshow:(id)sender
{
	if(slideshowtimer)
	{
		[slideshowtimer invalidate];
		[slideshowtimer release];
		slideshowtimer=nil;
	}
	else
	{
		slideshowcount=0;
		slideshowtimer=[[NSTimer scheduledTimerWithTimeInterval:1
		target:self selector:@selector(slideshowStep:) userInfo:nil repeats:YES] retain];
	}
}

-(IBAction)setSlideshowDelay:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setInteger:[sender tag] forKey:@"slideshowDelay"];
}

-(IBAction)setCustomSlideshowDelay:(id)sender
{
	if(!delaypanel)
	{
		NSNib *nib=[[[NSNib alloc] initWithNibNamed:@"SlideshowDelayPanel" bundle:nil] autorelease];
		[nib instantiateNibWithOwner:self topLevelObjects:nil];
	}

	int delay=[[NSUserDefaults standardUserDefaults] integerForKey:@"slideshowCustomDelay"];
	if(!delay) delay=[[NSUserDefaults standardUserDefaults] integerForKey:@"slideshowDelay"];
	[delayfield setIntValue:delay];

	if(fullscreenwindow)
	{
		[delaypanel makeKeyAndOrderFront:nil];
		delaysheet=NO;
	}
	else
	{
		[NSApp beginSheet:delaypanel modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
		delaysheet=YES;
	}
}

-(IBAction)delayPanelOK:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setInteger:[delayfield intValue] forKey:@"slideshowCustomDelay"];
	[[NSUserDefaults standardUserDefaults] setInteger:[delayfield intValue] forKey:@"slideshowDelay"];

	if(delaysheet) [NSApp endSheet:delaypanel];
	[delaypanel orderOut:nil];
}

-(IBAction)delayPanelCancel:(id)sender
{
	if(delaysheet) [NSApp endSheet:delaypanel];
	[delaypanel orderOut:nil];
}

-(void)slideshowStep:(NSTimer *)timer
{
	// Prevent sleeping
	UpdateSystemActivity(UsrActivity);

	int slideshowdelay=[[NSUserDefaults standardUserDefaults] integerForKey:@"slideshowDelay"];
	if(++slideshowcount>=slideshowdelay)
	{
		slideshowcount=0;

		if([[NSUserDefaults standardUserDefaults] boolForKey:@"randomizeSlideshow"])
		{
			[source pickNextImageAtRandom];
		}
		else
		{
			if([source indexOfCurrentImage]<[source numberOfImages]-1
			||[[NSUserDefaults standardUserDefaults] boolForKey:@"wrapImageBrowsing"])
			[source skip:1];
			else
			{
				[slideshowtimer invalidate];
				[slideshowtimer release];
				slideshowtimer=nil;
			}
		}
	}
}

-(BOOL)isSlideshowRunning { return slideshowtimer?YES:NO; }

@end
