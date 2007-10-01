#import "XeeDirectorySource.h"
#import "XeeImage.h"
#import "XeeKQueue.h"
#import "CSDesktopServices.h"
#import "XeeStringAdditions.h"

#import <sys/stat.h>

@implementation XeeDirectorySource

-(id)initWithDirectory:(XeeFSRef *)directory
{
	if(self=[super init])
	{
		imgref=dirref=nil;

		[self startListUpdates];
		BOOL res=[self scanDirectory:directory];
		[self endListUpdates];

		if(res)
		{
			[self pickImageAtIndex:0];
			return self;
		}
	}
	[self release];
	return nil;
}

-(id)initWithRef:(XeeFSRef *)ref
{
	return [self initWithRef:ref image:nil];
}

-(id)initWithImage:(XeeImage *)image
{
	return [self initWithRef:[image ref] image:image];
}

-(id)initWithRef:(XeeFSRef *)ref image:(XeeImage *)image
{
	if(self=[super init])
	{
		imgref=dirref=nil;

		[self startListUpdates];
		XeeDirectoryEntry *curr=[XeeDirectoryEntry entryWithRef:ref image:image];
		[self setCurrentEntry:curr];
		BOOL res=[self scanDirectory:[ref parent]];
		[self endListUpdates];

		if(res) return self;
	}
	[self release];
	return nil;
}

-(void)dealloc
{
	[[XeeKQueue defaultKQueue] removeObserver:self ref:dirref];
	[[XeeKQueue defaultKQueue] removeObserver:self ref:imgref];
	[dirref release];
	[imgref release];

	[super dealloc];
}



-(int)capabilities
{
	return XeeNavigationCapable|XeeRenamingCapable|XeeCopyingCapable|
	XeeMovingCapable|XeeDeletionCapable|XeeSortingCapable;
}



-(BOOL)scanDirectory:(XeeFSRef *)ref
{
	dirref=[ref retain];
	if(!dirref) return NO;

	if(sortorder==XeeDefaultSortOrder)
	{
		NSDictionary *dsdict=CSParseDSStore([[[ref parent] path] stringByAppendingPathComponent:@".DS_Store"]);
		NSData *lsvo=[[dsdict objectForKey:[ref name]] objectForKey:@"lsvo"];
		if(lsvo&&[lsvo length]>=11)
		{
			switch(XeeBEUInt32((uint8 *)[lsvo bytes]+7))
			{
				case 'phys': sortorder=XeeSizeSortOrder; break;
				case 'modd': sortorder=XeeDateSortOrder; break; // !5JrU4QOlH6
			}
		}
	}

	[self readDirectory:dirref];

	[self setIcon:[[NSWorkspace sharedWorkspace] iconForFile:[ref path]]];
	[icon setSize:NSMakeSize(16,16)];

	[[XeeKQueue defaultKQueue] addObserver:self selector:@selector(directoryChanged:)
	ref:dirref flags:NOTE_WRITE|NOTE_DELETE|NOTE_RENAME];

	needsrefresh=NO;

	return YES;
}

-(void)readDirectory:(XeeFSRef *)ref
{
	//double starttime=XeeGetTime();

	NSDictionary *filetypes=[XeeImage fileTypeDictionary];
	NSMutableDictionary *oldentries=[NSMutableDictionary dictionary];

	NSEnumerator *enumerator=[entries objectEnumerator];
	XeeFileEntry *entry;
	while(entry=[enumerator nextObject]) [oldentries setObject:entry forKey:[entry ref]];

	if(![ref startReadingDirectoryWithRecursion:NO]) return;

	[self removeAllEntries];

	XeeFSRef *subref;
	while(subref=[ref nextDirectoryEntry])
	{
		NSString *ext=[[[subref name] pathExtension] lowercaseString];
		NSString *type=[subref HFSTypeCode];

		if([filetypes objectForKey:ext]||[filetypes objectForKey:type])
		{
			XeeDirectoryEntry *entry=[oldentries objectForKey:subref];
			if(!entry) entry=[XeeDirectoryEntry entryWithRef:subref];
			[self addEntry:entry];
		}
	}

	//double sorttime=XeeGetTime();

	[self runSorter];

	//double endtime=XeeGetTime();
	//NSLog(@"readDirectory: %g s read, %g s sort, %g s total",sorttime-starttime,endtime-sorttime,endtime-starttime);
}

-(void)setCurrentEntry:(XeeFileEntry *)entry
{
	[[XeeKQueue defaultKQueue] removeObserver:self ref:imgref];
	[imgref release];
	imgref=nil;

	[super setCurrentEntry:entry];

	if(entry)
	{
		imgref=[[entry ref] retain];
		written=NO;
		[[XeeKQueue defaultKQueue] addObserver:self selector:@selector(fileChanged:)
		ref:imgref flags:NOTE_WRITE|NOTE_DELETE|NOTE_RENAME|NOTE_ATTRIB];
	}
}



