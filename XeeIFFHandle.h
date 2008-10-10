#import "CSFileHandle.h"
	#import "XeeTypes.h"

@interface XeeIFFHandle:CSFileHandle
{
	uint32 file_id,file_end,file_type;
	uint32 next_chunk;
	uint32 curr_id,curr_start,curr_size;
	int align_mask;
	BOOL big_endian;
}

-(id)initWithFilePointer:(FILE *)file closeOnDealloc:(BOOL)closeondealloc description:(NSString *)description fileType:(uint32)type;

-(BOOL)isShort;

-(uint32)fileID;
-(uint32)fileType;

-(uint32)nextChunk;

-(uint32)offsetInChunk;
-(uint32)chunkSize;
-(uint32)chunkID;
-(uint32)bytesLeft;

-(void)seekToChunkOffset:(off_t)offs;
-(void)seekToEndOfFile;
-(void)seekToFileOffset:(off_t)offs;

-(int16)readInt16;
-(int32)readInt32;
-(int64)readInt64;
-(uint16)readUInt16;
-(uint32)readUInt32;
-(uint64)readUInt64;

-(uint32)_readHeaderUint32;

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
+(id)IFFHandleWithPath:(NSString *)path fileType:(uint32)type;

@end
