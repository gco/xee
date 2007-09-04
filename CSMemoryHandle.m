#import "CSMemoryHandle.h"


@implementation CSMemoryHandle



+(CSMemoryHandle *)memoryHandleForReadingData:(NSData *)data
{
	return [[[CSMemoryHandle alloc] initWithData:data] autorelease];
}

+(CSMemoryHandle *)memoryHandleForReadingBuffer:(void *)buf length:(unsigned)len
{
	return [[[CSMemoryHandle alloc] initWithData:[NSData dataWithBytesNoCopy:buf length:len freeWhenDone:NO]] autorelease];
}

+(CSMemoryHandle *)memoryHandleForWriting
{
	return [[[CSMemoryHandle alloc] initWithData:[NSMutableData data]] autorelease];
}


-(id)initWithData:(NSData *)dataobj
{
	if(self=[super initWithName:[NSString stringWithFormat:@"NSData at 0x%x",(int)dataobj]])
	{
		pos=0;
		data=[dataobj retain];
	}
	return self;
}

-(void)dealloc
{
	[data release];
	[super dealloc];
}





-(off_t)fileSize { return [data length]; }

-(off_t)offsetInFile { return pos; }

-(BOOL)atEndOfFile { return pos==[data length]; }



-(void)seekToFileOffset:(off_t)offs
{
	if(offs<0) [self _raiseNotSupported];
	if(offs>[data length]) [self _raiseEOF];
	pos=offs;
}

-(void)seekToEndOfFile { pos=[data length]; }

//-(void)pushBackByte:(int)byte {}

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	if(!num) return 0;

	int len=[data length];
	if(pos==len) [self _raiseEOF];
	if(pos+num>len) num=len-pos;
	memcpy(buffer,(uint8_t *)[data bytes]+pos,num);
	pos+=num;
	return num;
}

-(void)writeBytes:(int)num fromBuffer:(const void *)buffer
{
	if(![data isKindOfClass:[NSMutableData class]]) [self _raiseNotSupported];
	NSMutableData *mdata=(NSMutableData *)data;

	if(pos+num>[mdata length]) [mdata setLength:pos+num];
	memcpy((uint8_t *)[mdata mutableBytes]+pos,buffer,num);
	pos+=num;
}

-(id)copyWithZone:(NSZone *)zone;
{
	CSMemoryHandle *copy=[[CSMemoryHandle allocWithZone:zone] initWithData:data];
	[copy seekToFileOffset:pos];
	return copy;
}


-(NSData *)data { return data; }

-(NSMutableData *)mutableData
{
	if(![data isKindOfClass:[NSMutableData class]]) [self _raiseNotSupported];
	return (NSMutableData *)data;
}

@end
