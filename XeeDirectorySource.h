#import "XeeFileSource.h"
#import "XeeKQueue.h"

@class XeeDirectoryEntry;

@interface XeeDirectorySource:XeeFileSource
{
	XeeFSRef *dirref,*imgref;
	int dirfd,filefd;
	BOOL scheduledimagerename,scheduledimagerefresh,scheduleddirrefresh;
	XeeDirectoryEntry *first;
}

-(id)initWithDirectory:(XeeFSRef *)directory;
-(id)initWithRef:(XeeFSRef *)ref;
-(id)initWithImage:(XeeImage *)image;
-(id)initWithRef:(XeeFSRef *)ref image:(XeeImage *)image;
-(void)dealloc;

-(NSString *)windowTitle;
-(NSString *)windowRepresentedFilename;

-(BOOL)canBrowse;
-(BOOL)canSort;
-(BOOL)canRenameCurrentImage;
-(BOOL)canDeleteCurrentImage;
-(BOOL)canCopyCurrentImage;
-(BOOL)canMoveCurrentImage;
-(BOOL)canOpenCurrentImage;
-(BOOL)canSaveCurrentImage;

-(NSError *)renameCurrentImageTo:(NSString *)newname;
-(NSError *)deleteCurrentImage;
-(NSError *)moveCurrentImageTo:(NSString *)destination;
-(void)beginSavingImage:(XeeImage *)image;
-(void)endSavingImage:(XeeImage *)image;

-(void)setCurrentEntry:(XeeFileEntry *)entry;

-(void)fileChanged:(XeeKEvent *)event;
-(void)directoryChanged:(XeeKEvent *)event;

-(void)scheduleImageRename;
-(void)scheduleImageRefresh;
-(void)scheduleDirectoryRefresh;
-(void)performScheduledTasks;

-(void)removeCurrentEntryAndUpdate;
-(void)removeAllEntriesAndUpdate;

-(void)scanDirectory;
-(void)readDirectory;

@end



@interface XeeDirectoryEntry:XeeFileEntry
{
	XeeFSRef *ref;
	uint64_t size;
	double time;
}

+(XeeDirectoryEntry *)entryWithRef:(XeeFSRef *)ref;
+(XeeDirectoryEntry *)entryWithRef:(XeeFSRef *)ref image:(XeeImage *)image;

-(id)initWithRef:(XeeFSRef *)fsref;
-(id)initWithRef:(XeeFSRef *)fsref image:(XeeImage *)image;
-(id)initAsCopyOf:(XeeDirectoryEntry *)other;
-(void)dealloc;

-(void)prepareForSortingBy:(int)sortorder;

-(NSString *)descriptiveName;
-(XeeFSRef *)ref;
-(NSString *)path;
-(NSString *)filename;
-(uint64_t)size;
-(double)time;

-(BOOL)matchesObject:(id)obj;

-(BOOL)isEqual:(XeeDirectoryEntry *)other;
-(unsigned long)hash;

@end
