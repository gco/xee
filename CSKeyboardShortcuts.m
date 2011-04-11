#import "CSKeyboardShortcuts.h"

#import <Carbon/Carbon.h>



// CSKeyboardShortcuts

static CSKeyboardShortcuts *defaultshortcuts=nil;

@implementation CSKeyboardShortcuts

+(NSArray *)parseMenu:(NSMenu *)menu
{
	return [self parseMenu:menu namespace:[NSMutableSet set]];
}

+(NSArray *)parseMenu:(NSMenu *)menu namespace:(NSMutableSet *)namespace
{
	NSMutableArray *array=[NSMutableArray array];

	int count=[menu numberOfItems];
	for(int i=0;i<count;i++)
	{
		NSMenuItem *item=[menu itemAtIndex:i];
		NSMenu *submenu=[item submenu];
		SEL sel=[item action];

		if(submenu) [array addObjectsFromArray:[self parseMenu:submenu namespace:namespace]];
		else if(sel) [array addObject:[CSAction actionFromMenuItem:item namespace:namespace]];
	}

	return array;
}

+(CSKeyboardShortcuts *)defaultShortcuts { return defaultshortcuts; }

+(void)installWindowClass { [CSKeyListenerWindow install]; }



-(id)init
{
	if(self=[super init])
	{
		actions=[[NSArray alloc] init];
		if(!defaultshortcuts) defaultshortcuts=self;
	}
	return self;
}

-(void)dealloc
{
	[actions release];

	[super dealloc];
}

-(NSArray *)actions { return actions; }

-(void)addActions:(NSArray *)moreactions
{
	[actions autorelease];
	actions=[[[actions arrayByAddingObjectsFromArray:moreactions] sortedArrayUsingSelector:@selector(compare:)] retain];
}

-(void)addActionsFromMenu:(NSMenu *)menu
{
	[self addActions:[CSKeyboardShortcuts parseMenu:menu]];
}

-(void)addShortcuts:(NSDictionary *)shortcuts
{
	NSEnumerator *enumerator=[actions objectEnumerator];
	CSAction *action;

	while(action=[enumerator nextObject])
	{
		NSArray *defkeys=[shortcuts objectForKey:[action identifier]];
		if(defkeys) [action addDefaultShortcuts:defkeys];
	}
}

-(void)resetToDefaults
{
	NSEnumerator *enumerator=[actions objectEnumerator];
	CSAction *action;

	while(action=[enumerator nextObject]) [action resetToDefaults];
}



-(BOOL)handleKeyEvent:(NSEvent *)event
{
	CSAction *action=[self actionForEvent:event ignoringModifiers:0];
	if(action&&[action perform:event]) return YES;
	return NO;
}

-(CSAction *)actionForEvent:(NSEvent *)event { return [self actionForEvent:event ignoringModifiers:0]; }

-(CSAction *)actionForEvent:(NSEvent *)event ignoringModifiers:(int)ignoredmods
{
	NSEnumerator *enumerator=[actions objectEnumerator];
	CSAction *action;
	while(action=[enumerator nextObject])
	{
		NSEnumerator *keyenumerator=[[action shortcuts] objectEnumerator];
		CSKeyStroke *key;
		while(key=[keyenumerator nextObject])
		{
			if([key matchesEvent:event ignoringModifiers:ignoredmods]) return action;
		}
	}
	return nil;
}

-(CSKeyStroke *)findKeyStrokeForEvent:(NSEvent *)event index:(int *)index
{
	for(int i=0;i<[actions count];i++)
	{
		CSAction *action=[actions objectAtIndex:i];

		NSEnumerator *keyenumerator=[[action shortcuts] objectEnumerator];
		CSKeyStroke *key;
		while(key=[keyenumerator nextObject])
		{
			if([key matchesEvent:event ignoringModifiers:0])
			{
				if(index) *index=i;
				return key;
			}
		}
	}
	return nil;
}

@end



// CSAction

@implementation CSAction

+(CSAction *)actionWithTitle:(NSString *)acttitle selector:(SEL)selector
{
	return [[[CSAction alloc] initWithTitle:acttitle identifier:nil selector:selector target:nil defaultShortcut:nil] autorelease];
}

+(CSAction *)actionWithTitle:(NSString *)acttitle identifier:(NSString *)ident selector:(SEL)selector
{
	return [[[CSAction alloc] initWithTitle:acttitle identifier:ident selector:selector target:nil defaultShortcut:nil] autorelease];
}

+(CSAction *)actionWithTitle:(NSString *)acttitle identifier:(NSString *)ident selector:(SEL)selector defaultShortcut:(CSKeyStroke *)defshortcut
{
	return [[[CSAction alloc] initWithTitle:acttitle identifier:ident selector:selector target:nil defaultShortcut:defshortcut] autorelease];
}

+(CSAction *)actionWithTitle:(NSString *)acttitle identifier:(NSString *)ident
{
	return [[[CSAction alloc] initWithTitle:acttitle identifier:ident selector:0 target:nil defaultShortcut:nil] autorelease];
}

