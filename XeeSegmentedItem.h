#import <Cocoa/Cocoa.h>

@interface XeeSegmentedItem:NSToolbarItem
{
	NSSegmentedControl *control;
	NSMenu *menu;
	SEL *actions;
}

-(id)initWithItemIdentifier:(NSString *)identifier label:(NSString *)label paletteLabel:(NSString *)pallabel segments:(int)segments;
-(void)dealloc;

-(void)setSegment:(int)segment label:(NSString *)label image:(NSImage *)image longLabel:(NSString *)longlabel width:(int)width action:(SEL)action;
-(void)setSegment:(int)segment label:(NSString *)label longLabel:(NSString *)longlabel action:(SEL)action;
-(void)setSegment:(int)segment imageName:(NSString *)imagename longLabel:(NSString *)longlabel action:(SEL)action;
-(void)setupView;

-(void)clicked:(id)sender;

+(XeeSegmentedItem *)itemWithIdentifier:(NSString *)identifier label:(NSString *)label paletteLabel:(NSString *)pallabel segments:(int)segments;

@end

