#import "CSFileTypeList.h"



@implementation CSFileTypeList

-(id)initWithCoder:(NSCoder *)coder
{
	if(self=[super initWithCoder:coder])
	{
		[self setDataSource:[[CSFileTypeListSource alloc] init]];
	}
	return self;
}

-(id)initWithFrame:(NSRect)frame
{
	if(self=[super initWithFrame:frame])
	{
		NSLog(@"Custom view mode in IB not supported yet");
		[self setDataSource:[[CSFileTypeListSource alloc] init]];
	}
	return self;
}

-(void)dealloc
{
	[[self dataSource] release];
	[super dealloc];
}

-(IBAction)selectAll:(id)sender
{
	[(CSFileTypeListSource *)[self dataSource] claimAllTypes];
	[self reloadData];
}

-(IBAction)deselectAll:(id)sender
{
	[(CSFileTypeListSource *)[self dataSource] surrenderAllTypes];
	[self reloadData];
}

@end



@implementation CSFileTypeListSource:NSObject

-(id)init
{
	if(self=[super init])
	{
		filetypes=[[self readFileTypes] retain];
	}
	return self;
}

-(void)dealloc
{
	[filetypes release];
	[super dealloc];
}

-(NSArray *)readFileTypes
{
	NSMutableArray *array=[NSMutableArray array];
	NSArray *types=[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDocumentTypes"];
	NSArray *hidden=[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CSHiddenDocumentTypes"];
	NSEnumerator *enumerator=[types objectEnumerator];
	NSDictionary *dict;

	while(dict=[enumerator nextObject])
	{
		NSArray *types=[dict objectForKey:@"LSItemContentTypes"];
		if(types)
		{
			NSString *description=[dict objectForKey:@"CFBundleTypeName"];
			NSString *extensions=[[dict objectForKey:@"CFBundleTypeExtensions"] componentsJoinedByString:@", "];
			NSString *type=[types objectAtIndex:0];

			if(!hidden||![hidden containsObject:type])
			[array addObject:[NSDictionary dictionaryWithObjectsAndKeys:
				type,@"type",
				description,@"description",
				extensions,@"extensions",
			nil]];
		}
	}

	return [NSArray arrayWithArray:array];
}

-(int)numberOfRowsInTableView:(NSTableView *)table
{
	return [filetypes count];
}

-(id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(int)row
{
	NSString *ident=[column identifier];

	if([ident isEqual:@"enabled"])
	{
		NSString *self_id=[[NSBundle mainBundle] bundleIdentifier];
		NSString *type=[[filetypes objectAtIndex:row] objectForKey:@"type"];
		NSString *handler=[(id)LSCopyDefaultRoleHandlerForContentType((CFStringRef)type,kLSRolesViewer) autorelease];
		return [NSNumber numberWithBool:[self_id isEqual:handler]];
	}
	else
	{
		return [[filetypes objectAtIndex:row] objectForKey:ident];
	}
}

-(void)tableView:(NSTableView *)table setObjectValue:(id)object forTableColumn:(NSTableColumn *)column row:(int)row
{
	NSString *ident=[column identifier];

	if([ident isEqual:@"enabled"])
	{
		NSString *type=[[filetypes objectAtIndex:row] objectForKey:@"type"];

		if([object boolValue]) [self claimType:type];
		else [self surrenderType:type];
	}
}

-(void)claimAllTypes
{
	NSEnumerator *enumerator=[filetypes objectEnumerator];
	NSDictionary *type;
	while(type=[enumerator nextObject]) [self claimType:[type objectForKey:@"type"]];
}

-(void)surrenderAllTypes
{
	NSEnumerator *enumerator=[filetypes objectEnumerator];
	NSDictionary *type;
	while(type=[enumerator nextObject]) [self surrenderType:[type objectForKey:@"type"]];
}

-(void)claimType:(NSString *)type
{
	NSString *self_id=[[NSBundle mainBundle] bundleIdentifier];
	NSString *oldhandler=[(id)LSCopyDefaultRoleHandlerForContentType((CFStringRef)type,kLSRolesViewer) autorelease];

	if(oldhandler&&![oldhandler isEqual:self_id]) [[NSUserDefaults standardUserDefaults] setObject:oldhandler
	forKey:[@"oldHandler." stringByAppendingString:type]];

	[self setHandler:self_id forType:type];
}

-(void)surrenderType:(NSString *)type
{
	NSString *self_id=[[NSBundle mainBundle] bundleIdentifier];
	NSString *oldhandler=[[NSUserDefaults standardUserDefaults] stringForKey:[@"oldHandler." stringByAppendingString:type]];

	if(oldhandler&&![oldhandler isEqual:self_id]) [self setHandler:oldhandler forType:type];
	else [self removeHandlerForType:type];
}

-(void)setHandler:(NSString *)handler forType:(NSString *)type
{
	LSSetDefaultRoleHandlerForContentType((CFStringRef)type,kLSRolesViewer,(CFStringRef)handler);
}

-(void)removeHandlerForType:(NSString *)type
{
	NSMutableArray *handlers=[NSMutableArray array];
	NSString *self_id=[[NSBundle mainBundle] bundleIdentifier];

	[handlers addObjectsFromArray:[(id)LSCopyAllRoleHandlersForContentType((CFStringRef)type,kLSRolesViewer) autorelease]];
	[handlers addObjectsFromArray:[(id)LSCopyAllRoleHandlersForContentType((CFStringRef)type,kLSRolesViewer) autorelease]];

	NSString *ext=[(id)UTTypeCopyPreferredTagWithClass((CFStringRef)type,kUTTagClassFilenameExtension) autorelease];
	NSString *filename=[NSString stringWithFormat:@"/tmp/CSFileTypeList%04x.%@",rand()&0xffff,ext];

	[[NSFileManager defaultManager] createFileAtPath:filename contents:nil attributes:nil];
	NSArray *apps=[(NSArray *)LSCopyApplicationURLsForURL((CFURLRef)[NSURL fileURLWithPath:filename],kLSRolesAll) autorelease];
	[[NSFileManager defaultManager] removeFileAtPath:filename handler:nil];

	NSEnumerator *enumerator=[apps objectEnumerator];
	NSURL *url;
	while(url=[enumerator nextObject])
	{
		NSString *identifier=[[NSBundle bundleWithPath:[url path]] bundleIdentifier];
		if(identifier) [handlers addObject:identifier];
	}

	for(;;)
	{
		int index=[handlers indexOfObject:self_id];
		if(index==NSNotFound) break;
		[handlers removeObjectAtIndex:index];
	}

	if([handlers count]) [self setHandler:[handlers objectAtIndex:0] forType:type];
	else [self setHandler:@"__dummy__" forType:type];
}

@end