+(CSAction *)actionFromMenuItem:(NSMenuItem *)item namespace:(NSMutableSet *)namespace
{
	return [[[CSAction alloc] initWithMenuItem:item namespace:namespace] autorelease];
}

-(id)initWithTitle:(NSString *)acttitle identifier:(NSString *)ident selector:(SEL)selector target:(id)acttarget defaultShortcut:(CSKeyStroke *)defshortcut
{
	if(self=[super init])
	{
		title=[acttitle retain];
		if(ident) identifier=[ident retain];
		else identifier=[NSStringFromSelector(selector) retain];
		sel=selector;
		target=[acttarget retain];

		shortcuts=nil;
		defshortcuts=[[NSMutableArray array] retain];

		item=nil;
		fullimage=nil;

		spacing=8;

		if(defshortcut) [defshortcuts addObject:defshortcut];

		[self loadCustomizations];
	}
	return self;
}

-(id)initWithMenuItem:(NSMenuItem *)menuitem namespace:(NSMutableSet *)namespace
{
	NSString *baseidentifier=NSStringFromSelector([menuitem action]);
	if([menuitem tag]) baseidentifier=[NSString stringWithFormat:@"%@%d",baseidentifier,[menuitem tag]];

	NSString *uniqueidentifier=baseidentifier;

	int counter=2;
	while([namespace containsObject:uniqueidentifier])
	{
		uniqueidentifier=[NSString stringWithFormat:@"%@(%d)",baseidentifier,counter];
		counter++;
	}

	[namespace addObject:uniqueidentifier];

	if(self=[self initWithTitle:[menuitem title] identifier:uniqueidentifier
	selector:[menuitem action] target:[menuitem target]
	defaultShortcut:[CSKeyStroke keyFromMenuItem:menuitem]])
	{
		item=[menuitem retain];
		[self updateMenuItem];
	}
	return self;
}

-(void)dealloc
{
	[title release];
	[identifier release];
	[target release];
	[shortcuts release];
	[defshortcuts release];
	[item release];
	[fullimage release];

	[super dealloc];
}

-(NSString *)title { return title; }

-(NSString *)identifier { return identifier; }

-(SEL)selector { return sel; }

-(BOOL)isMenuItem { return item?YES:NO; }



-(void)setDefaultShortcuts:(NSArray *)shortcutarray
{
	[defshortcuts removeAllObjects];
	[defshortcuts addObjectsFromArray:shortcutarray];
	[self updateMenuItem];
	[self clearImage];
}

-(void)addDefaultShortcut:(CSKeyStroke *)shortcut
{
	[defshortcuts addObject:shortcut];
	[self updateMenuItem];
	[self clearImage];
}

-(void)addDefaultShortcuts:(NSArray *)shortcutarray
{
	[defshortcuts addObjectsFromArray:shortcutarray];
	[self updateMenuItem];
	[self clearImage];
}



-(void)setShortcuts:(NSArray *)shortcutarray
{
	[shortcuts autorelease];

	NSString *key=[@"shortcuts." stringByAppendingString:identifier];
	if(!shortcutarray||[shortcutarray isEqual:defshortcuts])
	{
		shortcuts=nil;
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
	}
	else
	{
		shortcuts=[shortcutarray retain];
		NSArray *dictionaries=[CSKeyStroke dictionariesFromKeys:shortcuts];
		[[NSUserDefaults standardUserDefaults] setObject:dictionaries forKey:key];
	}
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:identifier]; // also remove old-style

	[self updateMenuItem];
	[self clearImage];
}

-(NSArray *)shortcuts { return shortcuts?shortcuts:defshortcuts; }



-(void)resetToDefaults
{
	[self setShortcuts:nil];
}

-(void)loadCustomizations
{
	NSArray *dictionaries=[[NSUserDefaults standardUserDefaults] arrayForKey:[@"shortcuts." stringByAppendingString:identifier]];
	if(!dictionaries) dictionaries=[[NSUserDefaults standardUserDefaults] arrayForKey:identifier];

	if(dictionaries)
	{
		[shortcuts autorelease];
		shortcuts=[[CSKeyStroke keysFromDictionaries:dictionaries] retain];
		[self updateMenuItem];
		[self clearImage];
	}
}

-(void)updateMenuItem
{
	if(!item) return;

	NSArray *currshortcuts=[self shortcuts];

	if([currshortcuts count])
	{
		CSKeyStroke *key=[currshortcuts objectAtIndex:0];
		[item setKeyEquivalent:[key character]];
		[item setKeyEquivalentModifierMask:[key modifiers]];
	}
	else
	{
		[item setKeyEquivalent:@""];
		[item setKeyEquivalentModifierMask:0];
	}
}

