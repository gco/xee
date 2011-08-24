#import "XeeFileHandle.h"


typedef uint32 iff_id;

@interface XeeIFFHandle:XeeFileHandle
{
	FILE *fh;
	uint32 fileend,mainid,nextchunk,currsize;
	iff_id currid;
	int alignmask;
	BOOL littleendian;
}

-(id)initWithFilePointer:(FILE *)file closeOnDealloc:(BOOL)shouldclose description:(NSString *)description fileType:(iff_id)filetype;

-(BOOL)isShort;

-(iff_id)fileType;
-(iff_id)nextChunk;
-(iff_id)currentChunk;
-(uint32)chunkSize;
-(uint32)bytesLeft;

-(int16)readInt16;
-(uint16)readUint16;
-(int32)readInt32;
-(uint32)readUint32;
-(int64)readInt64;
-(uint64)readUint64;
-(uint32)_readHeaderUint32;

-(NSData *)chunkContents;
-(NSData *)restOfChunkContents;
-(NSData *)copyChunkContents;
-(NSData *)copyRestOfChunkContents;

-(XeeIFFHandle *)IFFHandleForChunk;

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

-(NSData *)readDataToEndOfFile;
-(NSData *)copyDataOfLength:(int)count;

-(void)readBytes:(int)count toBuffer:(void *)buffer;

-(void)seekToEndOfFile;
-(void)seekToFileOffset:(off_t)position;
-(void)skipBytes:(off_t)count;

-(void)_raiseChunk;
-(void)_raiseNotSupported;

+(XeeIFFHandle *)IFFHandleWithPath:(NSString *)path;
+(XeeIFFHandle *)IFFHandleWithPath:(NSString *)path fileType:(iff_id)filetype;

@end
