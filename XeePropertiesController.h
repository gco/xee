#import <Cocoa/Cocoa.h>


@class XeePropertyItem,XeeController;

@interface XeePropertiesController:NSObject
{
	IBOutlet NSPanel *infopanel;
	IBOutlet NSOutlineView *outlineview;
	NSArray *dataarray;

	NSDictionary *sectionattributes,*labelattributes;
}

-(void)awakeFromNib;

-(void)toggleVisibility;
-(BOOL)closeIfOpen;
-(void)setFullscreenMode:(BOOL)fullscreen;

-(void)frontImageDidChange:(NSNotification *)notification;
-(IBAction)doubleClick:(id)sender;

-(BOOL)outlineView:(NSOutlineView *)view isItemExpandable:(XeePropertyItem *)item;
-(int)outlineView:(NSOutlineView *)view numberOfChildrenOfItem:(XeePropertyItem *)item;
-(id)outlineView:(NSOutlineView *)view child:(int)index ofItem:(XeePropertyItem *)item;
-(id)outlineView:(NSOutlineView *)view objectValueForTableColumn:(NSTableColumn *)col byItem:(XeePropertyItem *)item;

-(BOOL)outlineView:(NSOutlineView *)view shouldEditTableColumn:(NSTableColumn *)col item:(XeePropertyItem *)item;

-(void)restoreCollapsedStatusForArray:(NSArray *)array;

@end


@interface XeePropertyOutlineView:NSOutlineView
{
	NSColor *top_normal,*bottom_normal;
	NSDictionary *attrs_normal;
	NSColor *top_selected,*bottom_selected;
	NSDictionary *attrs_selected;
}

-(void)drawRow:(int)row clipRect:(NSRect)clip;
-(NSRect)frameOfCellAtColumn:(int)column row:(int)row;

-(IBAction)copy:(id)sender;

@end
