#import "CSStreamHandle.h"

@implementation CSStreamHandle

-(id)initWithName:(NSString *)descname
{
	if(self=[super initWithName:descname])
	{
		streampos=0;
		endofstream=NO;
		needsreset=YES;
		nextstreambyte=-1;
	}
	return self;
}

-(id)initAsCopyOf:(CSStreamHandle *)other
{
	[self _raiseNotSupported:_cmd];
	return nil;
}

-(off_t)offsetInFile { return streampos; }

-(BOOL)atEndOfFile
{
	if(endofstream) return YES;
	if(nextstreambyte>=0) return NO;

	uint8_t b[1];
	if([self streamAtMost:1 toBuffer:b]==1)
	{
		nextstreambyte=b[0];
		return NO;
	}
	else
	{
		endofstream=YES;
		return YES;
	}
}

-(void)seekToFileOffset:(off_t)offs
{
	if(offs==streampos) return;

	if(needsreset) { [self resetStream]; needsreset=NO; }

	if(nextstreambyte>=0)
	{
		nextstreambyte=-1;
		streampos+=1;
		if(offs==streampos) return;
	}

	if(offs<streampos)
	{
		streampos=0;
		endofstream=NO;
		//nextstreambyte=-1;
		[self resetStream];
	}

	if(offs==0) return;

	[self readAndDiscardBytes:offs-streampos];
}

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	if(!num) return 0;
	if(endofstream) return 0;

	if(needsreset) { [self resetStream]; needsreset=NO; }

	int offs=0;
	if(nextstreambyte>=0)
	{
		((uint8_t *)buffer)[0]=nextstreambyte;
		streampos++;
		nextstreambyte=-1;
		offs=1;
	}

	int actual=[self streamAtMost:num-offs toBuffer:((uint8_t *)buffer)+offs];

	if(actual!=num-offs) endofstream=YES;

	streampos+=actual;

	return actual+offs;
}

-(void)endStream
{
	endofstream=YES;
}

-(void)resetStream {}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer { return 0; }

@end
