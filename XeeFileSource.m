#import "XeeFileSource.h"
#import "XeeImage.h"

#define XeeAdditionChange 0x0001
#define XeeDeletionChange 0x0002
#define XeeSortingChange 0x0004

@implementation XeeFileSource

-(id)init
{
	if(self=[super init])
	{
	}
	return self;
}

-(void)dealloc
{
	[super dealloc];
}

-(NSString *)representedFilename { return [(XeeFileEntry *)currentry path]; }

-(int)capabilities { return XeeNavigationCapable|XeeSortingCapable; }



-(void)setSortOrder:(int)order
{
	[super setSortOrder:order];
	[self sortFiles];
}

-(void)runSorter
{
	NSEnumerator *enumerator=[entries objectEnumerator];
	XeeFileEntry *entry;
	while(entry=[enumerator nextObject]) [entry prepareForSortingBy:sortorder];

	switch(sortorder)
	{
		case XeeDateSortOrder: [entries sortUsingSelector:@selector(compareTimes:)]; break;
		case XeeSizeSortOrder: [entries sortUsingSelector:@selector(compareSizes:)]; break;
		default: [entries sortUsingSelector:@selector(comparePaths:)]; break;
	}

	[entries makeObjectsPerformSelector:@selector(finishSorting)];

	changes|=XeeSortingChange;
}

-(void)sortFiles
{
	[self startListUpdates];
	[self runSorter];
	[self endListUpdates];
}

@end



@implementation XeeFileEntry

-(id)init
{
	if(self=[super init])
	{
		pathbuf=NULL;
	}
	return self;
}

-(void)dealloc
{
	free(pathbuf);
	[super dealloc];
}



-(XeeImage *)produceImage
{
	return [XeeImage imageForRef:[self ref]];
}



-(NSString *)path { return nil; }

-(XeeFSRef *)ref { return nil; }

-(off_t)size { return 0; }

-(long)time { return 0; }



-(void)prepareForSortingBy:(int)sortorder
{
	switch(sortorder)
	{
		case XeeDateSortOrder: break;
		case XeeSizeSortOrder: break;
		default:
		{
			NSString *path=[self path];
			pathlen=[path length];
			pathbuf=malloc(pathlen*sizeof(UniChar));
			[path getCharacters:pathbuf];
		}
	}
}

-(void)finishSorting
{
	free(pathbuf);
	pathbuf=NULL;
}

-(NSComparisonResult)comparePaths:(XeeFileEntry *)other
{
	SInt32 res;
	UCCompareTextDefault(kUCCollateComposeInsensitiveMask|kUCCollateWidthInsensitiveMask|
	kUCCollateCaseInsensitiveMask|kUCCollateDigitsOverrideMask|kUCCollateDigitsAsNumberMask|
	kUCCollatePunctuationSignificantMask,pathbuf,pathlen,other->pathbuf,other->pathlen,NULL,&res);
	return res;
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

-(NSString *)description { return [NSString stringWithFormat:@"%@",[self path]]; }

@end
