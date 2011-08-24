#import <Cocoa/Cocoa.h>



@interface XeeStatusBar:NSView
{
	NSMutableArray *elements;
}

-(id)initWithFrame:(NSRect)frame;
-(void)dealloc;

-(void)drawRect:(NSRect)rect;

-(void)addCell:(NSCell *)cell priority:(float)priority;

-(void)setPriority:(float)priority atIndex:(int)index;
-(void)setPriority:(float)priority forCell:(NSCell *)cell;
-(void)setHidden:(BOOL)hidden atIndex:(int)index;
-(void)setHidden:(BOOL)hidden forCell:(NSCell *)cell;
-(void)setHiddenFrom:(int)start to:(int)end values:(BOOL)hidden,...;
-(int)indexOfCell:(NSCell *)cell;

@end



@interface XeeStatusCell:NSCell
{
	int spacing;
	NSDictionary *attributes;
	NSString *titlestring;
}

-(id)initWithImage:(NSImage *)image title:(NSString *)title;
-(void)dealloc;

-(void)setTitle:(NSString *)title;
-(NSString *)title;

-(NSSize)cellSize;
-(void)drawInteriorWithFrame:(NSRect)frame inView:(NSView *)view;

+(XeeStatusCell *)statusWithImageNamed:(NSString *)name title:(NSString *)title;

@end
