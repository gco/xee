#import <Cocoa/Cocoa.h>

@interface CSFileTypeList:NSTableView
{
}

-(id)initWithCoder:(NSCoder *)coder;
-(id)initWithFrame:(NSRect)frame;
-(void)dealloc;

-(IBAction)selectAll:(id)sender;
-(IBAction)deselectAll:(id)sender;

@end

/*
	Columns:
	enabled (checkbox)
	description (string)
	extensions (string)
	[type] (string)
*/

@interface CSFileTypeListSource:NSObject
{
	NSArray *filetypes;
}

-(id)init;
-(void)dealloc;
-(NSArray *)readFileTypes;

-(int)numberOfRowsInTableView:(NSTableView *)table;
-(id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(int)row;
-(void)tableView:(NSTableView *)table setObjectValue:(id)object forTableColumn:(NSTableColumn *)column row:(int)row;

-(void)claimAllTypes;
-(void)surrenderAllTypes;
-(void)claimType:(NSString *)type;
-(void)surrenderType:(NSString *)type;
-(void)setHandler:(NSString *)handler forType:(NSString *)type;
-(void)removeHandlerForType:(NSString *)type;

@end
