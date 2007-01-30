#import "XeeImageSource.h"
#import "XeeKQueue.h"

@class XeeFileEntry;

@interface XeeFileSource:XeeImageSource
{
	NSMutableArray *entries;
	NSRecursiveLock *listlock,*loadlock;
	NSArray *types;

	int currindex,nextindex,previndex;
	XeeImage *currimage,*nextimage,*previmage;
	XeeFileEntry *preventry,*currentry,*nextentry;

	BOOL loader_running,exiting;
	XeeImage *loadingimage;
}

-(id)init;
-(void)dealloc;

-(void)stop;

-(int)numberOfImages;
-(int)indexOfCurrentImage;
-(NSString *)representedFilename;
-(NSString *)descriptiveNameOfCurrentImage;
-(int)capabilities;

-(void)setSortOrder:(int)order;

-(void)pickImageAtIndex:(int)index next:(int)next;
-(void)pickImageAtIndex:(int)index;

-(void)addEntry:(XeeFileEntry *)entry sort:(BOOL)sort;
-(void)addEntries:(NSArray *)newentries sort:(BOOL)sort clear:(BOOL)clear;
-(void)removeEntry:(XeeFileEntry *)entry;
-(void)removeEntryAtIndex:(int)index;
-(void)removeEntryMatchingObject:(id)obj;
-(void)removeAllEntries;
-(void)sortFiles;
-(void)_runSorter;

-(void)lockList;
-(void)unlockListWithUpdates:(BOOL)updated;

-(XeeImage *)imageAtIndex:(int)index;
-(void)setCurrentImage:(XeeImage *)image index:(int)index;
-(void)setPreviousImage:(XeeImage *)image index:(int)index;
-(void)setNextImage:(XeeImage *)image index:(int)index;
-(void)launchLoader;
-(void)loader;

@end



@interface XeeFileEntry:NSObject
{
}

-(NSString *)path;
-(XeeFSRef *)ref;
-(off_t)size;
-(long)time;
-(NSString *)descriptiveName;

-(BOOL)matchesObject:(id)obj;

-(NSComparisonResult)comparePaths:(XeeFileEntry *)other;
-(NSComparisonResult)compareSizes:(XeeFileEntry *)other;
-(NSComparisonResult)compareTimes:(XeeFileEntry *)other;

@end
