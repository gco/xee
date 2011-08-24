#import "XeeTypes.h"

#import <Cocoa/Cocoa.h>
#import <sys/types.h>

@interface XeeFileHandle:NSObject
{
	FILE *fh;
	BOOL close;
	NSString *desc;
}

-(id)initWithFilePointer:(FILE *)file closeOnDealloc:(BOOL)shouldclose description:(NSString *)description;
-(void)dealloc;

-(void)closeFile;

-(int8)readInt8;
-(uint8)readUint8;
-(int16)readInt16BE;
-(uint16)readUint16BE;
-(int32)readInt32BE;
-(uint32)readUint32BE;
-(int64)readInt64BE;
-(uint64)readUint64BE;
-(int16)readInt16LE;
-(uint16)readUint16LE;
-(int32)readInt32LE;
-(uint32)readUint32LE;
-(int64)readInt64LE;
-(uint64)readUint64LE;
-(uint32)readID;

-(NSData *)readDataOfLength:(int)count;
-(NSData *)readDataToEndOfFile;
-(NSData *)copyDataOfLength:(int)count;

-(void)readBytes:(int)count toBuffer:(void *)buffer;

-(off_t)offsetInFile;
-(off_t)fileSize;
-(void)seekToEndOfFile;
-(void)seekToFileOffset:(off_t)position;
-(void)skipBytes:(off_t)count;

-(FILE *)filePointer;

-(void)_raiseError;
-(void)_raiseClosed;
-(void)_raiseMemory;

+(XeeFileHandle *)fileHandleWithPath:(NSString *)path;

@end