-(BOOL)perform:(NSEvent *)event
{
	if(!sel) return NO;

	if(item)
	{
		[[item menu] update];
		if([item isEnabled])
		{
			NSString *keyequivalent=[[item keyEquivalent] retain];
			unsigned int modifiermask=[item keyEquivalentModifierMask];

			[item setKeyEquivalent:@"\020"];
			[item setKeyEquivalentModifierMask:CSCmd|CSShift|CSAlt|CSCtrl];

			NSEvent *keyevent=[NSEvent keyEventWithType:NSKeyDown
			location:[event locationInWindow]
			modifierFlags:CSCmd|CSShift|CSAlt|CSCtrl
			timestamp:[event timestamp]
			windowNumber:[event windowNumber]
			context:[event context]
			characters:@"\020"
			charactersIgnoringModifiers:@"\020"
			isARepeat:[event isARepeat] 
			keyCode:0];

			BOOL res=[[item menu] performKeyEquivalent:keyevent];

			[item setKeyEquivalent:[keyequivalent autorelease]];
			[item setKeyEquivalentModifierMask:modifiermask];

			return res;
		}
		else
		{
			return YES; // avoid beeping
		}
	}
	else
	{
		return [[NSApplication sharedApplication] sendAction:sel to:target from:nil];
	}
}



-(NSImage *)shortcutsImage
{
	if(![[self shortcuts] count]) return nil;

	if(!fullimage)
	{
		fullimage=[[NSImage alloc] initWithSize:[self imageSizeWithDropSize:NSZeroSize]];
		[fullimage lockFocus];
		[self drawAtPoint:NSZeroPoint selected:nil dropBefore:nil dropSize:NSZeroSize];
		[fullimage unlockFocus];
	}
	return fullimage;
}

-(void)clearImage
{
	[fullimage release];
	fullimage=nil;
}

-(NSSize)imageSizeWithDropSize:(NSSize)dropsize
{
	NSEnumerator *enumerator=[[self shortcuts] objectEnumerator];
	CSKeyStroke *key;

	int width=0,height=0;

	while(key=[enumerator nextObject])
	{
		NSSize size=[[key image] size];
		width+=size.width+spacing;
		height=MAX(size.height,height);
	}
	width-=spacing;

	if(dropsize.width)
	{
		width+=dropsize.width+spacing;
		height=MAX(dropsize.height,height);
	}

	if(width<0) return NSZeroSize;
	else return NSMakeSize(width,height);
}

-(void)drawAtPoint:(NSPoint)point selected:(CSKeyStroke *)selected dropBefore:(CSKeyStroke *)dropbefore dropSize:(NSSize)dropsize
{
	NSEnumerator *enumerator=[[self shortcuts] objectEnumerator];
	CSKeyStroke *key;
	while(key=[enumerator nextObject])
	{
		NSSize size=[[key image] size];

		if(key==dropbefore)
		{
			[[NSColor colorWithCalibratedWhite:0 alpha:0.33] set];
			[NSBezierPath fillRect:NSMakeRect(point.x,point.y,dropsize.width,dropsize.height)];
			point.x+=dropsize.width+spacing;
 		}

		[[key image] compositeToPoint:point operation:NSCompositeSourceOver];

		if(key==selected)
		{
			[[NSColor colorWithCalibratedWhite:0 alpha:0.33] set];
			[NSBezierPath fillRect:NSMakeRect(point.x,point.y,size.width,size.height)];
		}

		point.x+=size.width+spacing;
	}

	if(!dropbefore&&dropsize.width) // drop at end
	{
		[[NSColor colorWithCalibratedWhite:0 alpha:0.33] set];
		[NSBezierPath fillRect:NSMakeRect(point.x,point.y,dropsize.width,dropsize.height)];
	}
}

-(CSKeyStroke *)findKeyAtPoint:(NSPoint)point offset:(NSPoint)offset
{
	NSPoint searchpoint=offset;
	NSEnumerator *enumerator=[[self shortcuts] objectEnumerator];
	CSKeyStroke *key;
	while(key=[enumerator nextObject])
	{
		NSSize size=[[key image] size];
		if(NSPointInRect(point,NSMakeRect(searchpoint.x,searchpoint.y,size.width,size.height))) return key;

		searchpoint.x+=size.width+spacing;
	}
	return nil;
}

-(NSPoint)findLocationOfKey:(CSKeyStroke *)searchkey offset:(NSPoint)offset
{
	NSPoint searchpoint=offset;
	NSEnumerator *enumerator=[[self shortcuts] objectEnumerator];
	CSKeyStroke *key;
	while(key=[enumerator nextObject])
	{
		NSSize size=[[key image] size];
		if(key==searchkey) return searchpoint;

		searchpoint.x+=size.width+spacing;
	}
	return NSMakePoint(0,0);
}

-(CSKeyStroke *)findKeyAfterDropPoint:(NSPoint)point offset:(NSPoint)offset
{
	NSPoint searchpoint=offset;
	NSEnumerator *enumerator=[[self shortcuts] objectEnumerator];
	CSKeyStroke *key;

	int prevdistance=point.x-searchpoint.x;
	if(prevdistance<0) prevdistance=-prevdistance;

	while(key=[enumerator nextObject])
	{
		NSSize size=[[key image] size];
		searchpoint.x+=size.width+spacing;

		int distance=point.x-searchpoint.x;
		if(distance<0) distance=-distance;
		if(distance>=prevdistance) return key;

		prevdistance=distance;
	}
	return nil;
}




