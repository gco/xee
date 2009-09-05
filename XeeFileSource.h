#import "XeeListSource.h"
#import "XeeFSRef.h"

@class XeeFileEntry;

@interface XeeFileSource:XeeListSource
{
}

-(id)init;
-(void)dealloc;

-(uint64_t)sizeOfCurrentImage;
-(NSDate *)dateOfCurrentImage;
-(BOOL)isCurrentImageRemote;
-(BOOL)isCurrentImageAtPath:(NSString *)path;

-(void)setSortOrder:(int)order;

-(void)runSorter;
-(void)sortFiles;

-(NSError *)renameCurrentImageTo:(NSString *)newname;
-(NSError *)deleteCurrentImage;
-(NSError *)copyCurrentImageTo:(NSString *)destination;
-(NSError *)moveCurrentImageTo:(NSString *)destination;
-(NSError *)openCurrentImageInApp:(NSString *)app;

-(void)playSound:(NSString *)filename;
-(void)actuallyPlaySound:(NSString *)filename;

@end

@interface XeeFileEntry:XeeListEntry
{
	UniChar *pathbuf;
	int pathlen;
}

-(id)init;
-(void)dealloc;

-(XeeImage *)produceImage;

-(XeeFSRef *)ref;
-(NSString *)path;
-(NSString *)filename;
-(uint64_t)size;
-(double)time;

-(void)prepareForSortingBy:(int)sortorder;
-(void)finishSorting;
-(NSComparisonResult)comparePaths:(XeeFileEntry *)other;
-(NSComparisonResult)compareSizes:(XeeFileEntry *)other;
-(NSComparisonResult)compareTimes:(XeeFileEntry *)other;

@end
