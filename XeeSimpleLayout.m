#import "XeeSimpleLayout.h"



@implementation XeeSimpleLayout:NSView

-(id)initWithControl:(XeeSLControl *)content
{
	if(self=[super initWithFrame:NSZeroRect])
	{
		delegate=nil;

		control=[content retain];
		[control addElementsToSuperview:self];

		[self layout];
	}
	return self;
}

-(void)dealloc
{
	[super dealloc];
}

-(BOOL)isFlipped { return YES; }

-(void)layout
{
	int titlewidth=[control titleWidth];
	int contentwidth=[control contentWidth];
	int height=[control height];

	/*if([self frame].size.height==0)*/ [self setFrameSize:NSMakeSize(titlewidth+contentwidth,height)];
	[control layoutContent:NSMakeRect(titlewidth,0,contentwidth,height) title:NSMakeRect(0,0,titlewidth,height)];

	[self setNeedsDisplay:YES];
}

-(void)requestLayout
{
	[self layout];

	if(delegate&&[delegate respondsToSelector:@selector(xeeSLUpdated:)])
	[delegate performSelectorOnMainThread:@selector(xeeSLUpdated:) withObject:self waitUntilDone:NO];
}

-(void)setDelegate:(id)newdelegate
{
	[delegate autorelease];
	delegate=[newdelegate retain];
}

-(id)delegate
{
	return delegate;
}

@end



@implementation XeeSLControl

-(id)initWithTitle:(NSString *)title
{
	if(self=[super init])
	{
		delegate=nil;
		parent=nil;

		if(title)
		{
			titlefield=[[NSTextField alloc] initWithFrame:NSZeroRect];
			[titlefield setStringValue:title];
			[titlefield setEditable:NO];
			[titlefield setBezeled:NO];
			[titlefield setDrawsBackground:NO];
			[titlefield sizeToFit];
		}
		else titlefield=nil;
	}
	return self;
}

-(void)dealloc
{
	[titlefield release];
	[super dealloc];
}

-(int)height { return [titlefield frame].size.height; }
-(int)topSpacing { return 0; }
-(int)bottomSpacing { return 0; }
-(int)contentWidth { return 0; }
-(int)titleWidth { return titlefield?[titlefield frame].size.width+2:0; }

-(void)addElementsToSuperview:(XeeSimpleLayout *)superview
{
	if(titlefield) [superview addSubview:titlefield];
	[parent release];
	parent=[superview retain];
}

-(void)layoutContent:(NSRect)contentrect title:(NSRect)titlerect
{
	if(titlefield)
	{
		NSRect frame=[titlefield frame];
		[titlefield setFrameOrigin:NSMakePoint(titlerect.origin.x+titlerect.size.width-frame.size.width-2,titlerect.origin.y)];
	}
}

-(void)setHidden:(BOOL)hidden
{
	[titlefield setHidden:hidden];
}

-(void)setDelegate:(id)newdelegate
{
	[delegate autorelease];
	delegate=[newdelegate retain];
}

-(id)delegate
{
	return delegate;
}

@end



@implementation XeeSLGroup:XeeSLControl

-(id)initWithControls:(NSArray *)controlarray
{
	if(self=[super initWithTitle:nil])
	{
		controls=[controlarray retain];
	}
	return self;
}

-(void)dealloc
{
	[controls release];
	[super dealloc];
}

-(int)height
{
	NSEnumerator *enumerator=[controls objectEnumerator];
	XeeSLControl *control;
	int height=0;
	int prevspacing=-1;

	while(control=[enumerator nextObject])
	{
		int currheight=[control height];
		int topspacing=[control topSpacing];
		int bottomspacing=[control bottomSpacing];

		if(prevspacing!=-1) height+=MAX(prevspacing,topspacing);
		height+=currheight;

		prevspacing=bottomspacing;
	}

	return height;
}

-(int)topSpacing { return [[controls objectAtIndex:0] topSpacing]; }

-(int)bottomSpacing { return [[controls lastObject] bottomSpacing]; }

