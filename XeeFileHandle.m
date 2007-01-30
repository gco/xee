#import "XeeFileHandle.h"

#include <sys/stat.h>



@implementation XeeFileHandle

-(id)initWithFilePointer:(FILE *)file closeOnDealloc:(BOOL)closeondealloc description:(NSString *)description
{
	if(self=[super init])
	{
		fh=file;
		close=closeondealloc;
		desc=[description retain];
	}
	return self;
}

-(void)dealloc
{
	if(fh&&close) fclose(fh);
	[desc release];

	[super dealloc];
}

-(void)closeFile
{
	if(fh) fclose(fh);
	fh=NULL;
}



-(FILE *)filePointer
{
	return fh;
}

-(off_t)offsetInFile
{
	if(!fh) [self _raiseClosed];
	return ftello(fh);
}

-(off_t)fileSize
{
	if(!fh) [self _raiseClosed];

	struct stat s;
	if(fstat(fileno(fh),&s)) [self _raiseError];
	return s.st_size;
}



-(void)seekToEndOfFile
{
	if(!fh) [self _raiseClosed];
	if(fseek(fh,0,SEEK_END)) [self _raiseError];
}

-(void)seekToFileOffset:(off_t)offs
{
	if(!fh) [self _raiseClosed];
	if(fseek(fh,offs,SEEK_SET)) [self _raiseError];
}

-(void)skipBytes:(off_t)bytes
{
	if(!fh) [self _raiseClosed];
	if(fseek(fh,bytes,SEEK_CUR)) [self _raiseError];
}



-(int8)readInt8;
{
	if(!fh) [self _raiseClosed];
	int c=fgetc(fh);
	if(c==EOF) [self _raiseError];
	return (int8)c;
}

-(uint8)readUInt8
{
	if(!fh) [self _raiseClosed];
	int c=fgetc(fh);
	if(c==EOF) [self _raiseError];
	return (uint8)c;
}

#define XeeReadValueImpl(type,name,conv) \
-(type)name \
{ \
	uint8 bytes[sizeof(type)]; \
	if(!fh) [self _raiseClosed]; \
	if(fread(bytes,1,sizeof(type),fh)!=sizeof(type)) [self _raiseError]; \
	return conv(bytes); \
}

//XeeReadValueImpl(int8,readInt8,(int8)*)
//XeeReadValueImpl(uint8,readUInt8,(uint8)*)

XeeReadValueImpl(int16,readInt16BE,XeeBEInt16)
XeeReadValueImpl(int32,readInt32BE,XeeBEInt32)
XeeReadValueImpl(int64,readInt64BE,XeeBEInt64)
XeeReadValueImpl(uint16,readUInt16BE,XeeBEUInt16)
XeeReadValueImpl(uint32,readUInt32BE,XeeBEUInt32)
XeeReadValueImpl(uint64,readUInt64BE,XeeBEUInt64)

XeeReadValueImpl(int16,readInt16LE,XeeLEInt16)
XeeReadValueImpl(int32,readInt32LE,XeeLEInt32)
XeeReadValueImpl(int64,readInt64LE,XeeLEInt64)
XeeReadValueImpl(uint16,readUInt16LE,XeeLEUInt16)
XeeReadValueImpl(uint32,readUInt32LE,XeeLEUInt32)
XeeReadValueImpl(uint64,readUInt64LE,XeeLEUInt64)

XeeReadValueImpl(uint32,readID,XeeBEUInt32)



-(void)pushBackByte:(int)byte
{
	if(ungetc(byte,fh)==EOF) [self _raiseError];
}



-(NSData *)fileContents
{
	[self seekToFileOffset:0];
	return [self remainingFileContents];
}

-(NSData *)remainingFileContents
{
	return [self readDataOfLength:[self fileSize]-[self offsetInFile]];
}

-(NSData *)readDataOfLength:(int)length
{
	return [[self copyDataOfLength:length] autorelease];
}

-(NSData *)copyDataOfLength:(int)length
{
	NSMutableData *data=[[NSMutableData alloc] initWithLength:length];
	if(!data) [self _raiseMemory];
	[self readBytes:length toBuffer:[data mutableBytes]];
	return data;
}

-(void)readBytes:(int)num toBuffer:(void *)buffer
{
	if(!fh) [self _raiseClosed];
	if(fread(buffer,1,num,fh)!=num) [self _raiseError];
}



-(void)_raiseError
{
	if(feof(fh)) [NSException raise:@"XeeEndOfFileException" format:@"Attempted to read past the end of file \"%@\".",desc];
	else [NSException raise:@"XeeFileErrorException" format:@"Error while attempting to read file \"%@\": %s.",desc,strerror(ferror(fh))];
}

-(void)_raiseClosed
{
	[NSException raise:@"XeeFileNotOpenException" format:@"Attempted to read from file \"%@\", which was not open.",desc];
}

-(void)_raiseMemory
{
	[NSException raise:@"XeeOutOfMemoryException" format:@"Out of memory while attempting to read from file \"%@\".",desc];
}

-(NSString *)description
{
	return [NSString stringWithFormat:@"XeeFileHandle for file \"%@\", position %qu",
	desc,[self offsetInFile]];
}

+(XeeFileHandle *)fileHandleWithPath:(NSString *)path
{
	if(!path) return nil;

	FILE *fh=fopen([path fileSystemRepresentation],"rb");
	XeeFileHandle *handle=[[[XeeFileHandle alloc] initWithFilePointer:fh closeOnDealloc:YES description:path] autorelease];
	if(handle) return handle;

	fclose(fh);
	return nil;
}

@end