-(NSString *)description { return identifier; }

-(NSComparisonResult)compare:(CSAction *)other
{
	return [title compare:[other title] options:NSNumericSearch|NSCaseInsensitiveSearch];
}

@end



// CSKeyStroke

@implementation CSKeyStroke

+(CSKeyStroke *)keyForCharacter:(NSString *)character modifiers:(unsigned int)modifiers
{
	return [[[CSKeyStroke alloc] initWithCharacter:character modifiers:modifiers] autorelease];
}

+(CSKeyStroke *)keyForCharCode:(unichar)character modifiers:(unsigned int)modifiers;
{
	return [CSKeyStroke keyForCharacter:[NSString stringWithFormat:@"%C",character] modifiers:modifiers];
}

+(CSKeyStroke *)keyFromMenuItem:(NSMenuItem *)item
{
	if([[item keyEquivalent] length]==0) return nil;
	return [CSKeyStroke keyForCharacter:[item keyEquivalent] modifiers:[item keyEquivalentModifierMask]];
}

+(CSKeyStroke *)keyFromEvent:(NSEvent *)event
{
	NSString *character=[event remappedCharactersIgnoringAllModifiers];
	unsigned int modifiers=[event modifierFlags];
	return [CSKeyStroke keyForCharacter:character modifiers:modifiers];
}

+(CSKeyStroke *)keyFromDictionary:(NSDictionary *)dict
{
	NSString *character=[dict objectForKey:@"character"];
	unsigned int modifiers=[[dict objectForKey:@"modifiers"] unsignedIntValue];
	return [CSKeyStroke keyForCharacter:character modifiers:modifiers];
}



+(NSArray *)keysFromDictionaries:(NSArray *)dicts
{
	NSMutableArray *keys=[NSMutableArray arrayWithCapacity:[dicts count]];
	NSEnumerator *enumerator=[dicts objectEnumerator];
	NSDictionary *dict;

	while(dict=[enumerator nextObject]) [keys addObject:[CSKeyStroke keyFromDictionary:dict]];

	return keys;
}

+(NSArray *)dictionariesFromKeys:(NSArray *)keys
{
	NSMutableArray *dicts=[NSMutableArray arrayWithCapacity:[keys count]];
	NSEnumerator *enumerator=[keys objectEnumerator];
	CSKeyStroke *key;

	while(key=[enumerator nextObject]) [dicts addObject:[key dictionary]];

	return dicts;
}

-(id)initWithCharacter:(NSString *)character modifiers:(unsigned int)modifiers
{
	if(self=[super init])
	{
		chr=[character retain];
		mod=modifiers&(NSCommandKeyMask|NSAlternateKeyMask|NSControlKeyMask|NSShiftKeyMask);

		img=nil;
	}
	return self;
}

-(void)dealloc
{
	[chr release];
	[img release];
	[super dealloc];
}

-(NSString *)character { return chr; }

-(unsigned int)modifiers { return mod; }

-(NSDictionary *)dictionary
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		chr,@"character",
		[NSNumber numberWithUnsignedInt:mod],@"modifiers",
	nil];
}



-(NSImage *)image
{
	if(!img)
	{
		NSString *text=[self description];
		NSImage *left=[NSImage imageNamed:@"button_left"];
		NSImage *mid=[NSImage imageNamed:@"button_mid"];
		NSImage *right=[NSImage imageNamed:@"button_right"];
		NSFont *font=[NSFont menuFontOfSize:13];
		NSDictionary *attrs=[NSDictionary dictionaryWithObjectsAndKeys:font,NSFontAttributeName,nil];

		NSSize textsize=[text sizeWithAttributes:attrs];
		int textwidth=textsize.width;
		int textheight=textsize.height;

		int imgwidth=textwidth+14+7;
		int imgheight=[left size].height;
		imgwidth-=imgwidth%8;

		NSSize imgsize=NSMakeSize(imgwidth,imgheight);
		NSPoint point=NSMakePoint((imgwidth-textwidth)/2,(imgheight-textheight)/2+1);

		img=[[NSImage alloc] initWithSize:imgsize];

		[img lockFocus];

		[left compositeToPoint:NSMakePoint(0,0) operation:NSCompositeSourceOver];
		[right compositeToPoint:NSMakePoint(imgsize.width-[right size].width,0) operation:NSCompositeSourceOver];

		int x=[left size].width;
		int totalwidth=imgsize.width-x-[right size].width;
		int midwidth=[mid size].width;

		while(totalwidth>=midwidth)
		{
			[mid compositeToPoint:NSMakePoint(x,0) operation:NSCompositeSourceOver];
			x+=midwidth;
			totalwidth-=midwidth;
		}

		if(totalwidth) [mid compositeToPoint:NSMakePoint(x,0) fromRect:NSMakeRect(0,0,totalwidth,[mid size].height) operation:NSCompositeSourceOver];

		[text drawAtPoint:point withAttributes:attrs];
		[img unlockFocus];
	}

	return img;
}



