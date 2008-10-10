#import "XeeListSource.h"
#import "XeeFSRef.h"

@class XeeFileEntry;

@interface XeeFileSource:XeeListSource
{
}

-(id)init;
-(void)dealloc;

-(NSString *)representedFilename;
-(int)capabilities;

-(void)setSortOrder:(int)order;

-(void)runSorter;
-(void)sortFiles;

@end

@interface XeeFileEntry:XeeListEntry
{
	UniChar *pathbuf;
	int pathlen;
}

-(id)init;
-(void)dealloc;

-(XeeImage *)produceImage;

-(NSString *)path;
-(XeeFSRef *)ref;
-(off_t)size;
-(long)time;

-(void)prepareForSortingBy:(int)sortorder;
-(void)finishSorting;
-(NSComparisonResult)comparePaths:(XeeFileEntry *)other;
-(NSComparisonResult)compareSizes:(XeeFileEntry *)other;
-(NSComparisonResult)compareTimes:(XeeFileEntry *)other;

@end
