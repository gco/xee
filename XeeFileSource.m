#import "XeeFileSource.h"
#import "XeeImage.h"



NSComparisonResult XeeFileSorter(id file1,id file2,XeeFileSource *source);



@implementation XeeFileSource

-(id)init
{
	if(self=[super init])
	{
		currindex=nextindex=previndex=-1;
		currimage=nextimage=previmage=nil;
		loadingimage=nil;

		entries=[[NSMutableArray array] retain];

		listlock=[[NSRecursiveLock alloc] init];
		loadlock=[[NSRecursiveLock alloc] init];
		loader_running=NO;
	}
	return self;
}

-(void)dealloc
{
	[entries release];
	[listlock release];
	[loadlock release];

	[currimage release];
	[nextimage release];
	[previmage release];

	[super dealloc];
}

-(void)stop
{
	exiting=YES;
	[loadingimage stopLoading];
}



-(int)numberOfImages
{
	return [entries count];
}

-(int)indexOfCurrentImage
{
	if(currindex<0) return NSNotFound;
	return currindex;
}

-(NSString *)representedFilename
{
	if(currindex<0) return nil;
	return [[entries objectAtIndex:currindex] path];
}

-(NSString *)descriptiveNameOfCurrentImage
{
	if(currindex<0) return nil;
	return [[entries objectAtIndex:currindex] descriptiveName];
}

-(int)capabilities { return XeeNavigationCapable; }



-(void)setSortOrder:(int)order
{
	[super setSortOrder:order];
	[self sortFiles];
}



-(void)pickImageAtIndex:(int)index next:(int)next
{
	[listlock lock];

	XeeImage *newcurrimage=nil,*newnextimage=nil;

	if(index<0 || index>=[entries count]) index=-1;
	else newcurrimage=[[self imageAtIndex:index] retain];

	if(next<0 || next>=[entries count]) next=-1;
	else newnextimage=[[self imageAtIndex:next] retain];

	[loadlock lock];

	if(index!=currindex) [self setPreviousImage:currimage index:currindex];
	[self setCurrentImage:newcurrimage index:index];
	[self setNextImage:newnextimage index:next];

	[newcurrimage release];
	[newnextimage release];

	[listlock unlock];

	if(loadingimage&&loadingimage!=currimage) [loadingimage stopLoading];

	[self launchLoader];

	[loadlock unlock];

	[self triggerImageChangeAction:currimage];
}

-(void)pickImageAtIndex:(int)index
{
	if(index==currindex&&nextindex>=0) [self pickImageAtIndex:index next:nextindex];
	else [super pickImageAtIndex:index];
}



-(void)addEntry:(XeeFileEntry *)entry sort:(BOOL)sort
{
	[self lockList];

	int index=[entries indexOfObject:entry];
	if(index!=NSNotFound) { [self unlockListWithUpdates:NO]; return; } // already added

	[entries addObject:entry];

	if(sort) [self _runSorter];

	[self unlockListWithUpdates:sort];

	[self triggerImageListChangeAction];
	if(currindex<0&&delegate) [self pickImageAtIndex:0 next:-1];
}

-(void)addEntries:(NSArray *)newentries sort:(BOOL)sort clear:(BOOL)clear
{
	[self lockList];

	if(clear)
	{
		[entries removeAllObjects];
		[entries addObjectsFromArray:newentries];
	}
	else
	{
		NSEnumerator *enumerator=[newentries objectEnumerator];
		XeeFileEntry *entry;
		while(entry=[enumerator nextObject]) [self addEntry:entry sort:NO];
	}

	if(sort) [self _runSorter];

	[self unlockListWithUpdates:sort||clear];

	[self triggerImageListChangeAction];
	if(currindex<0&&delegate) [self pickImageAtIndex:0 next:-1];
}

-(void)removeEntry:(XeeFileEntry *)entry
{
	[self lockList];

	int index=[entries indexOfObject:entry];
	if(index==NSNotFound) { [self unlockListWithUpdates:NO]; return; }

	[entries removeObjectAtIndex:index];

	[self unlockListWithUpdates:YES];

	[self triggerImageListChangeAction];
}

-(void)removeEntryAtIndex:(int)index
{
	[self lockList];
	[entries removeObjectAtIndex:index];
	[self unlockListWithUpdates:YES];

	[self triggerImageListChangeAction];
}

-(void)removeEntryMatchingObject:(id)obj
{
	[self lockList];

	int count=[entries count],index=NSNotFound;
	for(int i=0;i<count;i++) if([[entries objectAtIndex:i] matchesObject:obj]) { index=i; break; }

	if(index==NSNotFound) { [self unlockListWithUpdates:NO]; return; }

	[entries removeObjectAtIndex:index];

	[self unlockListWithUpdates:YES];

	[self triggerImageListChangeAction];
}

-(void)removeAllEntries
{
	[self lockList];
	[entries removeAllObjects];
	[self unlockListWithUpdates:YES];

	[self triggerImageListChangeAction];
	[self triggerImageChangeAction:nil];
}

-(void)sortFiles
{
	[self lockList];
	[self _runSorter];
	[self unlockListWithUpdates:YES];

	[self triggerImageListChangeAction]; // just to update the position display
}

