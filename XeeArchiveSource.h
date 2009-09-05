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

-(BOOL)canBrowse;
-(BOOL)canSort;
-(BOOL)canCopyCurrentImage;

-(XADArchive *)archiveForFile:(NSString *)archivename;

@end



@interface XeeArchiveEntry:XeeFileEntry
{
	XADArchive *archive;
	int n;
	XeeFSRef *ref;
	NSString *path;
	uint64_t size;
	double time;
}

-(id)initWithArchive:(XADArchive *)parentarchive entry:(int)num realPath:(NSString *)realpath;
-(id)initAsCopyOf:(XeeArchiveEntry *)other;
-(void)dealloc;

-(NSString *)descriptiveName;
-(XeeFSRef *)ref;
-(NSString *)path;
-(NSString *)filename;
-(uint64_t)size;
-(double)time;

-(BOOL)isEqual:(XeeArchiveEntry *)other;
-(unsigned)hash;

@end
