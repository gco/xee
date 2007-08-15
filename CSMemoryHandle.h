#import "CSHandle.h"

@interface CSMemoryHandle:CSHandle
{
	NSData *data;
	off_t pos;
}

+(CSMemoryHandle *)memoryHandleForReadingData:(NSData *)data;
+(CSMemoryHandle *)memoryHandleForReadingBuffer:(void *)buf length:(unsigned)len;
+(CSMemoryHandle *)memoryHandleForWriting;

-(id)initWithData:(NSData *)dataobj;
-(void)dealloc;

-(off_t)fileSize;
-(off_t)offsetInFile;
-(BOOL)atEndOfFile;

-(void)seekToFileOffset:(off_t)offs;
-(void)seekToEndOfFile;
//-(void)pushBackByte:(int)byte;
-(int)readAtMost:(int)num toBuffer:(void *)buffer;
-(void)writeBytes:(int)num fromBuffer:(const void *)buffer;

-(NSData *)data;
-(NSMutableData *)mutableData;

@end