-(void)_runSorter
{
	switch(sortorder)
	{
		case XeeDateSortOrder: [entries sortUsingSelector:@selector(compareTimes:)]; break;
		case XeeSizeSortOrder: [entries sortUsingSelector:@selector(compareSizes:)]; break;
		default: [entries sortUsingSelector:@selector(comparePaths:)]; break;
	}
}



-(void)lockList
{
	[listlock lock];

	preventry=currentry=nextentry=nil;
	if(previndex>=0) preventry=[[entries objectAtIndex:previndex] retain];
	if(currindex>=0) currentry=[[entries objectAtIndex:currindex] retain];
	if(nextindex>=0) nextentry=[[entries objectAtIndex:nextindex] retain];
}

-(void)unlockListWithUpdates:(BOOL)updated
{
	if(updated)
	{
		int oldindex=currindex;
		previndex=[entries indexOfObject:preventry];
		currindex=[entries indexOfObject:currentry];
		nextindex=[entries indexOfObject:nextentry];

		[loadlock lock];

		if(previndex==NSNotFound)
		{
			if(loadingimage==previmage) [loadingimage stopLoading];
			[self setPreviousImage:nil index:-1];
		}
		if(nextindex==NSNotFound)
		{
			if(loadingimage==nextimage) [loadingimage stopLoading];
			[self setNextImage:nil index:-1];
		}
		if(currindex==NSNotFound)
		{
			if(loadingimage==currimage) [loadingimage stopLoading];
			[self setCurrentImage:nil index:-1];

			int count=[entries count];
/*			if(count&&currfile)
			{
				int index;
				for(index=0;index<count;index++)
				if(XeeFileSorter(currfile,[entries objectAtIndex:index],self)!=NSOrderedAscending)
				break;
				if(index<count) [self pickImageAtIndex:index];
				else [self pickImageAtIndex:count-1];
			}
			else [self triggerImageChangeAction:nil];*/
			// this is pretty dumb, but it'll do for now
			if(oldindex>=count) [self pickImageAtIndex:count-1];
			else [self pickImageAtIndex:oldindex];
		}

		// should handle loading image
		[loadlock unlock];
	}

	[preventry release];
	[currentry release];
	[nextentry release];

	[listlock unlock];
}



-(XeeImage *)imageAtIndex:(int)index
{
	if(index<0) return nil;
	else if(index==currindex) return currimage;
	else if(index==nextindex) return nextimage;
	else if(index==previndex) return previmage;
	else
	{
		XeeFileEntry *entry=[entries objectAtIndex:index];
		return [XeeImage imageForRef:[entry ref]];
	}
}

-(void)setCurrentImage:(XeeImage *)image index:(int)index
{
	currindex=index;
	if(image==currimage) return;
	[currimage release];
	currimage=[image retain];
}

-(void)setPreviousImage:(XeeImage *)image index:(int)index
{
	previndex=index;
	if(image==previmage) return;
	[previmage release];
	previmage=[image retain];
}

-(void)setNextImage:(XeeImage *)image index:(int)index
{
	nextindex=index;
	if(image==nextimage) return;
	[nextimage release];
	nextimage=[image retain];
}



-(void)launchLoader
{
	if(!loader_running)
	{
		[NSThread detachNewThreadSelector:@selector(loader) toTarget:self withObject:nil];
		loader_running=YES;
	}
}

-(void)loader
{
	NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

	[self retain];

	[NSThread setThreadPriority:0.1];

	[loadlock lock];

	for(;;)
	{
		if(exiting) break;

		NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

		if(currimage&&[currimage needsLoading]) loadingimage=currimage;
		else if(nextimage&&[nextimage needsLoading]) loadingimage=nextimage;
		else break;

		[loadingimage retain];
		[loadlock unlock];

		//double starttime=XeeGetTime();
		[loadingimage runLoader];
		//double endtime=XeeGetTime();

		//NSLog(@"%@: %g s",[[loadingimage filename] lastPathComponent],endtime-starttime);

		[loadlock lock];
		[loadingimage release];

		[pool release];
	}

	loader_running=NO;
	loadingimage=nil;

	[loadlock unlock];

	[self release];

	[pool release];
}



@end



@implementation XeeFileEntry

-(NSString *)path { return nil; }

-(XeeFSRef *)ref { return nil; }

-(off_t)size { return 0; }

-(long)time { return 0; }

-(NSString *)descriptiveName { return nil; }

-(BOOL)matchesObject:(id)obj { return NO; }

-(NSComparisonResult)comparePaths:(XeeFileEntry *)other
{
	return [[self path] compare:[other path] options:NSCaseInsensitiveSearch|NSNumericSearch];
}

-(NSComparisonResult)compareSizes:(XeeFileEntry *)other
{
	off_t size1=[self size];
	off_t size2=[other size];

	if(size1==size2) return NSOrderedSame;
	else if(size1>size2) return NSOrderedAscending;
	else return NSOrderedDescending;
}

-(NSComparisonResult)compareTimes:(XeeFileEntry *)other
{
	long time1=[self time];
	long time2=[other time];

	if(time1==time2) return NSOrderedSame;
	else if(time1>time2) return NSOrderedAscending;
	else return NSOrderedDescending;
}

@end