-(BOOL)matchesEvent:(NSEvent *)event ignoringModifiers:(int)ignoredmods
{
//	return [event _matchesKeyEquivalent:chr modifierMask:mod];

	unsigned int eventmod=[event modifierFlags]&(NSCommandKeyMask|NSAlternateKeyMask|NSControlKeyMask|NSShiftKeyMask)&~ignoredmods;
	unsigned int maskedmod=mod&~ignoredmods;
	NSString *eventchr=[event remappedCharacters];
	NSString *nomodchr=[event remappedCharactersIgnoringAllModifiers];

	if(![eventchr isEqual:nomodchr])
	if([chr isEqual:eventchr])
	if(((maskedmod^eventmod)&~((NSAlternateKeyMask|NSShiftKeyMask)&eventmod))==0)
	return YES;

	if([chr isEqual:nomodchr])
	if((maskedmod^eventmod)==0)
	return YES;

	return NO;
}



-(NSString *)description
{
	return [[self descriptionOfModifiers] stringByAppendingString:[self descriptionOfCharacter]];
}

-(NSString *)descriptionOfModifiers
{
	NSString *str=@"";

	if(mod&NSCommandKeyMask) str=[NSString stringWithFormat:@"%@%C",str,0x2318];
	if(mod&NSAlternateKeyMask) str=[NSString stringWithFormat:@"%@%C",str,0x2325];
	if(mod&NSControlKeyMask) str=[NSString stringWithFormat:@"%@%C",str,0x2303];
	if((mod&NSShiftKeyMask)||![[chr lowercaseString] isEqual:chr]) str=[NSString stringWithFormat:@"%@%C",str,0x21e7];

	return str;
}

-(NSString *)descriptionOfCharacter
{
	if(!chr||![chr length]) return @"(Empty)";
	switch([chr characterAtIndex:0])
	{
		case NSEnterCharacter: return [NSString stringWithFormat:@"%C",0x2305];
		case NSBackspaceCharacter: return [NSString stringWithFormat:@"%C",0x232b];
		case NSTabCharacter: return [NSString stringWithFormat:@"%C",0x21e5];
		case NSCarriageReturnCharacter: return [NSString stringWithFormat:@"%C",0x21a9];
		case NSBackTabCharacter: return [NSString stringWithFormat:@"%C",0x21e4];
		case 16: return @"DLE"; // Context menu key on PC keyboard, ASCII DLE.
		case 27: return [NSString stringWithFormat:@"%C",0x238b]; // esc
		case ' ': return @"Space";
		case NSDeleteCharacter: return [NSString stringWithFormat:@"%C",0x2326];
		case NSUpArrowFunctionKey: return [NSString stringWithFormat:@"%C",0x2191];
		case NSDownArrowFunctionKey: return [NSString stringWithFormat:@"%C",0x2193];
		case NSLeftArrowFunctionKey: return [NSString stringWithFormat:@"%C",0x2190];
		case NSRightArrowFunctionKey: return [NSString stringWithFormat:@"%C",0x2192];
		case NSF1FunctionKey: return @"F1";
		case NSF2FunctionKey: return @"F2";
		case NSF3FunctionKey: return @"F3";
		case NSF4FunctionKey: return @"F4";
		case NSF5FunctionKey: return @"F5";
		case NSF6FunctionKey: return @"F6";
		case NSF7FunctionKey: return @"F7";
		case NSF8FunctionKey: return @"F8";
		case NSF9FunctionKey: return @"F9";
		case NSF10FunctionKey: return @"F10";
		case NSF11FunctionKey: return @"F11";
		case NSF12FunctionKey: return @"F12";
		case NSF13FunctionKey: return @"F13";
		case NSF14FunctionKey: return @"F14";
		case NSF15FunctionKey: return @"F15";
		case NSInsertFunctionKey: return @"Insert";
		//case NSDeleteFunctionKey: return [NSString stringWithFormat:@"%C",0x2326];
		case NSDeleteFunctionKey: return @"(invalid)";
		case NSHomeFunctionKey: return [NSString stringWithFormat:@"%C",0x2196];
		case NSEndFunctionKey: return [NSString stringWithFormat:@"%C",0x2198];
		case NSPageUpFunctionKey: return [NSString stringWithFormat:@"%C",0x21de];
		case NSPageDownFunctionKey: return [NSString stringWithFormat:@"%C",0x21df];
		case NSClearLineFunctionKey: return [NSString stringWithFormat:@"%C",0x2327];
		case NSHelpFunctionKey: return [NSString stringWithFormat:@"?%C",0x20dd];
		default: return [chr uppercaseString];
//		default: return [NSString stringWithFormat:@"%d",[character characterAtIndex:0]];
	}
}

@end



// CSKeyboardList

@implementation CSKeyboardList

-(id)initWithCoder:(NSCoder *)decoder
{
	if(self=[super initWithCoder:decoder])
	{
		selected=nil;
		dropaction=nil;
		dropbefore=nil;
		dropsize=NSZeroSize;

		keyboardShortcuts=nil;
	}
	return self;
}

