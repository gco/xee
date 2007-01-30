#import "XeeIFFHandle.h"

@implementation XeeIFFHandle

-(id)initWithFilePointer:(FILE *)file closeOnDealloc:(BOOL)closeondealloc description:(NSString *)description fileType:(uint32)type
{
	if(self=[super initWithFilePointer:file closeOnDealloc:closeondealloc description:description])
	{
		file_id=[super readID];
		switch(file_id)
		{
			case 'FORM': case 'LIST': case 'CAT ': case 'PROP': case 'RIFX':
				align_mask=1;
				big_endian=YES;
			break;
			case 'FOR4': case 'LIS4': case 'CAT4': case 'PRO4':
				align_mask=3;
				big_endian=YES;
			break;
			case 'FOR8': case 'LIS8': case 'CAT8': case 'PRO8':
				align_mask=7;
				big_endian=YES;
			break;
			case 'RIFF':
				align_mask=1;
				big_endian=NO;
			break;
			default:
				[self release];
				return nil;
		}

		file_end=[self offsetInFile]+[self _readHeaderUint32];

		file_type=[super readID];
		if(type&&file_type!=type)
		{
			[self release];
			return nil;
		}

		next_chunk=[self offsetInFile];
		curr_id=curr_start=curr_size=0;
	}
	return self;
}

-(BOOL)isShort
{
	return file_end>=[self fileSize];
}

-(uint32)fileID { return file_id; }

-(uint32)fileType { return file_type; }



-(uint32)nextChunk
{
	if(next_chunk>=file_end)
	{
		curr_id=0;
		curr_size=0;
		curr_start=0;
		return 0;
	}

	[super seekToFileOffset:next_chunk];

	curr_id=[super readID];
	curr_size=[self _readHeaderUint32];
	curr_start=next_chunk+8;

	next_chunk=curr_start+((curr_size+align_mask)&~align_mask);

	return curr_id;
}



-(uint32)offsetInChunk { return [self offsetInFile]-curr_start; }

-(uint32)chunkSize { return curr_size; }

-(uint32)chunkID { return curr_id; }

-(uint32)bytesLeft { return curr_start+curr_size-[self offsetInFile]; }



-(void)seekToChunkOffset:(off_t)offs
{
	uint32 newpos=curr_start+offs;
	if(newpos<curr_start||newpos>=curr_start+curr_size) [self _raiseChunk];
	[super seekToFileOffset:newpos];
}

-(void)seekToEndOfFile { [self _raiseNotSupported]; }

-(void)seekToFileOffset:(off_t)offs { [self _raiseNotSupported]; }

-(void)skipBytes:(off_t)bytes
{
	uint32 newpos=[self offsetInFile]+bytes;
	if(newpos<curr_start||newpos>=curr_start+curr_size) [self _raiseChunk];
	[super skipBytes:bytes];
}




-(int16)readInt16
{
	if(big_endian) return [self readInt16BE];
	else return [self readInt16LE];
}

-(int32)readInt32
{
	if(big_endian) return [self readInt32BE];
	else return [self readInt32LE];
}

-(int64)readInt64
{
	if(big_endian) return [self readInt64BE];
	else return [self readInt64LE];
}

-(uint16)readUInt16
{
	if(big_endian) return [self readUInt16BE];
	else return [self readUInt16LE];
}

-(uint32)readUInt32
{
	if(big_endian) return [self readUInt32BE];
	else return [self readUInt32LE];
}

-(uint64)readUInt64
{
	if(big_endian) return [self readUInt64BE];
	else return [self readUInt64LE];
}

-(uint32)_readHeaderUint32
{
	if(big_endian) return [super readUInt32BE];
	else return [super readUInt32LE];
}

#define XeeIFFReadValueImpl(type,name) \
-(type)name \
{ \
	if([self bytesLeft]<sizeof(type)) [self _raiseChunk]; \
	return [super name]; \
} 

XeeIFFReadValueImpl(int8,readInt8)
XeeIFFReadValueImpl(uint8,readUInt8)

XeeIFFReadValueImpl(int16,readInt16BE)
XeeIFFReadValueImpl(int32,readInt32BE)
XeeIFFReadValueImpl(int64,readInt64BE)
XeeIFFReadValueImpl(uint16,readUInt16BE)
XeeIFFReadValueImpl(uint32,readUInt32BE)
XeeIFFReadValueImpl(uint64,readUInt64BE)

XeeIFFReadValueImpl(int16,readInt16LE)
XeeIFFReadValueImpl(int32,readInt32LE)
XeeIFFReadValueImpl(int64,readInt64LE)
XeeIFFReadValueImpl(uint16,readUInt16LE)
XeeIFFReadValueImpl(uint32,readUInt32LE)
XeeIFFReadValueImpl(uint64,readUInt64LE)

XeeIFFReadValueImpl(uint32,readID)



-(void)pushBackByte:(int)byte { [self _raiseNotSupported]; }



-(NSData *)chunkContents { return [[self copyChunkContents] autorelease]; }

-(NSData *)remainingChunkContents { return [[self copyRemainingChunkContents] autorelease]; }

-(NSData *)copyChunkContents
{
	[self seekToChunkOffset:0];
	return [self copyRemainingChunkContents];
}

-(NSData *)copyRemainingChunkContents
{
	return [super copyDataOfLength:[self bytesLeft]];
}

-(NSData *)fileContents { [self _raiseNotSupported]; return nil; }

-(NSData *)remainingFileContents { [self _raiseNotSupported]; return nil; }

-(void)readBytes:(int)num toBuffer:(void *)buffer
{
	if([self offsetInFile]+num>curr_start+curr_size) [self _raiseChunk];
	[super readBytes:num toBuffer:buffer];
}



-(XeeIFFHandle *)IFFHandleForChunk
{
	if(!curr_start) [self _raiseChunk];
	[super seekToFileOffset:curr_start-8];
	return [[[XeeIFFHandle alloc] initWithFilePointer:fh closeOnDealloc:NO description:desc fileType:0] autorelease];
}



-(void)_raiseChunk
{
	if(!curr_start) [NSException raise:@"XeeNoIFFChunkException" format:@"Attempted to read from an IFF handle before the first chunk has been parsed."];
	else [NSException raise:@"XeeReadOutsideChunkException" format:@"Attempted to read outside the current IFF chunk."];
}

-(void)_raiseNotSupported
{
	[NSException raise:@"XeeNotSupportedInIFFException" format:@"Action not supported for IFF handles."];
}



-(NSString *)description
{
	return [NSString stringWithFormat:@"XeeIFFHandle for file \"%@\", position %d in chunk %c%c%c%c",
	desc,[self offsetInChunk],(curr_id>>24)&0xff,(curr_id>>16)&0xff,(curr_id>>8)&0xff,curr_id&0xff];
}



+(id)IFFHandleWithPath:(NSString *)path { return [self IFFHandleWithPath:path fileType:0]; }

+(id)IFFHandleWithPath:(NSString *)path fileType:(uint32)type
{
	if(!path) return nil;

	FILE *fh=fopen([path fileSystemRepresentation],"rb");
	XeeFileHandle *handle=[[[XeeIFFHandle alloc] initWithFilePointer:fh closeOnDealloc:YES description:path fileType:type] autorelease];
	if(handle) return handle;

	fclose(fh);
	return nil;
}

@end
