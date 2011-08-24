#import "XeeIFFHandle.h"


@implementation XeeIFFHandle

-(id)initWithFilePointer:(FILE *)file closeOnDealloc:(BOOL)shouldclose description:(NSString *)description fileType:(iff_id)filetype
{
	if(self=[super initWithFilePointer:file closeOnDealloc:shouldclose description:description])
	{
		iff_id fileid=[super readID];

		switch(fileid)
		{
			case 'FORM': alignmask=1; littleendian=NO; break;
			case 'FOR4': alignmask=3; littleendian=NO; break;
			case 'FOR8': alignmask=7; littleendian=NO; break;
			case 'CAT ': alignmask=1; littleendian=NO; break;
			case 'CAT4': alignmask=3; littleendian=NO; break;
			case 'CAT8': alignmask=7; littleendian=NO; break;
			case 'LIST': alignmask=1; littleendian=NO; break;
			case 'LIS4': alignmask=3; littleendian=NO; break;
			case 'LIS8': alignmask=7; littleendian=NO; break;
			case 'PROP': alignmask=1; littleendian=NO; break;
			case 'PRO4': alignmask=3; littleendian=NO; break;
			case 'PRO8': alignmask=7; littleendian=NO; break;
			case 'RIFF': alignmask=1; littleendian=YES; break;
			case 'RIFX': alignmask=1; littleendian=NO; break;
			default: [self release]; return nil;
		}

		fileend=[self _readHeaderUint32]+[super offsetInFile];

		mainid=[super readID];
		if(filetype&&filetype!=mainid) { [self release]; return nil; }

		nextchunk=[super offsetInFile];
		currid=0;
		currsize=0;

		return self;
	}

	return nil;
}



-(BOOL)isShort { return fileend>[super fileSize]; }



-(iff_id)fileType { return mainid; }

-(iff_id)nextChunk
{
	if(nextchunk>=fileend) return 0;

	[super seekToFileOffset:nextchunk];
	currid=[super readID];
	currsize=[self _readHeaderUint32];
	nextchunk+=8+((currsize+alignmask)&~alignmask);

	return currid;
}

-(iff_id)currentChunk { return currid; }

-(uint32)chunkSize { return currsize; }

-(uint32)bytesLeft { return nextchunk-[self offsetInFile]; }




#define READ_INT_ENDIAN_IMPL(type,name) \
-(type)name \
{ \
	if(littleendian) return [self name##LE]; \
	else return [self name##BE]; \
}

READ_INT_ENDIAN_IMPL(int16,readInt16)
READ_INT_ENDIAN_IMPL(uint16,readUint16)
READ_INT_ENDIAN_IMPL(int32,readInt32)
READ_INT_ENDIAN_IMPL(uint32,readUint32)
READ_INT_ENDIAN_IMPL(int64,readInt64)
READ_INT_ENDIAN_IMPL(uint64,readUint64)

-(uint32)_readHeaderUint32
{
	if(littleendian) return [super readUint32LE];
	else return [super readUint32BE];
}



-(NSData *)chunkContents { return [[self copyChunkContents] autorelease]; }

-(NSData *)restOfChunkContents { return [[self copyRestOfChunkContents] autorelease]; }

-(NSData *)copyChunkContents
{
	[super seekToFileOffset:nextchunk-currsize];
	return [super copyDataOfLength:currsize];
}

-(NSData *)copyRestOfChunkContents { return [super copyDataOfLength:[self bytesLeft]]; }



-(XeeIFFHandle *)IFFHandleForChunk
{
	if(currid=='FORM'||currid=='FOR4'||currid=='FOR8'
	||currid=='CAT '||currid=='CAT4'||currid=='CAT8'
	||currid=='LIST'||currid=='LIS4'||currid=='LIS8'
	||currid=='PROP'||currid=='PRO4'||currid=='PRO8')
	{
		[super seekToFileOffset:nextchunk-currsize-8];
		return [[[XeeIFFHandle alloc] initWithFilePointer:fh closeOnDealloc:NO description:desc fileType:0] autorelease];
	}
	else return nil;
}



#define READ_INT_OVERRIDE_IMPL(type,name,size) \
-(type)name \
{ \
	if([self bytesLeft]<size) [self _raiseChunk]; \
	return [super name]; \
}

READ_INT_OVERRIDE_IMPL(int8,readInt8,1)
READ_INT_OVERRIDE_IMPL(uint8,readUint8,1)
READ_INT_OVERRIDE_IMPL(int16,readInt16BE,2)
READ_INT_OVERRIDE_IMPL(uint16,readUint16BE,2)
READ_INT_OVERRIDE_IMPL(int32,readInt32BE,4)
READ_INT_OVERRIDE_IMPL(uint32,readUint32BE,4)
READ_INT_OVERRIDE_IMPL(int64,readInt64BE,8)
READ_INT_OVERRIDE_IMPL(uint64,readUint64BE,8)
READ_INT_OVERRIDE_IMPL(int16,readInt16LE,2)
READ_INT_OVERRIDE_IMPL(uint16,readUint16LE,2)
READ_INT_OVERRIDE_IMPL(int32,readInt32LE,4)
READ_INT_OVERRIDE_IMPL(uint32,readUint32LE,4)
READ_INT_OVERRIDE_IMPL(int64,readInt64LE,8)
READ_INT_OVERRIDE_IMPL(uint64,readUint64LE,8)
READ_INT_OVERRIDE_IMPL(uint32,readID,4)



-(NSData *)readDataToEndOfFile { return [self restOfChunkContents]; }

-(NSData *)copyDataOfLength:(int)count
{
	if([self bytesLeft]<count) [self _raiseChunk];
	return [super copyDataOfLength:count];
}



-(void)readBytes:(int)count toBuffer:(void *)buffer
{
	if([self bytesLeft]<count) [self _raiseChunk];
	[self readBytes:count toBuffer:buffer];
}



-(void)seekToEndOfFile { [self _raiseNotSupported]; }

-(void)seekToFileOffset:(off_t)position { [self _raiseNotSupported]; }

-(void)skipBytes:(off_t)count
{
	int pos=[self offsetInFile];
	if(pos+count>nextchunk||pos+count<nextchunk-currsize) [self _raiseChunk];
	[super skipBytes:count];
}



-(void)_raiseChunk
{
	[NSException raise:@"XeeIFFChunkException" format:@"Attempted to access file \"%@\" outside of current chunk %c%c%c%c",
	desc,(currid>>24)&0xff,(currid>>16)&0xff,(currid>>8)&0xff,currid&0xff];
}

-(void)_raiseNotSupported
{
	[NSException raise:@"XeeIFFNotSupportedException" format:@"Operation not supported for file \"%@\"",desc];
}


+(XeeIFFHandle *)IFFHandleWithPath:(NSString *)path { return [self IFFHandleWithPath:path fileType:0]; }

+(XeeIFFHandle *)IFFHandleWithPath:(NSString *)path fileType:(iff_id)filetype
{
	FILE *fh=fopen([path fileSystemRepresentation],"rb");
	if(fh) return [[[XeeIFFHandle alloc] initWithFilePointer:fh closeOnDealloc:YES description:path fileType:filetype] autorelease];
	else return nil;
}

@end
