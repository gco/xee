#import "XeeTypes.h"

#import <stdio.h>

@interface XeeFileHandle:NSObject
{
	FILE *fh;
	BOOL close;
	NSString *desc;
}

-(id)initWithFilePointer:(FILE *)file closeOnDealloc:(BOOL)closeondealloc description:(NSString *)description;
-(void)dealloc;

-(void)closeFile;

-(FILE *)filePointer;
-(off_t)offsetInFile;
-(off_t)fileSize;

-(void)seekToEndOfFile;
-(void)seekToFileOffset:(off_t)offs;
-(void)skipBytes:(off_t)bytes;

-(int8)readInt8;
-(uint8)readUInt8;

-(int16)readInt16BE;
-(int32)readInt32BE;
-(int64)readInt64BE;
-(uint16)readUInt16BE;
-(uint32)readUInt32BE;
-(uint64)readUInt64BE;

-(int16)readInt16LE;
-(int32)readInt32LE;
-(int64)readInt64LE;
-(uint16)readUInt16LE;
-(uint32)readUInt32LE;
-(uint64)readUInt64LE;

-(uint32)readID;

-(void)pushBackByte:(int)byte;

-(NSData *)fileContents;
-(NSData *)remainingFileContents;
-(NSData *)readDataOfLength:(int)length;
-(NSData *)copyDataOfLength:(int)length;
-(void)readBytes:(int)num toBuffer:(void *)buffer;

-(void)_raiseError;
-(void)_raiseClosed;
-(void)_raiseMemory;

-(NSString *)description;

+(XeeFileHandle *)fileHandleWithPath:(NSString *)path;

@end
