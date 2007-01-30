#import <Cocoa/Cocoa.h>



@interface XeeStatusBar:NSView
{
	NSMutableArray *cells;
	CGShadingRef shading;
}

-(id)initWithFrame:(NSRect)frame;
-(void)dealloc;

-(void)drawRect:(NSRect)rect;

-(void)addCell:(NSCell *)cell;
-(void)removeAllCells;

-(void)addEntry:(NSString *)title;
-(void)addEntry:(NSString *)title imageNamed:(NSString *)imagename;
-(void)addEntry:(NSString *)title image:(NSImage *)image;

@end



@interface XeeStatusCell:NSCell
{
	int spacing;
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
