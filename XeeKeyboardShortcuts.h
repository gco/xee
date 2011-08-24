#import <Cocoa/Cocoa.h>

#import "KFTypeSelectTableView.h"



#define XeeCmd NSCommandKeyMask
#define XeeAlt NSAlternateKeyMask
#define XeeCtrl NSControlKeyMask
#define XeeShift NSShiftKeyMask



@class XeeKeyStroke,XeeAction;



@interface XeeKeyboardShortcuts:NSObject
{
	NSArray *actions;
}

-(id)init;
-(void)dealloc;

-(NSArray *)actions;

-(void)addActions:(NSArray *)actions;
-(void)addActionsFromMenu:(NSMenu *)mainmenu;
-(void)addShortcuts:(NSDictionary *)shortcuts;

-(void)resetToDefaults;

-(BOOL)handleKeyEvent:(NSEvent *)event;
-(XeeKeyStroke *)findKeyStrokeForEvent:(NSEvent *)event index:(int *)index;
-(void)installWindowClass;

+(NSArray *)parseMenu:(NSMenu *)menu;

@end



@interface XeeAction:NSObject
{
	NSString *title;
	SEL sel;
	id target;
	NSMenuItem *item;
	NSImage *fullimage;
	int spacing;

	NSMutableArray *shortcuts,*defshortcuts;
}

-(id)initWithTitle:(NSString *)acttitle selector:(SEL)selector target:(id)acttarget defaultShortcut:(XeeKeyStroke *)defshortcut;
-(id)initWithMenuItem:(NSMenuItem *)menuitem;
-(void)dealloc;

-(NSString *)title;
-(NSString *)selectorName;
-(BOOL)isMenuItem;

-(void)setDefaultShortcuts:(NSArray *)shortcutarray;
-(void)addDefaultShortcut:(XeeKeyStroke *)shortcut;
-(void)addDefaultShortcuts:(NSArray *)shortcutarray;

-(void)setShortcuts:(NSArray *)shortcutarray;
-(NSArray *)shortcuts;

-(void)resetToDefaults;
-(void)loadCustomizations;
-(void)updateMenuItem;

-(BOOL)perform:(NSEvent *)event;

-(NSImage *)shortcutsImage;
-(void)clearImage;

-(NSSize)imageSizeWithDropSize:(NSSize)dropsize;
-(void)drawAtPoint:(NSPoint)point selected:(XeeKeyStroke *)selected dropBefore:(XeeKeyStroke *)dropbefore dropSize:(NSSize)dropsize;

-(XeeKeyStroke *)findKeyAtPoint:(NSPoint)point offset:(NSPoint)offset;
-(NSPoint)findLocationOfKey:(XeeKeyStroke *)searchkey offset:(NSPoint)offset;
-(XeeKeyStroke *)findKeyAfterDropPoint:(NSPoint)point offset:(NSPoint)offset;

-(NSString *)description;
-(NSComparisonResult)compare:(XeeAction *)other;

+(XeeAction *)actionWithTitle:(NSString *)acttitle selector:(SEL)selector;
+(XeeAction *)actionWithTitle:(NSString *)acttitle selector:(SEL)selector defaultShortcut:(XeeKeyStroke *)defshortcut;
+(XeeAction *)actionFromMenuItem:(NSMenuItem *)item;

@end



@interface XeeKeyStroke:NSObject
{
	NSString *chr;
	unsigned int mod;
	NSImage *img;
}

-(id)initWithCharacter:(NSString *)character modifiers:(unsigned int)modifiers;
-(void)dealloc;

-(NSString *)character;
-(unsigned int)modifiers;
-(NSDictionary *)dictionary;
-(NSImage *)image;

-(BOOL)matchesEvent:(NSEvent *)event;
-(NSString *)charactersIgnoringAllModifiersForEvent:(NSEvent *)event;

-(NSString *)description;
-(NSString *)descriptionOfModifiers;
-(NSString *)descriptionOfCharacter;

+(XeeKeyStroke *)keyForCharacter:(NSString *)character modifiers:(unsigned int)modifiers;
+(XeeKeyStroke *)keyForCharCode:(unichar)character modifiers:(unsigned int)modifiers;
+(XeeKeyStroke *)keyFromMenuItem:(NSMenuItem *)item;
+(XeeKeyStroke *)keyFromDictionary:(NSDictionary *)dict;

+(NSArray *)keysFromDictionaries:(NSArray *)dicts;
+(NSArray *)dictionariesFromKeys:(NSArray *)keys;

@end





@interface XeeKeyboardList:KFTypeSelectTableView
{
	XeeKeyStroke *selected;
	XeeAction *dropaction;
	XeeKeyStroke *dropbefore;
	NSSize dropsize;

	IBOutlet XeeKeyboardShortcuts *keyboardShortcuts;
	IBOutlet NSTextField *infoTextField;
	IBOutlet NSControl *addButton;
	IBOutlet NSControl *removeButton;
	IBOutlet NSControl *resetButton;
}

-(id)initWithCoder:(NSCoder *)decoder;
-(void)dealloc;

-(void)awakeFromNib;

-(id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(int)row;
-(int)numberOfRowsInTableView:(NSTableView *)table;
-(void)tableViewSelectionDidChange:(NSNotification *)notification;

-(void)mouseDown:(NSEvent *)event;

-(unsigned int)draggingSourceOperationMaskForLocal:(BOOL)local;
-(void)draggedImage:(NSImage *)image endedAt:(NSPoint)point operation:(NSDragOperation)operation;
-(NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
-(NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;
-(void)draggingExited:(id <NSDraggingInfo>)sender;
-(BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
-(XeeAction *)getActionForLocation:(NSPoint)point hasFrame:(NSRect *)frame;

-(void)updateButtons;

-(void)setKeyboardShortcuts:(XeeKeyboardShortcuts *)shortcuts;
-(XeeKeyboardShortcuts *)keybardShortcuts;

-(XeeAction *)getSelectedAction;

-(IBAction)addShortcut:(id)sender;
-(IBAction)removeShortcut:(id)sender;
-(IBAction)resetToDefaults:(id)sender;
-(IBAction)resetAll:(id)sender;

@end







@interface XeeKeyListenerWindow:NSWindow
{
}

-(BOOL)performKeyEquivalent:(NSEvent *)event;
+(void)installForShortcuts:(XeeKeyboardShortcuts *)shortcuts;

@end
