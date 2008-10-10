#import "XeeFileSource.h"
#import "SWFParser.h"
#import "CSMemoryHandle.h"

@interface XeeSWFSource:XeeFileSource
{
	NSString *filename;
}

+(NSArray *)fileTypes;

-(id)initWithFile:(NSString *)swfname;
-(void)dealloc;

-(void)loadWithParser:(SWFParser *)parser;

-(NSString *)representedFilename;
-(int)capabilities;

@end



@interface XeeSWFEntry:XeeListEntry
{
	CSHandle *originalhandle;
	NSString *name;
}

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)descname;
-(void)dealloc;
-(NSString *)descriptiveName;

-(CSHandle *)newHandle;

@end

@interface XeeSWFJPEGEntry:XeeSWFEntry {}
-(XeeImage *)produceImage;
@end

@interface XeeSWFLossless3Entry:XeeSWFEntry {}
-(XeeImage *)produceImage;
@end

@interface XeeSWFLossless3AlphaEntry:XeeSWFEntry {}
-(XeeImage *)produceImage;
@end

@interface XeeSWFLossless5Entry:XeeSWFEntry {}
-(XeeImage *)produceImage;
@end

@interface XeeSWFLossless5AlphaEntry:XeeSWFEntry {}
-(XeeImage *)produceImage;
@end
