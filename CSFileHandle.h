#import "CSHandle.h"

#import <stdio.h>

@interface CSFileHandle:CSHandle
{
	FILE *fh;
	BOOL close;
}

+(CSFileHandle *)fileHandleForReadingAtPath:(NSString *)path;
+(CSFileHandle *)fileHandleForWritingAtPath:(NSString *)path;
+(CSFileHandle *)fileHandleForPath:(NSString *)path modes:(NSString *)modes;

-(id)initWithFilePointer:(FILE *)file closeOnDealloc:(BOOL)closeondealloc name:(NSString *)descname;
-(void)dealloc;

-(off_t)fileSize;
-(off_t)offsetInFile;
-(BOOL)atEndOfFile;

-(void)seekToFileOffset:(off_t)offs;
-(void)seekToEndOfFile;
-(void)pushBackByte:(int)byte;
-(int)readAtMost:(int)num toBuffer:(void *)buffer;
-(void)writeBytes:(int)num fromBuffer:(const void *)buffer;

-(void)_raiseError;

-(FILE *)filePointer;

@end
