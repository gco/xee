#import "XeeFileSource.h"
#import "XADArchive.h"

@interface XeeArchiveSource:XeeFileSource
{
	XADArchive *archive;
	NSString *tmpdir;
}

+(NSArray *)fileTypes;

-(id)initWithArchive:(NSString *)archivename;
-(void)dealloc;

-(NSString *)representedFilename;
-(int)capabilities;

-(XADArchive *)archiveForFile:(NSString *)archivename;

@end



@interface XeeArchiveEntry:XeeFileEntry
{
	XADArchive *archive;
	int n;
	XeeFSRef *ref;
	NSString *path;
	off_t size;
	long time;
}

-(id)initWithArchive:(XADArchive *)parentarchive entry:(int)num realPath:(NSString *)realpath;
-(void)dealloc;

-(NSString *)path;
-(XeeFSRef *)ref;
-(off_t)size;
-(long)time;
-(NSString *)descriptiveName;

-(BOOL)isEqual:(XeeArchiveEntry *)other;

@end