-(void)dealloc
{
	[keyboardShortcuts release];
	[super dealloc];
}

-(void)awakeFromNib
{
	NSImageCell *cell=[[self tableColumnWithIdentifier:@"shortcuts"] dataCell];
	[cell setImageAlignment:NSImageAlignLeft];
	[cell setImageScaling:NSScaleNone];
	[self setRowHeight:18];
	[self setMatchAlgorithm:KFPrefixMatchAlgorithm];
	[self setSearchColumnIdentifiers:[NSSet setWithObject:@"title"]];

	[self setDoubleAction:@selector(addShortcut:)];

	if(!keyboardShortcuts) keyboardShortcuts=[[CSKeyboardShortcuts defaultShortcuts] retain];

	[self registerForDraggedTypes:[NSArray arrayWithObjects:@"CSKeyStroke",nil]];

	[self setDelegate:self];
	[self setDataSource:self];
	[self reloadData];
	[self performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
	[self updateButtons];
}



-(id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(int)row
{
	if([[column identifier] isEqual:@"title"])
	{
		return [[[keyboardShortcuts actions] objectAtIndex:row] title];
	}
	else if([[column identifier] isEqual:@"shortcuts"])
	{
		CSAction *action=[[keyboardShortcuts actions] objectAtIndex:row];

		if(action==dropaction)
		{
			NSImage *image=[[[NSImage alloc] initWithSize:[action imageSizeWithDropSize:dropsize]] autorelease];
			[image lockFocus];
			[action drawAtPoint:NSZeroPoint selected:selected dropBefore:dropbefore dropSize:dropsize];
			[image unlockFocus];
			return image;
		}
		else if(row==[self selectedRow]&&selected)
		{
			if(![[action shortcuts] count]) return nil;
			NSImage *image=[[[NSImage alloc] initWithSize:[action imageSizeWithDropSize:NSZeroSize]] autorelease];
			[image lockFocus];
			[action drawAtPoint:NSZeroPoint selected:selected dropBefore:nil dropSize:NSZeroSize];
			[image unlockFocus];
			return image;
		}
		else return [action shortcutsImage];
	}

	return nil;
}

-(int)numberOfRowsInTableView:(NSTableView *)table
{
	return [[keyboardShortcuts actions] count];
}

-(void)tableViewSelectionDidChange:(NSNotification *)notification
{
	selected=nil;
	[self updateButtons];
}



-(BOOL)performKeyEquivalent:(NSEvent *)event
{
	NSString *chr=[event charactersIgnoringModifiers];
	if([chr length])

	switch([chr characterAtIndex:0])
	{
		case NSDeleteCharacter:
		case NSDeleteFunctionKey:
			if(selected)
			{
				[self removeShortcut:nil];
				return YES;
			}
		break;
	}
	return NO;
}

-(void)mouseDown:(NSEvent *)event
{
	NSPoint clickpoint=[self convertPoint:[event locationInWindow] fromView:nil];
	NSRect cellframe;
	CSAction *action=[self getActionForLocation:clickpoint hasFrame:&cellframe];

	if(action)
	{
		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:[self rowAtPoint:clickpoint]] byExtendingSelection:NO];

		CSKeyStroke *clicked=[action findKeyAtPoint:clickpoint offset:cellframe.origin];
//		[action setSelected:[self findKeyAtPoint:clickpoint]];
		selected=clicked;
		[self reloadData];
		[self updateButtons];

		if(clicked)
		{
			NSEvent *newevent=[[self window] nextEventMatchingMask:(NSLeftMouseDraggedMask|NSLeftMouseUpMask)
			untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES];

			if(newevent&&[newevent type]==NSLeftMouseDragged)
			{
				NSPasteboard *pboard=[NSPasteboard pasteboardWithName:NSDragPboard];
				[pboard declareTypes:[NSArray arrayWithObject:@"CSKeyStroke"] owner:self];
				[pboard setData:[NSArchiver archivedDataWithRootObject:[clicked dictionary]] forType:@"CSKeyStroke"];

				NSPoint newpoint=[self convertPoint:[newevent locationInWindow] fromView:nil];
				NSPoint imgpoint=[action findLocationOfKey:clicked offset:cellframe.origin];

				NSMutableArray *newshortcuts=[NSMutableArray arrayWithArray:[action shortcuts]];
				[newshortcuts removeObject:clicked];
				[action setShortcuts:newshortcuts];

				NSImage *keyimage=[clicked image];
				NSSize keysize=[keyimage size];
				NSImage *dragimage=[[[NSImage alloc] initWithSize:keysize] autorelease];

				[dragimage lockFocus];
				[keyimage drawAtPoint:NSMakePoint(0,0) fromRect:NSMakeRect(0,0,keysize.width,keysize.height)
				operation:NSCompositeSourceOver fraction:0.66];
				[dragimage unlockFocus];

				imgpoint.y+=keysize.height;

				selected=nil;
				[self updateButtons];

				[[NSCursor arrowCursor] push];

				[self dragImage:dragimage at:imgpoint
				offset:NSMakeSize(newpoint.x-clickpoint.x,newpoint.y-clickpoint.y)
				event:event pasteboard:pboard source:self slideBack:NO];

				[NSCursor pop];
			}
			return;
		}
	}

	[super mouseDown:event];
}

