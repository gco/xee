#import "CSHandle.h"

#include <zlib.h>

@interface CSZlibHandle:CSHandle
{
	CSHandle *fh;
	off_t startoffs;
	z_stream zs;
	BOOL inited,eof;
	uint8_t inbuffer[128*1024];
}

+(CSZlibHandle *)zlibHandleWithHandle:(CSHandle *)handle;
//+(CSZlibHandle *)zlibHandleWithPath:(NSString *)path;

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)descname;
-(void)dealloc;

-(off_t)offsetInFile;
-(BOOL)atEndOfFile;

-(void)seekToFileOffset:(off_t)offs;
-(void)seekToEndOfFile;
-(int)readAtMost:(int)num toBuffer:(void *)buffer;

-(void)_raiseZlib;

@end
