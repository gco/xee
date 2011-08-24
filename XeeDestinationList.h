#import <Cocoa/Cocoa.h>

#import "KFTypeSelectTableView.h"

@class XeeDirectoryController;

@interface XeeDestinationView:KFTypeSelectTableView
{
	NSMutableArray *destinations;
	int droprow,dropnum;

	IBOutlet XeeDirectoryController *controller;
}

-(void)dealloc;
-(void)awakeFromNib;

-(id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(int)row;
-(int)numberOfRowsInTableView:(NSTableView *)table;

-(void)drawRow:(int)row clipRect:(NSRect)clipRect;
-(void)drawRoundedBar:(NSRect)rect;

-(void)keyDown:(NSEvent *)event;
-(void)menuForEvent:(NSEvent *)event;
-(void)mouseDown:(NSEvent *)event;

-(unsigned int)draggingSourceOperationMaskForLocal:(BOOL)local;
-(void)draggedImage:(NSImage *)image endedAt:(NSPoint)point operation:(NSDragOperation)operation;
-(NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
-(NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;
-(void)draggingExited:(id <NSDraggingInfo>)sender;
-(BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

-(int)rowForDropPoint:(NSPoint)point;
-(void)setDropRow:(int)row num:(int)num;
-(void)setDropRow:(int)row;

-(void)updateData:(id)notification;

-(IBAction)openInXee:(id)sender;
-(IBAction)openInFinder:(id)sender;
-(IBAction)removeFromList:(id)sender;

-(int)indexForRow:(int)row;
-(NSString *)pathForRow:(int)row;

+(void)updateTables;
+(void)suggestInsertion:(NSString *)directory;
+(void)addDestinations:(NSArray *)directories index:(int)index;
+(int)findDestination:(NSString *)directory;
+(void)loadArray;
+(void)saveArray;
+(NSMutableArray *)defaultArray;

@end
