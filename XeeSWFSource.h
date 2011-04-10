#import "XeeFileSource.h"
#import "SWFParser.h"

#import <XADMaster/CSMemoryHandle.h>

@interface XeeSWFSource:XeeListSource
{
	NSString *filename;
	SWFParser *parser;
}

+(NSArray *)fileTypes;

-(id)initWithFile:(NSString *)swfname;
-(void)dealloc;

-(void)start;

-(NSString *)windowTitle;
-(NSString *)windowRepresentedFilename;
-(BOOL)canBrowse;

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
