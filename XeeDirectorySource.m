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
		scheduledimagerename=scheduledimagerefresh=scheduleddirrefresh=NO;

		first=nil;
		dirref=[directory retain];

		if(dirref) return self;
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
		scheduledimagerename=scheduledimagerefresh=scheduleddirrefresh=NO;

		first=[[XeeDirectoryEntry entryWithRef:ref image:image] retain];
		dirref=[[ref parent] retain];

		if(dirref) return self;
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
	[first release];

	[super dealloc];
}



-(void)start
{
	[self startListUpdates];
	[self scanDirectory];
	if(first) [self addEntryUnlessExists:first];
	[self endListUpdates];

	if(first) [self pickImageAtIndex:[entries indexOfObject:first]];
	else [self pickImageAtIndex:0];

	[first release];
	first=nil;
}



-(NSString *)windowTitle { return [currentry descriptiveName]; }

-(NSString *)windowRepresentedFilename { return [(XeeFileEntry *)currentry path]; }



-(BOOL)canBrowse { return currentry!=nil; }
-(BOOL)canSort { return currentry!=nil; }
-(BOOL)canRenameCurrentImage { return currentry!=nil; }
-(BOOL)canDeleteCurrentImage { return currentry!=nil; }
-(BOOL)canCopyCurrentImage { return currentry!=nil; }
-(BOOL)canMoveCurrentImage { return currentry!=nil; }
-(BOOL)canOpenCurrentImage { return currentry!=nil; }

-(BOOL)canSaveCurrentImage
{
	// TODO: check if directory is writable
	//[dirref isWriteable]&&[imgref isWritable];
	return YES;
}



-(NSError *)renameCurrentImageTo:(NSString *)newname
{
	NSError *err=[super renameCurrentImageTo:newname];
	if(!err) [self scheduleImageRename];
	return err;
}

-(NSError *)deleteCurrentImage
{
	NSError *err=[super deleteCurrentImage];
	if(!err) [self removeCurrentEntryAndUpdate];
	return err;
}

-(NSError *)moveCurrentImageTo:(NSString *)destination
{
	NSError *err=[super moveCurrentImageTo:destination];
	if(!err) [self removeCurrentEntryAndUpdate];
	return err;
}

-(void)beginSavingImage:(XeeImage *)image
{
}

-(void)endSavingImage:(XeeImage *)image
{
	if([[image ref] isEqual:[(XeeDirectoryEntry *)currentry ref]]) [self scheduleImageRefresh];
}



-(void)setCurrentEntry:(XeeFileEntry *)entry
{
	[[XeeKQueue defaultKQueue] removeObserver:self ref:imgref];
	[imgref release];
	imgref=nil;

	// Cancel pending image updates if the image changed.
	if(entry!=currentry) scheduledimagerename=scheduledimagerefresh=NO;

	[super setCurrentEntry:entry];

	if(entry)
	{
		imgref=[[entry ref] retain];
		[[XeeKQueue defaultKQueue] addObserver:self selector:@selector(fileChanged:)
		ref:imgref flags:NOTE_WRITE|NOTE_DELETE|NOTE_RENAME|NOTE_ATTRIB];
	}
}



-(void)fileChanged:(XeeKEvent *)event
{
	int flags=[event flags];
	XeeFSRef *ref=[event ref];

	if(ref!=imgref) return; // Ignore spurious events after switching images

	if(flags&NOTE_WRITE) [self scheduleImageRefresh];

	if(flags&NOTE_ATTRIB)
	{
		if(sortorder==XeeDateSortOrder) [self sortFiles];
	}

	if(flags&NOTE_RENAME)
	{
		if([ref isValid]&&[[ref parent] isEqual:dirref]) [self scheduleImageRename];
		else [self removeCurrentEntryAndUpdate];
	}

	if(flags&NOTE_DELETE) [self removeCurrentEntryAndUpdate];
}

-(void)directoryChanged:(XeeKEvent *)event
{
	int flags=[event flags];
	XeeFSRef *ref=[event ref];

	if(flags&NOTE_WRITE) [self scheduleDirectoryRefresh];

	if(flags&NOTE_RENAME)
	{
		if(![ref isValid]) [self removeAllEntriesAndUpdate];
		else [[currentry image] triggerPropertyChangeAction];
	}

	if(flags&NOTE_DELETE) [self removeAllEntriesAndUpdate];
}



-(void)scheduleImageRename
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(performScheduledTasks) object:nil];
	[self performSelector:@selector(performScheduledTasks) withObject:nil afterDelay:0];
	scheduledimagerename=YES;
}

-(void)scheduleImageRefresh
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(performScheduledTasks) object:nil];
	[self performSelector:@selector(performScheduledTasks) withObject:nil afterDelay:0.2];
	scheduledimagerefresh=YES;
}