-(int)contentWidth
{
	NSEnumerator *enumerator=[controls objectEnumerator];
	XeeSLControl *control;
	int width=0;

	while(control=[enumerator nextObject])
	{
		int currwidth=[control contentWidth];
		if(currwidth>width) width=currwidth;
	}

	return width;
}

-(int)titleWidth
{
	NSEnumerator *enumerator=[controls objectEnumerator];
	XeeSLControl *control;
	int width=0;

	while(control=[enumerator nextObject])
	{
		int currwidth=[control titleWidth];
		if(currwidth>width) width=currwidth;
	}
	return width;
}

-(void)addElementsToSuperview:(XeeSimpleLayout *)superview
{
	[controls makeObjectsPerformSelector:@selector(addElementsToSuperview:) withObject:superview];
}

-(void)layoutContent:(NSRect)contentrect title:(NSRect)titlerect
{
	NSEnumerator *enumerator=[controls objectEnumerator];
	XeeSLControl *control;
	int y=contentrect.origin.y;
	int prevspacing=-1;

	while(control=[enumerator nextObject])
	{
		int currheight=[control height];
		int topspacing=[control topSpacing];
		int bottomspacing=[control bottomSpacing];

		if(prevspacing!=-1) y+=MAX(prevspacing,topspacing);

		titlerect.size.height=contentrect.size.height=currheight;
		titlerect.origin.y=contentrect.origin.y=y;

		[control layoutContent:contentrect title:titlerect];

		y+=currheight;
		prevspacing=bottomspacing;
	}
}

-(void)setHidden:(BOOL)hidden
{
	[super setHidden:hidden];

	NSEnumerator *enumerator=[controls objectEnumerator];
	XeeSLControl *control;
	while(control=[enumerator nextObject]) [control setHidden:hidden];
}

+(XeeSLGroup *)groupWithControls:(XeeSLControl *)control,...
{
	NSMutableArray *controls=[[[NSMutableArray alloc] initWithObjects:&control count:1] autorelease];
	id obj;
	va_list va;

	va_start(va,control);
	while(obj=va_arg(va,id)) [controls addObject:obj];
	va_end(va);

	return [[[XeeSLGroup alloc] initWithControls:controls] autorelease];
}

@end



@implementation XeeSLPopUp:XeeSLControl

-(id)initWithTitle:(NSString *)title contents:(NSArray *)contents defaultValue:(int)def
{
	if(self=[super initWithTitle:title])
	{
		popup=[[NSPopUpButton alloc] initWithFrame:NSZeroRect];
		[popup addItemsWithTitles:contents];

		maxwidth=0;
		for(int i=0;i<[popup numberOfItems];i++)
		{
			[popup selectItemAtIndex:i];
			[popup sizeToFit];
			int width=[popup frame].size.width;
			if(width>maxwidth) maxwidth=width;
		}

		[popup selectItemAtIndex:def];
	}
	return self;
}

-(void)dealloc
{
	[popup release];
	[super dealloc];
}

-(int)height { return 26; }
-(int)topSpacing { return 4; }
-(int)bottomSpacing { return 4; }
-(int)contentWidth { return maxwidth; }

-(void)addElementsToSuperview:(XeeSimpleLayout *)superview
{
	[superview addSubview:popup];
	[super addElementsToSuperview:superview];
}

-(void)layoutContent:(NSRect)contentrect title:(NSRect)titlerect
{
	[popup setFrame:contentrect];

	titlerect.origin.y+=4;
	titlerect.size.height-=4;
	[super layoutContent:contentrect title:titlerect];
}

-(void)setHidden:(BOOL)hidden
{
	[super setHidden:hidden];
	[popup setHidden:hidden];
}

-(int)value
{
	return [popup indexOfSelectedItem];
}

+(XeeSLPopUp *)popUpWithTitle:(NSString *)title defaultValue:(int)def contents:(NSString *)entry,...
{
	NSMutableArray *contents=[[[NSMutableArray alloc] initWithObjects:&entry count:1] autorelease];
	id obj;
	va_list va;

	va_start(va,entry);
	while(obj=va_arg(va,id)) [contents addObject:obj];
	va_end(va);

	return [[[XeeSLPopUp alloc] initWithTitle:title contents:contents defaultValue:def] autorelease];
}