-(unsigned int)draggingSourceOperationMaskForLocal:(BOOL)local
{
	return NSDragOperationMove|NSDragOperationDelete;
}

-(void)draggedImage:(NSImage *)image endedAt:(NSPoint)point operation:(NSDragOperation)operation
{
	if(operation!=NSDragOperationMove) NSShowAnimationEffect(NSAnimationEffectDisappearingItemDefault,
	[[self window] convertBaseToScreen:[[self window] mouseLocationOutsideOfEventStream]],NSZeroSize,nil,nil,nil);
}

-(NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	return NSDragOperationMove;
}

-(NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
	NSRect cellframe;
	dropaction=[self getActionForLocation:[self convertPoint:[sender draggingLocation] fromView:nil] hasFrame:&cellframe];

	if(dropaction)
	{
		dropsize=[[sender draggedImage] size];
		dropbefore=[dropaction findKeyAfterDropPoint:[self convertPoint:[sender draggedImageLocation] fromView:nil] offset:cellframe.origin];

		[[NSCursor arrowCursor] set];
		[self reloadData];
		return NSDragOperationMove;
	}
	else
	{
		dropbefore=nil;
		dropsize=NSZeroSize;

		[[NSCursor disappearingItemCursor] set];
		[self reloadData];
		return NSDragOperationNone;
	}
}

-(void)draggingExited:(id <NSDraggingInfo>)sender
{
	dropaction=nil;
	dropbefore=nil;
	dropsize=NSZeroSize;

//	[[NSCursor disappearingItemCursor] set];
	SetThemeCursor(kThemePoofCursor);
	[self reloadData];
}

-(BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard=[sender draggingPasteboard];
	if(dropaction&&[[pboard types] containsObject:@"CSKeyStroke"])
	{
		CSKeyStroke *stroke=[CSKeyStroke keyFromDictionary:[NSUnarchiver unarchiveObjectWithData:[pboard dataForType:@"CSKeyStroke"]]];
		NSMutableArray *newshortcuts=[NSMutableArray arrayWithArray:[dropaction shortcuts]];

		if(dropbefore)
		{
			int index=[newshortcuts indexOfObjectIdenticalTo:dropbefore];
			[newshortcuts insertObject:stroke atIndex:index];
		}
		else [newshortcuts addObject:stroke];

		[dropaction setShortcuts:newshortcuts];
		selected=stroke;
	}

	dropaction=nil;
	dropbefore=nil;
	dropsize=NSZeroSize;

	[self reloadData];
	[self updateButtons];

    return YES;
}

-(CSAction *)getActionForLocation:(NSPoint)point hasFrame:(NSRect *)frame
{
	int rowindex=[self rowAtPoint:point];
	int colindex=[self columnAtPoint:point];

	if(colindex>=0&&rowindex>=0)
	{
		NSTableColumn *col=[[self tableColumns] objectAtIndex:colindex];

		if([[col identifier] isEqual:@"shortcuts"])
		{
			if(frame) *frame=[self frameOfCellAtColumn:colindex row:rowindex];
			return [[keyboardShortcuts actions] objectAtIndex:rowindex];
		}
	}
	return nil;
}



-(void)updateButtons
{
	BOOL rowsel=[self selectedRow]>=0?YES:NO;

	[addButton setEnabled:rowsel];
	[removeButton setEnabled:selected?YES:NO];
	[resetButton setEnabled:rowsel];
}



-(void)setKeyboardShortcuts:(CSKeyboardShortcuts *)shortcuts
{
	[keyboardShortcuts autorelease];
	keyboardShortcuts=[shortcuts retain];

	[self setDataSource:self];
	[self reloadData];
}

-(CSKeyboardShortcuts *)keybardShortcuts { return keyboardShortcuts; }

-(CSAction *)getSelectedAction
{
	return [[keyboardShortcuts actions] objectAtIndex:[self selectedRow]];
}

