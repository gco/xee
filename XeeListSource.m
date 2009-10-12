#import "XeeListSource.h"
#import "XeeImage.h"

#define XeeAdditionChange 0x0001
#define XeeDeletionChange 0x0002
#define XeeSortingChange 0x0004

@implementation XeeListSource

-(id)init
{
	if(self=[super init])
	{
		currentry=nextentry=preventry=nil;
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

	[currentry release];
	[nextentry release];
	[preventry release];

	[super dealloc];
}

-(void)stop
{
	exiting=YES;
	[loadingimage stopLoading];
}



-(int)numberOfImages { return [entries count]; }

-(int)indexOfCurrentImage
{
	if(!currentry) return NSNotFound;
	return [entries indexOfObject:currentry];
}

-(NSString *)descriptiveNameOfCurrentImage { return [currentry descriptiveName]; }




-(void)pickImageAtIndex:(int)index next:(int)next
{
	[listlock lock];

	XeeListEntry *newcurrentry=nil,*newnextentry=nil;
	if(index>=0 && index<[entries count]) newcurrentry=[entries objectAtIndex:index];
	if(next>=0 && next<[entries count]) newnextentry=[entries objectAtIndex:next];

	[loadlock lock];

	[newcurrentry retainImage];
	[newnextentry retainImage];

	if(newcurrentry!=currentry) [self setPreviousEntry:currentry];
	[self setCurrentEntry:newcurrentry];
	[self setNextEntry:newnextentry];

	[newcurrentry releaseImage];
	[newnextentry releaseImage];

	XeeImage *currimage=[currentry image]; // grab image while holding loadlock to prevent race condition

	[listlock unlock];

	if(loadingimage&&loadingimage!=currimage) [loadingimage stopLoading];

	[self launchLoader];

	[loadlock unlock];

	[self triggerImageChangeAction:currimage];
}

-(void)pickImageAtIndex:(int)index
{
	// this is pretty dumb; FIX
	if(index<[entries count]&&[entries objectAtIndex:index]==currentry&&nextentry) [self pickImageAtIndex:index next:[entries indexOfObject:nextentry]];
	else [super pickImageAtIndex:index];
}


//double starttime;

-(void)startListUpdates
{
	//starttime=XeeGetTime();
	[listlock lock];
	changes=0;
	oldindex=[entries indexOfObjectIdenticalTo:currentry];
}

-(void)endListUpdates
{
	if(changes&XeeDeletionChange)
	{
		[loadlock lock];
		if(preventry&&![entries containsObject:preventry]) [self setPreviousEntry:nil];
		if(nextentry&&![entries containsObject:nextentry]) [self setNextEntry:nil];
		if(currentry&&![entries containsObject:currentry])
		{
			[self setCurrentEntry:nil];

			int count=[entries count];
			/*if(count&&currfile)
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
		[loadlock unlock];
	}

	[listlock unlock];

	if(changes&(XeeDeletionChange|XeeAdditionChange|XeeSortingChange))
	[self triggerImageListChangeAction];
	//double endtime=XeeGetTime();
	//NSLog(@"endListUpdates: total time %g s",endtime-starttime);

//	if(!currentry&&delegate) [self pickImageAtIndex:0 next:-1];
}

-(void)addEntry:(XeeListEntry *)entry
{
	[entries addObject:entry];
	changes|=XeeAdditionChange;
}

-(void)addEntryUnlessExists:(XeeListEntry *)entry
{
	if([entries containsObject:entry]) return;
	[entries addObject:entry];
	changes|=XeeAdditionChange;
}

-(void)removeEntry:(XeeListEntry *)entry
{
	[entries removeObject:entry];
	changes|=XeeDeletionChange;
}

-(void)removeEntryMatchingObject:(id)obj
{
	NSEnumerator *enumerator=[entries objectEnumerator];
	XeeListEntry *entry;
	while(entry=[enumerator nextObject]) if([entry matchesObject:obj]) break;
	if(!entry) return;

	[self removeEntry:entry];
}

-(void)removeAllEntries
{
	[entries removeAllObjects];
	changes|=XeeDeletionChange;
}



-(void)setCurrentEntry:(XeeListEntry *)entry
{
	[currentry releaseImage];
	[currentry autorelease];
	currentry=[entry retain];
	[currentry retainImage];
}

-(void)setPreviousEntry:(XeeListEntry *)entry
{
	[preventry releaseImage];
	[preventry autorelease];
	preventry=[entry retain];
	[preventry retainImage];
}

-(void)setNextEntry:(XeeListEntry *)entry
{
	[nextentry releaseImage];
	[nextentry autorelease];
	nextentry=[entry retain];
	[nextentry retainImage];
}



-(void)launchLoader
{
	if(!loader_running)
	{
		[self retain];
		[NSThread detachNewThreadSelector:@selector(loader) toTarget:self withObject:nil];
		loader_running=YES;
	}
}

-(void)loader
{
	NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

	[NSThread setThreadPriority:0.1];

	[loadlock lock];

	for(;;)
	{
		if(exiting) break;

		NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

		XeeImage *currimage=[currentry image];
		if(currimage&&[currimage needsLoading]) loadingimage=currimage;
		else
		{
			XeeImage *nextimage=[nextentry image];
			if(nextimage&&[nextimage needsLoading]) loadingimage=nextimage;
			else break;
		}

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



@implementation XeeListEntry

-(id)init
{
	if(self=[super init])
	{
		savedimage=nil;
		imageretain=0;
	}
	return self;
}

-(id)initAsCopyOf:(XeeListEntry *)other
{
	return [self init]; // FIX - what the hell?
}

-(void)dealloc
{
	[savedimage release];
	[super dealloc];
}



-(NSString *)descriptiveName { return nil; }

-(BOOL)matchesObject:(id)obj { return NO; }



-(void)retainImage
{
	imageretain++;
}

-(void)releaseImage
{
	imageretain--;
	if(imageretain==0)
	{
		[savedimage stopLoading];
		[savedimage release];
		savedimage=nil;
	}
	else if(imageretain<0) [NSException raise:@"XeeListEntryException" format:@"Too many releaseImage calls for file %@",self];
}

-(XeeImage *)image
{
	if(!imageretain) [NSException raise:@"XeeListEntryException" format:@"Attempted to access image without using retainImage for file %@",self];
	if(!savedimage) savedimage=[[self produceImage] retain];
	return savedimage;
}

-(XeeImage *)produceImage { return nil; }



-(BOOL)isEqual:(id)other { return NO; }

-(unsigned long)hash { return 0; }

-(NSString *)description
{
	NSString *desc=[self descriptiveName];
	if(!desc) return [super description];
	else return desc;
}

-(id)copyWithZone:(NSZone *)zone { return [[[self class] allocWithZone:zone] initAsCopyOf:self]; }

@end
