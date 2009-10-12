#import <XADMaster/CSHandle.h>

@interface XeeInterleavingHandle:CSHandle
{
	NSArray *handles;
	int n2,bits;
}

-(id)initWithHandles:(NSArray *)handlearray elementSize:(int)bitsize;
-(void)dealloc;

//-(off_t)fileSize;
//-(off_t)offsetInFile;
//-(BOOL)atEndOfFile;
//-(void)seekToFileOffset:(off_t)offs;
//-(void)seekToEndOfFile;
-(int)readAtMost:(int)num toBuffer:(void *)buffer;
//-(id)copyWithZone:(NSZone *)zone;

@end

