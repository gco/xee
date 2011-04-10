#import "XeeFileSource.h"

#define NSUInteger unsigned long
#import <XADMaster/XADArchive.h>


@interface XeeArchiveSource:XeeFileSource
{
	NSString *filename;
	XADArchiveParser *parser;
	NSString *tmpdir;
	int n;
}

+(NSArray *)fileTypes;

-(id)initWithArchive:(NSString *)archivename;
-(void)dealloc;

-(void)start;

-(NSString *)windowTitle;
-(NSString *)windowRepresentedFilename;

-(BOOL)canBrowse;
-(BOOL)canSort;
-(BOOL)canCopyCurrentImage;

@end



@interface XeeArchiveEntry:XeeFileEntry
{
	XADArchiveParser *parser;
	NSDictionary *dict;
	XeeFSRef *ref;
	NSString *path;
	uint64_t size;
	double time;
}

-(id)initWithArchiveParser:(XADArchiveParser *)parent entry:(NSDictionary *)entry realPath:(NSString *)realpath;
-(id)initAsCopyOf:(XeeArchiveEntry *)other;
-(void)dealloc;

-(NSString *)descriptiveName;
-(XeeFSRef *)ref;
-(NSString *)path;
-(NSString *)filename;
-(uint64_t)size;
-(double)time;

-(BOOL)isEqual:(XeeArchiveEntry *)other;
-(unsigned long)hash;

@end
