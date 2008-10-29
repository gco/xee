#import "CSHandle.h"

@interface CSStreamHandle:CSHandle
{
	off_t streampos;
	BOOL needsreset,endofstream;
	int nextstreambyte;
}

-(id)initWithName:(NSString *)descname;
-(id)initAsCopyOf:(CSStreamHandle *)other;

-(off_t)offsetInFile;
-(BOOL)atEndOfFile;
-(void)seekToFileOffset:(off_t)offs;
-(int)readAtMost:(int)num toBuffer:(void *)buffer;

-(void)resetStream;
-(int)streamAtMost:(int)num toBuffer:(void *)buffer;

-(void)endStream;

@end
