#import "CSZlibHandle.h"




@implementation CSZlibHandle


+(CSZlibHandle *)zlibHandleWithHandle:(CSHandle *)handle
{
	return [[[CSZlibHandle alloc] initWithHandle:handle name:[handle name]] autorelease];
}

/*+(CSFileHandle *)fileHandleWithPath:(NSString *)path
{
	if(!path) return nil;

	FILE *fh=fopen([path fileSystemRepresentation],"rb");
	CSFileHandle *handle=[[[CSFileHandle alloc] initWithFilePointer:fh closeOnDealloc:YES description:path] autorelease];
	if(handle) return handle;

	fclose(fh);
	return nil;
}*/



-(id)initWithHandle:(CSHandle *)handle name:(NSString *)descname
{
	if(self=[super initWithName:descname])
	{
		fh=[handle retain];
		startoffs=[fh offsetInFile];
		inited=eof=NO;

		zs.zalloc=Z_NULL;
		zs.zfree=Z_NULL;
		zs.opaque=Z_NULL;
		zs.avail_in=0;
		zs.next_in=Z_NULL;

		if(inflateInit(&zs)==Z_OK)
		{
			inited=YES;
			return self;
		}

		[self release];
	}
	return nil;
}

-(id)initAsCopyOf:(CSZlibHandle *)other
{
	if(self=[super initWithName:[[other name] stringByAppendingString:@" (copy)"]])
	{
		fh=[other->fh copy];
		startoffs=other->startoffs;
		inited=NO;
		eof=other->eof;

		if(inflateCopy(&zs,&other->zs)==Z_OK)
		{
			zs.next_in=inbuffer;
			memcpy(inbuffer,other->zs.next_in,zs.avail_in);

			inited=YES;
			return self;
		}

		[self release];
	}
	return nil;
}

-(void)dealloc
{
	if(inited) inflateEnd(&zs);
	[fh release];

	[super dealloc];
}



-(off_t)offsetInFile
{
	return zs.total_out;
}

-(BOOL)atEndOfFile { return eof; }



-(void)seekToFileOffset:(off_t)offs
{
	if(offs<zs.total_out)
	{
		if(zs.total_out==0) return;

		zs.avail_in=0;
		zs.next_in=Z_NULL;
		if(inflateReset(&zs)!=Z_OK) [self _raiseZlib];
		[fh seekToFileOffset:startoffs];
	}

	int skip=offs-zs.total_out;
	uint8_t dummybuf[16384];
	while(skip)
	{
		int num=sizeof(dummybuf);
		if(num>skip) num=skip;
		skip-=[self readAtMost:num toBuffer:dummybuf];
	}
}

-(void)seekToEndOfFile
{
	@try
	{
		[self seekToFileOffset:0x7fffffff];
	}
	@catch(NSException *e)
	{
		if([[e name] isEqual:@"CSEndOfFileException"]) return;
		@throw e;
	}
}

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	if(eof) return 0;

	zs.next_out=buffer;
	zs.avail_out=num;

	while(zs.avail_out)
	{
		if(!zs.avail_in)
		{
			if([fh atEndOfFile]) { eof=YES; break; }
			zs.avail_in=[fh readAtMost:sizeof(inbuffer) toBuffer:inbuffer];
			zs.next_in=inbuffer;
		}

		int err=inflate(&zs,0);
		if(err==Z_STREAM_END) { eof=YES; break; }
		else if(err!=Z_OK) [self _raiseZlib];
	}

	return num-zs.avail_out;
}

-(id)copyWithZone:(NSZone *)zone
{
	return [[CSZlibHandle allocWithZone:zone] initAsCopyOf:self];
}



-(void)_raiseZlib
{
	[NSException raise:@"CSZlibException"
	format:@"Zlib error while attepting to read from \"%@\": %s.",name,zs.msg];
}

@end