-(IBAction)addShortcut:(id)sender
{
	int rowindex=[self selectedRow];
	if(rowindex<0) return;

	CSAction *action=[[keyboardShortcuts actions] objectAtIndex:rowindex];

	[infoTextField setStringValue:NSLocalizedString(@"Press the keys you want as a shortcut for this action.",@"Text asking the user to press keys when assigning a new keyboard shortcut")];

	NSEvent *event=[[self window] nextEventMatchingMask:(NSKeyDownMask|NSLeftMouseDownMask)
	untilDate:[NSDate dateWithTimeIntervalSinceNow:10] inMode:NSEventTrackingRunLoopMode dequeue:YES];

	if(event&&[event type]==NSKeyDown)
	{
		int otherrow;
		CSKeyStroke *other=[keyboardShortcuts findKeyStrokeForEvent:event index:&otherrow];

		if(other)
		{
			[self selectRowIndexes:[NSIndexSet indexSetWithIndex:otherrow] byExtendingSelection:NO];
			[self scrollRowToVisible:otherrow];
			selected=other;
			[infoTextField setStringValue:NSLocalizedString(@"This shortcut is already in use.",@"Text explaining that an entered keyboard shortcut is already in use")];
		}
		else
		{
			CSKeyStroke *stroke=[CSKeyStroke keyFromEvent:event];

			[action setShortcuts:[[action shortcuts] arrayByAddingObject:stroke]];
			selected=stroke;
			[infoTextField setStringValue:@""];
		}

		[self reloadData];
		[self updateButtons];

		NSEvent *upevent=[[self window] nextEventMatchingMask:NSKeyUpMask
		untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES];
		[[self window] discardEventsMatchingMask:NSAnyEventMask beforeEvent:upevent];
	}
	else [infoTextField setStringValue:@""];
}

-(IBAction)removeShortcut:(id)sender
{
	if(!selected) return;
	int rowindex=[self selectedRow];
	if(rowindex<0) return;

	CSAction *action=[[keyboardShortcuts actions] objectAtIndex:rowindex];

	NSMutableArray *newshortcuts=[NSMutableArray arrayWithArray:[action shortcuts]];
	[newshortcuts removeObjectIdenticalTo:selected];
	[action setShortcuts:newshortcuts];

	selected=nil;

	[self reloadData];
	[self updateButtons];
}

-(IBAction)resetToDefaults:(id)sender
{
	int rowindex=[self selectedRow];
	if(rowindex<0) return;

	CSAction *action=[[keyboardShortcuts actions] objectAtIndex:rowindex];

	[action resetToDefaults];
	selected=nil;

	[self reloadData];
	[self updateButtons];
}

-(IBAction)resetAll:(id)sender
{
	[keyboardShortcuts resetToDefaults];

	selected=nil;

	[self reloadData];
	[self updateButtons];
}

@end



// CSKeyListenerWindow

@implementation CSKeyListenerWindow

+(void)install
{
	[self poseAsClass:[NSWindow class]];
}

-(BOOL)performKeyEquivalent:(NSEvent *)event
{
	if(![self isKindOfClass:[NSPanel class]])
	{
		if([event type]==NSKeyDown) // maybe I should just use keyDown?
		if([defaultshortcuts handleKeyEvent:event]) return YES;
	}

	return [super performKeyEquivalent:event];
}

@end



// NSEvent additions

@implementation NSEvent (CSKeyboardShortcutsAdditions)

+(NSString *)remapCharacters:(NSString *)characters
{
	static NSDictionary *remapdictionary=nil;
	if(!remapdictionary)
	{
		remapdictionary=[[NSDictionary dictionaryWithObjectsAndKeys:
			[NSString stringWithFormat:@"%C",NSBackspaceCharacter],
			[NSString stringWithFormat:@"%C",NSDeleteCharacter],

			[NSString stringWithFormat:@"%C",NSDeleteCharacter],
			[NSString stringWithFormat:@"%C",NSDeleteFunctionKey],
		nil] retain];
	}

	NSString *remapped=[remapdictionary objectForKey:characters];
	if(remapped) return remapped;
	else return characters;
}

-(NSString *)charactersIgnoringAllModifiers
{
	unsigned short keycode=[self keyCode];

	KeyboardLayoutRef layout;
	const void *uchr,*kchr;
	KLGetCurrentKeyboardLayout(&layout);
	KLGetKeyboardLayoutProperty(layout,kKLuchrData,&uchr);
	KLGetKeyboardLayoutProperty(layout,kKLKCHRData,&kchr);

	if(uchr)
	{
		UInt32 state=0;
		UniCharCount strlen;
		UniChar c;

		UCKeyTranslate(uchr,keycode,kUCKeyActionDown,0,LMGetKbdType(),0,&state,1,&strlen,&c);
		if(state!=0) UCKeyTranslate(uchr,keycode,kUCKeyActionDown,0,LMGetKbdType(),0,&state,1,&strlen,&c);

		if(strlen&&c>=32&&c!=127) // control chars are not reliable!
		return [NSString stringWithCharacters:&c length:strlen];
	}
	else if(kchr)
	{
		char c[2]={0,0};
		UInt32 state=0;
		c[0]=KeyTranslate(kchr,keycode,&state)&0xff;
		if(state!=0) c[0]=KeyTranslate(kchr,keycode,&state)&0xff;

		return [NSString stringWithCString:c encoding:NSMacOSRomanStringEncoding];
	}

	return [[self charactersIgnoringModifiers] lowercaseString];
}

-(NSString *)remappedCharacters { return [NSEvent remapCharacters:[self characters]]; }

-(NSString *)remappedCharactersIgnoringAllModifiers { return [NSEvent remapCharacters:[self charactersIgnoringAllModifiers]]; }


@end
