#import <XADMaster/CSFileHandle.h>
#import "XeeTypes.h"

@interface XeeIFFHandle:CSFileHandle
{
	uint32_t file_id,file_end,file_type;
	uint32_t next_chunk;
	uint32_t curr_id,curr_start,curr_size;
	int align_mask;
	BOOL big_endian;
}

-(id)initWithFilePointer:(FILE *)file closeOnDealloc:(BOOL)closeondealloc description:(NSString *)description fileType:(uint32_t)type;

-(BOOL)isShort;

-(uint32_t)fileID;
-(uint32_t)fileType;

-(uint32_t)nextChunk;

-(uint32_t)offsetInChunk;
-(uint32_t)chunkSize;
-(uint32_t)chunkID;
-(uint32_t)bytesLeft;

-(void)seekToChunkOffset:(off_t)offs;
-(void)seekToEndOfFile;
-(void)seekToFileOffset:(off_t)offs;

-(int16_t)readInt16;
-(int32_t)readInt32;
-(int64_t)readInt64;
-(uint16_t)readUInt16;
-(uint32_t)readUInt32;
-(uint64_t)readUInt64;

-(uint32_t)_readHeaderUint32;

-(int8_t)readInt8;
-(uint8_t)readUInt8;

-(int16_t)readInt16BE;
-(int32_t)readInt32BE;
-(int64_t)readInt64BE;
-(uint16_t)readUInt16BE;
-(uint32_t)readUInt32BE;
-(uint64_t)readUInt64BE;

-(int16_t)readInt16LE;
-(int32_t)readInt32LE;
-(int64_t)readInt64LE;
-(uint16_t)readUInt16LE;
-(uint32_t)readUInt32LE;
-(uint64_t)readUInt64LE;

-(uint32_t)readID;

-(void)pushBackByte:(int)byte;

-(NSData *)chunkContents;
-(NSData *)remainingChunkContents;
-(NSData *)copyChunkContents;
-(NSData *)copyRemainingChunkContents;
-(NSData *)fileContents;
-(NSData *)remainingFileContents;
-(void)readBytes:(int)num toBuffer:(void *)buffer;

-(XeeIFFHandle *)IFFHandleForChunk;

-(void)_raiseChunk;

-(NSString *)description;

+(id)IFFHandleWithPath:(NSString *)path;
+(id)IFFHandleWithPath:(NSString *)path fileType:(uint32_t)type;

@end
