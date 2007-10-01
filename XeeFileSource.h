#import "XeeImageSource.h"
#import "XeeKQueue.h"

@class XeeFileEntry;

@interface XeeFileSource:XeeImageSource
{
	NSMutableArray *entries;
	NSRecursiveLock *listlock,*loadlock;
	NSArray *types;

	XeeFileEntry *currentry,*nextentry,*preventry;
	int changes,oldindex;

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

-(void)startListUpdates;
-(void)endListUpdates;

-(void)addEntry:(XeeFileEntry *)entry;
-(void)removeEntry:(XeeFileEntry *)entry;
-(void)removeEntryMatchingObject:(id)obj;
-(void)removeAllEntries;

-(void)runSorter;
-(void)sortFiles;

-(void)setCurrentEntry:(XeeFileEntry *)entry;
-(void)setPreviousEntry:(XeeFileEntry *)entry;
-(void)setNextEntry:(XeeFileEntry *)entry;

-(void)launchLoader;
-(void)loader;

@end



@interface XeeFileEntry:NSObject <NSCopying>
{
	XeeImage *image;
	int imageretain;
	UniChar *pathbuf;
	int pathlen;
}

-(id)init;
-(id)initAsCopyOf:(XeeFileEntry *)other;
-(void)dealloc;

-(NSString *)path;
-(XeeFSRef *)ref;
-(off_t)size;
-(long)time;
-(NSString *)descriptiveName;
-(BOOL)matchesObject:(id)obj;

-(void)retainImage;
-(void)releaseImage;
-(XeeImage *)image;

-(void)prepareForSortingBy:(int)sortorder;
-(void)finishSorting;
-(NSComparisonResult)comparePaths:(XeeFileEntry *)other;
-(NSComparisonResult)compareSizes:(XeeFileEntry *)other;
-(NSComparisonResult)compareTimes:(XeeFileEntry *)other;

-(BOOL)isEqual:(id)other;
-(unsigned)hash;

-(id)copyWithZone:(NSZone *)zone;

@end
