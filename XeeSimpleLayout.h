#import <Cocoa/Cocoa.h>



@class XeeSLControl,XeeSLGroup,XeeSLPopUp,XeeSLSwitch,XeeSLSlider,XeeSLPages;

@interface XeeSimpleLayout:NSView
{
	XeeSLControl *control;
	id delegate;
}

-(id)initWithControl:(XeeSLControl *)content;
-(void)dealloc;
-(BOOL)isFlipped;

-(void)layout;
-(void)requestLayout;

-(void)setDelegate:(id)delegate;
-(id)delegate;

@end


@interface XeeSLControl:NSObject
{
	NSTextField *titlefield;
	XeeSimpleLayout *parent;
	id delegate;
}

-(id)initWithTitle:(NSString *)title;
-(void)dealloc;

-(int)height;
-(int)topSpacing;
-(int)bottomSpacing;
-(int)contentWidth;
-(int)titleWidth;

-(void)addElementsToSuperview:(XeeSimpleLayout *)superview;
-(void)layoutContent:(NSRect)contentrect title:(NSRect)titlerect;
-(void)setHidden:(BOOL)hidden;

-(void)setDelegate:(id)delegate;
-(id)delegate;

@end



@interface XeeSLGroup:XeeSLControl
{
	NSArray *controls;
}

-(id)initWithControls:(NSArray *)controlarray;
-(void)dealloc;

-(int)height;
-(int)topSpacing;
-(int)bottomSpacing;
-(int)contentWidth;
-(int)titleWidth;

-(void)addElementsToSuperview:(XeeSimpleLayout *)superview;
-(void)layoutContent:(NSRect)contentrect title:(NSRect)titlerect;
-(void)setHidden:(BOOL)hidden;

+(XeeSLGroup *)groupWithControls:(XeeSLControl *)control,...;

@end



@interface XeeSLPopUp:XeeSLControl
{
	NSPopUpButton *popup;
	int maxwidth;
}

-(id)initWithTitle:(NSString *)title contents:(NSArray *)contents defaultValue:(int)def;
-(void)dealloc;

-(int)height;
-(int)topSpacing;
-(int)bottomSpacing;
-(int)contentWidth;

-(void)addElementsToSuperview:(XeeSimpleLayout *)superview;
-(void)layoutContent:(NSRect)contentrect title:(NSRect)titlerect;
-(void)setHidden:(BOOL)hidden;

-(int)value;

+(XeeSLPopUp *)popUpWithTitle:(NSString *)title defaultValue:(int)def contents:(NSString *)entry,...;

@end



@interface XeeSLSwitch:XeeSLControl
{
	NSButton *check;
}

-(id)initWithTitle:(NSString *)title label:(NSString *)label defaultValue:(BOOL)def;
-(void)dealloc;

-(int)height;
-(int)topSpacing;
-(int)bottomSpacing;
-(int)contentWidth;

-(void)addElementsToSuperview:(XeeSimpleLayout *)superview;
-(void)layoutContent:(NSRect)contentrect title:(NSRect)titlerect;
-(void)setHidden:(BOOL)hidden;

-(BOOL)value;

+(XeeSLSwitch *)switchWithTitle:(NSString *)title label:(NSString *)label defaultValue:(BOOL)def;

@end



@interface XeeSLSlider:XeeSLControl
{
	NSSlider *slider;
	NSTextField *minfield,*maxfield;
}

-(id)initWithTitle:(NSString *)title minLabel:(NSString *)minlabel maxLabel:(NSString *)maxlabel min:(float)minval max:(float)maxval defaultValue:(float)def;
-(void)dealloc;

-(int)height;
-(int)topSpacing;
-(int)bottomSpacing;
-(int)contentWidth;

-(void)addElementsToSuperview:(XeeSimpleLayout *)superview;
-(void)layoutContent:(NSRect)contentrect title:(NSRect)titlerect;
-(void)setHidden:(BOOL)hidden;

-(float)value;

+(XeeSLSlider *)sliderWithTitle:(NSString *)title minLabel:(NSString *)minlabel maxLabel:(NSString *)maxlabel min:(float)minval max:(float)maxval defaultValue:(float)def;

@end



@interface XeeSLPages:XeeSLPopUp
{
	NSArray *pages;
}

-(id)initWithTitle:(NSString *)title pages:(NSArray *)pagearray names:(NSArray *)namearray defaultValue:(int)def;
-(void)dealloc;

-(int)height;
-(int)bottomSpacing;
-(int)contentWidth;
-(int)titleWidth;

-(void)addElementsToSuperview:(XeeSimpleLayout *)superview;
-(void)layoutContent:(NSRect)contentrect title:(NSRect)titlerect;
-(void)setHidden:(BOOL)hidden;

//+(XeeSLPages *)pagesWithTitle:(NSString *)title pagesAndNames:(id)page,... defaultValue:(int)def;

@end