-(void)scheduleDirectoryRefresh
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(performScheduledTasks) object:nil];
	[self performSelector:@selector(performScheduledTasks) withObject:nil afterDelay:0.2];
	scheduleddirrefresh=YES;
}

-(void)performScheduledTasks
{
	if(scheduledimagerename)
	{
		[[currentry image] triggerPropertyChangeAction];
		if(sortorder==XeeNameSortOrder) [self sortFiles];
	}

	if(scheduledimagerefresh)
	{
		// pretty stupid
		int index=[self indexOfCurrentImage];
		[self setCurrentEntry:nil];
		[self pickImageAtIndex:index next:nextentry?[entries indexOfObject:nextentry]:-1];
		if(sortorder==XeeSizeSortOrder) [self sortFiles];
	}

	if(scheduleddirrefresh)
	{
		[self startListUpdates];
		[self readDirectory];
		[self endListUpdates];
	}

	scheduledimagerename=scheduledimagerefresh=scheduleddirrefresh=NO;
}



-(void)removeCurrentEntryAndUpdate
{
	[self startListUpdates];
	[self removeEntry:currentry];
	[self endListUpdates];
}

-(void)removeAllEntriesAndUpdate
{
	[self startListUpdates];
	[self removeAllEntries];
	[self endListUpdates];
}



-(void)scanDirectory
{
	if(sortorder==XeeDefaultSortOrder)
	{
		NSDictionary *dsdict=CSParseDSStore([[[dirref parent] path] stringByAppendingPathComponent:@".DS_Store"]);

		if(floor(NSAppKitVersionNumber)>949)
		{
			NSData *lsvp=[[dsdict objectForKey:[dirref name]] objectForKey:@"lsvp"];
			if(lsvp)
			{
				NSDictionary *properties=(NSDictionary *)[NSPropertyListSerialization
				propertyListFromData:lsvp mutabilityOption:NSPropertyListMutableContainersAndLeaves
				format:nil errorDescription:nil];
			
				NSString *sortcolumn=[properties objectForKey:@"sortColumn"];

				if([sortcolumn isEqualToString:@"dateModified"]) sortorder=XeeDateSortOrder;
				else if([sortcolumn isEqualToString:@"size"]) sortorder=XeeSizeSortOrder;
			}
		}
		else
		{
			NSData *lsvo=[[dsdict objectForKey:[dirref name]] objectForKey:@"lsvo"];
			if(lsvo&&[lsvo length]>=11)
			{
				switch(XeeBEUInt32((uint8_t *)[lsvo bytes]+7))
				{
					case 'phys': sortorder=XeeSizeSortOrder; break;
					case 'modd': sortorder=XeeDateSortOrder; break; // !5JrU4QOlH6
				}
			}
		}
	}

	[self readDirectory];

	[self setIcon:[[NSWorkspace sharedWorkspace] iconForFile:[dirref path]]];
	[icon setSize:NSMakeSize(16,16)];

	[[XeeKQueue defaultKQueue] addObserver:self selector:@selector(directoryChanged:)
	ref:dirref flags:NOTE_WRITE|NOTE_DELETE|NOTE_RENAME];
}

-(void)readDirectory
{
	//double starttime=XeeGetTime();

	NSDictionary *filetypes=[XeeImage fileTypeDictionary];
	NSMutableDictionary *oldentries=[NSMutableDictionary dictionary];

	NSEnumerator *enumerator=[entries objectEnumerator];
	XeeFileEntry *entry;
	while(entry=[enumerator nextObject]) [oldentries setObject:entry forKey:[entry ref]];

	if(![dirref startReadingDirectoryWithRecursion:NO]) return;

	[self removeAllEntries];

	XeeFSRef *subref;
	while(subref=[dirref nextDirectoryEntry])
	{
		NSString *name=[subref name];
		if([name hasPrefix:@"._"]) continue;

		NSString *ext=[[name pathExtension] lowercaseString];
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

-(id)initWithRef:(XeeFSRef *)fsref image:(XeeImage *)image
{
	if(self=[super init])
	{
		ref=[fsref retain];
		savedimage=[image retain];
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
			time=[ref modificationTime];
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

-(NSString *)descriptiveName
{
	return [[ref name] stringByMappingColonToSlash];
}

-(XeeFSRef *)ref { return ref; }

-(NSString *)path { return [ref path]; }

-(NSString *)filename
{
	return [ref name];
}

-(uint64_t)size { return size; }

-(double)time { return time; }


-(BOOL)matchesObject:(id)obj { return [obj isKindOfClass:[XeeFSRef class]]&&[ref isEqual:obj]; }

-(BOOL)isEqual:(XeeDirectoryEntry *)other { return [ref isEqual:other->ref]; }

-(unsigned long)hash { return [ref hash]; }

@end
