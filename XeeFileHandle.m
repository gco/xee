#import "XeeFileHandle.h"


@implementation XeeFileHandle

-(id)initWithFilePointer:(FILE *)file closeOnDealloc:(BOOL)shouldclose description:(NSString *)description
{
	if(self=[super init])
	{
		fh=file;
		close=shouldclose;
		desc=[description retain];
	}
	return self;
}

-(void)dealloc
{
	if(close&&fh) fclose(fh);
	[desc release];
	[super dealloc];
}

-(void)closeFile
{
	if(fh) fclose(fh);
	fh=NULL;
}



-(int8)readInt8
{
	if(!fh) [self _raiseClosed];
	int c=getc(fh);
	if(c==EOF) [self _raiseError];
	return c;
}

-(uint8)readUint8
{
	if(!fh) [self _raiseClosed];
	int c=getc(fh);
	if(c==EOF) [self _raiseError];
	return c;
}

#define READ_INT_IMPL(type,name,size,convmacro) \
-(type)name \
{ \
	if(!fh) [self _raiseClosed]; \
	uint8 val[size]; \
	if(fread(val,1,size,fh)!=size) [self _raiseError]; \
	return convmacro(val); \
}

READ_INT_IMPL(int16,readInt16BE,2,read_be_int16);
READ_INT_IMPL(uint16,readUint16BE,2,read_be_uint16);
READ_INT_IMPL(int32,readInt32BE,4,read_be_int32);
READ_INT_IMPL(uint32,readUint32BE,4,read_be_uint32);
READ_INT_IMPL(int64,readInt64BE,8,read_be_int32);
READ_INT_IMPL(uint64,readUint64BE,8,read_be_uint32);
READ_INT_IMPL(int16,readInt16LE,2,read_le_int16);
READ_INT_IMPL(uint16,readUint16LE,2,read_le_uint16);
READ_INT_IMPL(int32,readInt32LE,4,read_le_int32);
READ_INT_IMPL(uint32,readUint32LE,4,read_le_uint32);
READ_INT_IMPL(int64,readInt64LE,8,read_le_int32);
READ_INT_IMPL(uint64,readUint64LE,8,read_le_uint32);
READ_INT_IMPL(uint32,readID,4,read_be_uint32);



-(NSData *)readDataOfLength:(int)count { return [[self copyDataOfLength:count] autorelease]; }

-(NSData *)readDataToEndOfFile
{
	if(!fh) [self _raiseClosed];

	return [[self copyDataOfLength:[self fileSize]-[self offsetInFile]] autorelease];
}

-(NSData *)copyDataOfLength:(int)count
{
	if(!fh) [self _raiseClosed];

	void *mem=malloc(count);
	if(!mem) [self _raiseMemory];

	NSData *data=[[NSData alloc] initWithBytesNoCopy:mem length:count freeWhenDone:YES];
	if(!data) { free(mem); [self _raiseMemory]; }

	if(fread(mem,1,count,fh)!=count) { [data release]; [self _raiseError]; }

	return data;
}



-(void)readBytes:(int)count toBuffer:(void *)buffer
{
	if(!fh) [self _raiseClosed];
	if(fread(buffer,1,count,fh)!=count) [self _raiseError];
}



-(off_t)offsetInFile
{
	if(!fh) [self _raiseClosed];

	off_t pos=ftello(fh);
	if(pos<0) [self _raiseError];

	return pos;
}

-(off_t)fileSize
{
	if(!fh) [self _raiseClosed];

	off_t pos=ftello(fh);
	if(pos<0) [self _raiseError];
	if(fseek(fh,0,SEEK_END)) [self _raiseError];
	off_t end=ftello(fh);
	if(end<0) [self _raiseError];
	if(fseek(fh,pos,SEEK_SET)) [self _raiseError];

	return end;
}

-(void)seekToEndOfFile
{
	if(!fh) [self _raiseClosed];
	if(fseek(fh,0,SEEK_END)) [self _raiseError];
}

-(void)seekToFileOffset:(off_t)position
{
	if(!fh) [self _raiseClosed];
	if(fseek(fh,position,SEEK_SET)) [self _raiseError];
}

-(void)skipBytes:(off_t)count
{
	if(!fh) [self _raiseClosed];
	if(fseek(fh,count,SEEK_CUR)) [self _raiseError];
}

-(FILE *)filePointer { return fh; }

-(void)_raiseError
{
	if(feof(fh)) [NSException raise:@"XeeEOFException" format:@"Attempted to read past the end of file \"%@\"",desc];
	else [NSException raise:@"XeeFileErrorException" format:@"Error %d while trying to access file \"%@\"",errno,desc];
}

-(void)_raiseClosed
{
	[NSException raise:@"XeeFileClosedException" format:@"Attempted to access closed file \"%@\"",desc];
}

-(void)_raiseMemory
{
	[NSException raise:@"XeeFileClosedException" format:@"Out of memory while trying to access file \"%@\"",desc];
}

+(XeeFileHandle *)fileHandleWithPath:(NSString *)path
{
	FILE *fh=fopen([path fileSystemRepresentation],"rb");
	if(fh) return [[[XeeFileHandle alloc] initWithFilePointer:fh closeOnDealloc:YES description:path] autorelease];
	else return nil;
}

@end
