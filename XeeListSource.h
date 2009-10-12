#import "XeeImageSource.h"

@class XeeListEntry;

@interface XeeListSource:XeeImageSource
{
	NSMutableArray *entries;
	NSRecursiveLock *listlock,*loadlock;
	NSArray *types;

	XeeListEntry *currentry,*nextentry,*preventry;
	int changes,oldindex;

	BOOL loader_running,exiting;
	XeeImage *loadingimage;
}

-(id)init;
-(void)dealloc;

-(void)stop;

-(int)numberOfImages;
-(int)indexOfCurrentImage;
-(NSString *)descriptiveNameOfCurrentImage;

-(void)pickImageAtIndex:(int)index next:(int)next;
-(void)pickImageAtIndex:(int)index;

-(void)startListUpdates;
-(void)endListUpdates;

-(void)addEntry:(XeeListEntry *)entry;
-(void)addEntryUnlessExists:(XeeListEntry *)entry;
-(void)removeEntry:(XeeListEntry *)entry;
-(void)removeEntryMatchingObject:(id)obj;
-(void)removeAllEntries;

-(void)setCurrentEntry:(XeeListEntry *)entry;
-(void)setPreviousEntry:(XeeListEntry *)entry;
-(void)setNextEntry:(XeeListEntry *)entry;

-(void)launchLoader;
-(void)loader;

@end



@interface XeeListEntry:NSObject <NSCopying>
{
	XeeImage *savedimage;
	int imageretain;
}

-(id)init;
-(id)initAsCopyOf:(XeeListEntry *)other;
-(void)dealloc;

-(NSString *)descriptiveName;
-(BOOL)matchesObject:(id)obj;

-(void)retainImage;
-(void)releaseImage;
-(XeeImage *)image;
-(XeeImage *)produceImage;

-(BOOL)isEqual:(id)other;
-(unsigned long)hash;

-(id)copyWithZone:(NSZone *)zone;

@end