@end




@implementation XeeSLSwitch:XeeSLControl

-(id)initWithTitle:(NSString *)title label:(NSString *)label defaultValue:(BOOL)def;
{
	if(self=[super initWithTitle:title])
	{
		check=[[NSButton alloc] initWithFrame:NSZeroRect];
		[check setButtonType:NSSwitchButton];
		[check setTitle:label];
		if(def) [check setState:NSOnState];
		[check sizeToFit];
	}
	return self;
}

-(void)dealloc
{
	[check release];
	[super dealloc];
}

-(int)height { return 18; }
-(int)topSpacing { return 2; }
-(int)bottomSpacing { return 2; }
-(int)contentWidth { return [check frame].size.width; }

-(void)addElementsToSuperview:(XeeSimpleLayout *)superview
{
	[superview addSubview:check];
	[super addElementsToSuperview:superview];
}

-(void)layoutContent:(NSRect)contentrect title:(NSRect)titlerect
{
	[check setFrameOrigin:contentrect.origin];
	[super layoutContent:contentrect title:titlerect];
}

-(void)setHidden:(BOOL)hidden
{
	[super setHidden:hidden];
	[check setHidden:hidden];
}

-(BOOL)value
{
	return [check state]==NSOnState;
}

+(XeeSLSwitch *)switchWithTitle:(NSString *)title label:(NSString *)label defaultValue:(BOOL)def
{
	return [[[XeeSLSwitch alloc] initWithTitle:title label:label defaultValue:def] autorelease];
}

@end



@implementation XeeSLSlider:XeeSLControl

-(id)initWithTitle:(NSString *)title minLabel:(NSString *)minlabel maxLabel:(NSString *)maxlabel min:(float)minval max:(float)maxval defaultValue:(float)def
{
	if(self=[super initWithTitle:title])
	{
		slider=[[NSSlider alloc] initWithFrame:NSZeroRect];
		[slider setMinValue:minval];
		[slider setMaxValue:maxval];
		[slider setNumberOfTickMarks:11];
		[slider setFloatValue:def];
		[slider sizeToFit];

		minfield=[[NSTextField alloc] initWithFrame:NSZeroRect];
		[minfield setStringValue:minlabel];
		[minfield setEditable:NO];
		[minfield setBezeled:NO];
		[minfield setDrawsBackground:NO];
		[minfield setFont:[NSFont labelFontOfSize:9]];
		[minfield sizeToFit];

		maxfield=[[NSTextField alloc] initWithFrame:NSZeroRect];
		[maxfield setStringValue:maxlabel];
		[maxfield setEditable:NO];
		[maxfield setBezeled:NO];
		[maxfield setDrawsBackground:NO];
		[maxfield setAlignment:NSRightTextAlignment];
		[maxfield setFont:[NSFont labelFontOfSize:9]];
		[maxfield sizeToFit];
	}
	return self;
}

-(void)dealloc
{
	[slider release];
	[minfield release];
	[maxfield release];
	[super dealloc];
}

-(int)height { return 44; }
-(int)topSpacing { return 6; }
-(int)bottomSpacing { return 6; }
-(int)contentWidth { return 3*([minfield frame].size.width+[maxfield frame].size.width)/2; }

-(void)addElementsToSuperview:(XeeSimpleLayout *)superview
{
	[superview addSubview:slider];
	[superview addSubview:minfield];
	[superview addSubview:maxfield];
	[super addElementsToSuperview:superview];
}

-(void)layoutContent:(NSRect)contentrect title:(NSRect)titlerect
{
	int sliderheight=33;

	contentrect.size.height=sliderheight;
	[slider setFrame:contentrect];

	[minfield setFrameOrigin:NSMakePoint(contentrect.origin.x,contentrect.origin.y+sliderheight)];
	[maxfield setFrameOrigin:NSMakePoint(contentrect.origin.x+contentrect.size.width-[maxfield frame].size.width,contentrect.origin.y+sliderheight)];

	[super layoutContent:contentrect title:titlerect];
}

-(void)setHidden:(BOOL)hidden
{
	[super setHidden:hidden];
	[slider setHidden:hidden];
	[minfield setHidden:hidden];
	[maxfield setHidden:hidden];
}

