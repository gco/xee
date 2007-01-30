#import "XeeFileSource.h"
#import "XeeKQueue.h"

@interface XeeDirectorySource:XeeFileSource
{
	XeeFSRef *dirref,*imgref;
	int dirfd,filefd;
	BOOL needsrefresh,written;
}

-(id)initWithDirectory:(NSString *)directoryname;
-(id)initWithFilename:(NSString *)filename;
-(id)initWithImage:(XeeImage *)image;

-(int)capabilities;

-(void)_runSorter;

-(BOOL)scanDirectory:(NSString *)directoryname;
-(NSArray *)readDirectory:(XeeFSRef *)dirref;
-(NSString *)directory;

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
+(XeeDirectoryEntry *)entryWithFilename:(NSString *)filename;

-(id)initWithRef:(XeeFSRef *)fsref;
-(void)dealloc;

-(void)readAttributes;

-(NSString *)path;
-(XeeFSRef *)ref;
-(off_t)size;
-(long)time;
-(NSString *)descriptiveName;

-(BOOL)matchesObject:(id)obj;
-(BOOL)isEqual:(XeeDirectoryEntry *)other;

@end
