#import "XeeFileSource.h"
#import "XeeKQueue.h"

@interface XeeDirectorySource:XeeFileSource
{
	XeeFSRef *dirref,*imgref;
	int dirfd,filefd;
	BOOL needsrefresh,written;
}

-(id)initWithDirectory:(XeeFSRef *)directory;
-(id)initWithRef:(XeeFSRef *)ref;
-(id)initWithImage:(XeeImage *)image;
-(id)initWithRef:(XeeFSRef *)ref image:(XeeImage *)image;
-(void)dealloc;

-(int)capabilities;

-(BOOL)scanDirectory:(XeeFSRef *)ref;
-(void)readDirectory:(XeeFSRef *)ref;
-(void)setCurrentEntry:(XeeFileEntry *)entry;

-(void)fileChanged:(XeeKEvent *)event;
-(void)directoryChanged:(XeeKEvent *)event;
-(void)setNeedsRefresh:(BOOL)refresh;
-(void)refresh;

@end



@interface XeeDirectoryEntry:XeeFileEntry
{
	XeeFSRef *ref;
	off_t size;
	long time;
}

+(XeeDirectoryEntry *)entryWithRef:(XeeFSRef *)ref;
+(XeeDirectoryEntry *)entryWithRef:(XeeFSRef *)ref image:(XeeImage *)image;

-(id)initWithRef:(XeeFSRef *)fsref;
-(id)initWithRef:(XeeFSRef *)fsref image:(XeeImage *)image;
-(id)initAsCopyOf:(XeeDirectoryEntry *)other;
-(void)dealloc;

-(void)prepareForSortingBy:(int)sortorder;

-(NSString *)path;
-(XeeFSRef *)ref;
-(off_t)size;
-(long)time;
-(NSString *)descriptiveName;

-(BOOL)matchesObject:(id)obj;

-(BOOL)isEqual:(XeeDirectoryEntry *)other;
-(unsigned)hash;

@end