-(void)fileChanged:(XeeKEvent *)event
{
	int flags=[event flags];
	XeeFSRef *ref=[event ref];

	if(ref!=imgref) return; // probably doesn't happen

	if(flags&NOTE_WRITE)
	{
		written=YES;
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshImage) object:nil];
	}
	if(flags&NOTE_ATTRIB)
	{
		if(sortorder==XeeDateSortOrder) [self sortFiles];

		if(written&&!(flags&NOTE_WRITE))
		{
			written=NO;
			[self performSelector:@selector(refreshImage) withObject:nil afterDelay:0.2];
		}
	}
	if(flags&NOTE_RENAME)
	{
		if([ref isValid]&&[[ref parent] isEqual:dirref])
		{
			if(sortorder==XeeNameSortOrder) [self sortFiles];
			[[currentry image] triggerPropertyChangeAction];
		}
		else
		{
			[self startListUpdates];
			[self removeEntryMatchingObject:ref];
			[self endListUpdates];
		}
	}
	if(flags&NOTE_DELETE)
	{
		[self startListUpdates];
		[self removeEntryMatchingObject:ref];
		[self endListUpdates];
	}
}

-(void)refreshImage
{
	// pretty stupid
	int index=[self indexOfCurrentImage];
	[self setCurrentEntry:nil];
	[self pickImageAtIndex:index next:nextentry?[entries indexOfObject:nextentry]:-1];
	if(sortorder==XeeSizeSortOrder) [self sortFiles];
}

-(void)directoryChanged:(XeeKEvent *)event
{
	int flags=[event flags];
	XeeFSRef *ref=[event ref];

	if(flags&NOTE_WRITE)
	{
		[self setNeedsRefresh:YES];
	}
	if(flags&NOTE_RENAME)
	{
		if(![ref isValid])
		{
			[self startListUpdates];
			[self removeAllEntries];
			[self endListUpdates];
		}
		else [[currentry image] triggerPropertyChangeAction];
	}
	if(flags&NOTE_DELETE)
	{
		[self startListUpdates];
		[self removeAllEntries];
		[self endListUpdates];
	}
}



-(void)setNeedsRefresh:(BOOL)refresh
{
	if(needsrefresh==refresh) return;

	needsrefresh=refresh;

	if(needsrefresh) [self performSelector:@selector(refresh) withObject:nil afterDelay:0];
}

-(void)refresh
{
	if(!needsrefresh) return;

	[self startListUpdates];
	[self readDirectory:dirref];
	[self endListUpdates];

	needsrefresh=NO;
}

@end



@implementation XeeDirectoryEntry

+(XeeDirectoryEntry *)entryWithRef:(XeeFSRef *)ref { return [self entryWithRef:ref image:nil]; }

+(XeeDirectoryEntry *)entryWithRef:(XeeFSRef *)ref image:(XeeImage *)image
{
	return [[[XeeDirectoryEntry alloc] initWithRef:ref image:image] autorelease];
}

-(id)initWithRef:(XeeFSRef *)fsref
{
	return [self initWithRef:fsref image:nil];
}

-(id)initWithRef:(XeeFSRef *)fsref image:(XeeImage *)img
{
	if(self=[super init])
	{
		ref=[fsref retain];
		image=[img retain];
		//[self readAttributes];
	}
	return self;
}

-(id)initAsCopyOf:(XeeDirectoryEntry *)other
{
	if(self=[super initAsCopyOf:other])
	{
		ref=[other->ref retain];
		size=other->size;
		time=other->time;
	}
	return self;
}

-(void)dealloc
{
	[ref release];
	[super dealloc];
}

-(void)prepareForSortingBy:(int)sortorder
{
	switch(sortorder)
	{
		case XeeSizeSortOrder:
			size=[ref dataSize];
		break;

		case XeeDateSortOrder:
			size=(long)[ref modificationTime];
		break;

		default:
		{
			HFSUniStr255 name;
			FSGetCatalogInfo([ref FSRef],kFSCatInfoNone,NULL,&name,NULL,NULL);
			pathbuf=malloc(name.length*sizeof(UniChar));
			memcpy(pathbuf,name.unicode,name.length*sizeof(UniChar));
			pathlen=name.length;
		}
		break;
	}
}

-(NSString *)path { return [ref path]; }

-(XeeFSRef *)ref { return ref; }

-(off_t)size { return size; }

-(long)time { return time; }

-(NSString *)descriptiveName
{
	return [[ref name] stringByMappingColonToSlash];
}

-(BOOL)matchesObject:(id)obj { return [obj isKindOfClass:[XeeFSRef class]]&&[ref isEqual:obj]; }

-(BOOL)isEqual:(XeeDirectoryEntry *)other { return [ref isEqual:other->ref]; }

-(unsigned)hash { return [ref hash]; }

@end