-(float)value
{
	return [slider floatValue];
}

+(XeeSLSlider *)sliderWithTitle:(NSString *)title minLabel:(NSString *)minlabel maxLabel:(NSString *)maxlabel min:(float)minval max:(float)maxval defaultValue:(float)def
{
	return [[[XeeSLSlider alloc] initWithTitle:title minLabel:minlabel maxLabel:maxlabel min:minval max:maxval defaultValue:def] autorelease];
}

@end




@implementation XeeSLPages:XeeSLPopUp

-(id)initWithTitle:(NSString *)title pages:(NSArray *)pagearray names:(NSArray *)namearray defaultValue:(int)def
{
	NSAssert([pagearray count]==[namearray count],@"Page and name counts do not match");

	if(self=[super initWithTitle:title contents:namearray defaultValue:def])
	{
		pages=[pagearray retain];

		[popup setAction:@selector(pageChanged:)];
		[popup setTarget:self];
	}
	return self;
}

-(void)dealloc
{
	[pages release];
	
	[super dealloc];
}

-(int)height
{
	XeeSLControl *content=[pages objectAtIndex:[self value]];
	int selectorheight=[super height];
	int selectorbottom=[super bottomSpacing];

	if((id)content==[NSNull null]) return selectorheight;

	int contenttop=[content topSpacing];
	int contentheight=[content height];

	return selectorheight+MAX(selectorbottom,contenttop)+contentheight;
}

-(int)bottomSpacing
{
	XeeSLControl *content=[pages objectAtIndex:[self value]];

	if((id)content==[NSNull null]) return [super bottomSpacing];
	else return [content bottomSpacing];
}

-(int)contentWidth
{
	NSEnumerator *enumerator=[pages objectEnumerator];
	XeeSLControl *control;
	int width=[super contentWidth];

	while(control=[enumerator nextObject])
	{
		if((id)control==[NSNull null]) continue;
		int currwidth=[control contentWidth];
		if(currwidth>width) width=currwidth;
	}

	return width;
}

-(int)titleWidth
{
	NSEnumerator *enumerator=[pages objectEnumerator];
	XeeSLControl *control;
	int width=[super titleWidth];

	while(control=[enumerator nextObject])
	{
		if((id)control==[NSNull null]) continue;
		int currwidth=[control titleWidth];
		if(currwidth>width) width=currwidth;
	}

	return width;
}

-(void)addElementsToSuperview:(XeeSimpleLayout *)superview
{
	[super addElementsToSuperview:superview];

	NSEnumerator *enumerator=[pages objectEnumerator];
	XeeSLControl *control;

	while(control=[enumerator nextObject])
	{
		if((id)control==[NSNull null]) continue;
		[control addElementsToSuperview:superview];
	}
}

-(void)layoutContent:(NSRect)contentrect title:(NSRect)titlerect
{
	int page=[self value];
	XeeSLControl *content=[pages objectAtIndex:page];

	int selectorheight=[super height];
	int selectorbottom=[super bottomSpacing];

	titlerect.size.height=contentrect.size.height=selectorheight;
	[super layoutContent:contentrect title:titlerect];

	if((id)content!=[NSNull null])
	{
		int contenttop=[content topSpacing];
		int contentheight=[content height];

		titlerect.origin.y+=selectorheight+MAX(selectorbottom,contenttop);
		contentrect.origin.y+=selectorheight+MAX(selectorbottom,contenttop);
		titlerect.size.height=contentrect.size.height=contentheight;

		[content layoutContent:contentrect title:titlerect];
	}

	int count=[pages count];
	for(int i=0;i<count;i++)
	{
		XeeSLControl *control=[pages objectAtIndex:i];
		if((id)control==[NSNull null]) continue;

		[control setHidden:i!=page];
	}
}

-(void)setHidden:(BOOL)hidden
{
	[super setHidden:hidden];

	XeeSLControl *content=[pages objectAtIndex:[self value]];
	if((id)content!=[NSNull null]) [content setHidden:hidden];
}

-(void)pageChanged:(id)sender
{
	[parent requestLayout];
}

@end
