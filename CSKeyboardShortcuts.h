#import <Cocoa/Cocoa.h>

#import "KFTypeSelectTableView.h"



#define CSCmd NSCommandKeyMask
#define CSAlt NSAlternateKeyMask
#define CSCtrl NSControlKeyMask
#define CSShift NSShiftKeyMask



@class CSKeyStroke,CSAction;



@interface CSKeyboardShortcuts:NSObject
{
	NSArray *actions;
}

+(NSArray *)parseMenu:(NSMenu *)menu;
+(NSArray *)parseMenu:(NSMenu *)menu namespace:(NSMutableSet *)namespace;

+(CSKeyboardShortcuts *)defaultShortcuts;
+(void)installWindowClass;

-(id)init;
-(void)dealloc;

-(NSArray *)actions;

-(void)addActions:(NSArray *)actions;
-(void)addActionsFromMenu:(NSMenu *)mainmenu;
-(void)addShortcuts:(NSDictionary *)shortcuts;

-(void)resetToDefaults;

-(BOOL)handleKeyEvent:(NSEvent *)event;
-(CSAction *)actionForEvent:(NSEvent *)event;
-(CSAction *)actionForEvent:(NSEvent *)event ignoringModifiers:(int)ignoredmods;
-(CSKeyStroke *)findKeyStrokeForEvent:(NSEvent *)event index:(int *)index;

@end



@interface CSAction:NSObject
{
	NSString *title,*identifier;
	SEL sel;
	id target;
	NSMenuItem *item;
	NSImage *fullimage;
	int spacing;

	NSMutableArray *shortcuts,*defshortcuts;
}

+(CSAction *)actionWithTitle:(NSString *)acttitle selector:(SEL)selector;
+(CSAction *)actionWithTitle:(NSString *)acttitle identifier:(NSString *)ident selector:(SEL)selector;
+(CSAction *)actionWithTitle:(NSString *)acttitle identifier:(NSString *)ident selector:(SEL)selector defaultShortcut:(CSKeyStroke *)defshortcut;
+(CSAction *)actionWithTitle:(NSString *)acttitle identifier:(NSString *)ident;
+(CSAction *)actionFromMenuItem:(NSMenuItem *)item namespace:(NSMutableSet *)namespace;

-(id)initWithTitle:(NSString *)acttitle identifier:(NSString *)ident selector:(SEL)selector target:(id)acttarget defaultShortcut:(CSKeyStroke *)defshortcut;
-(id)initWithMenuItem:(NSMenuItem *)menuitem namespace:(NSMutableSet *)namespace;
-(void)dealloc;

-(NSString *)title;
-(NSString *)identifier;
-(SEL)selector;
-(BOOL)isMenuItem;

-(void)setDefaultShortcuts:(NSArray *)shortcutarray;
-(void)addDefaultShortcut:(CSKeyStroke *)shortcut;
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
-(void)drawAtPoint:(NSPoint)point selected:(CSKeyStroke *)selected dropBefore:(CSKeyStroke *)dropbefore dropSize:(NSSize)dropsize;

-(CSKeyStroke *)findKeyAtPoint:(NSPoint)point offset:(NSPoint)offset;
-(NSPoint)findLocationOfKey:(CSKeyStroke *)searchkey offset:(NSPoint)offset;
-(CSKeyStroke *)findKeyAfterDropPoint:(NSPoint)point offset:(NSPoint)offset;

-(NSString *)description;
-(NSComparisonResult)compare:(CSAction *)other;

@end



@interface CSKeyStroke:NSObject
{
	NSString *chr;
	unsigned int mod;
	NSImage *img;
}

+(CSKeyStroke *)keyForCharacter:(NSString *)character modifiers:(unsigned int)modifiers;
+(CSKeyStroke *)keyForCharCode:(unichar)character modifiers:(unsigned int)modifiers;
+(CSKeyStroke *)keyFromMenuItem:(NSMenuItem *)item;
+(CSKeyStroke *)keyFromEvent:(NSEvent *)event;
+(CSKeyStroke *)keyFromDictionary:(NSDictionary *)dict;

+(NSArray *)keysFromDictionaries:(NSArray *)dicts;
+(NSArray *)dictionariesFromKeys:(NSArray *)keys;

-(id)initWithCharacter:(NSString *)character modifiers:(unsigned int)modifiers;
-(void)dealloc;

-(NSString *)character;
-(unsigned int)modifiers;
-(NSDictionary *)dictionary;

-(NSImage *)image;

-(BOOL)matchesEvent:(NSEvent *)event ignoringModifiers:(int)ignoredmods;

-(NSString *)description;
-(NSString *)descriptionOfModifiers;
-(NSString *)descriptionOfCharacter;

@end





@interface CSKeyboardList:KFTypeSelectTableView
{
	CSKeyStroke *selected;
	CSAction *dropaction;
	CSKeyStroke *dropbefore;
	NSSize dropsize;

	IBOutlet CSKeyboardShortcuts *keyboardShortcuts;
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
-(CSAction *)getActionForLocation:(NSPoint)point hasFrame:(NSRect *)frame;

-(void)updateButtons;

-(void)setKeyboardShortcuts:(CSKeyboardShortcuts *)shortcuts;
-(CSKeyboardShortcuts *)keybardShortcuts;

-(CSAction *)getSelectedAction;

-(IBAction)addShortcut:(id)sender;
-(IBAction)removeShortcut:(id)sender;
-(IBAction)resetToDefaults:(id)sender;
-(IBAction)resetAll:(id)sender;

@end







@interface CSKeyListenerWindow:NSWindow
{
}

+(void)install;

-(BOOL)performKeyEquivalent:(NSEvent *)event;

@end



@interface NSEvent (CSKeyboardShortcutsAdditions)

+(NSString *)remapCharacters:(NSString *)characters;

-(NSString *)charactersIgnoringAllModifiers;
-(NSString *)remappedCharacters;
-(NSString *)remappedCharactersIgnoringAllModifiers;

@end
