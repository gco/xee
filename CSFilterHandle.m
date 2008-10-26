#import "CSFilterHandle.h"


@implementation CSFilterHandle

-(id)initWithHandle:(CSHandle *)handle
{
	return [self initWithHandle:handle bufferSize:4096];
}

-(id)initWithHandle:(CSHandle *)handle bufferSize:(int)buffersize
{
	if(self=[super initWithName:[handle name]])
	{
		parent=[handle retain];
		startoffs=[handle offsetInFile];

		producebyte_ptr=(uint8 (*)(id,SEL))[self methodForSelector:@selector(produceByte)];
		pos=0;
		eof=NO;

		inbuffer=malloc(buffersize);
		bufsize=buffersize;
		bufbytes=0;
		currbyte=0;
		currbit=7;

		[self resetFilter];
	}
	return self;
}

-(id)initAsCopyOf:(CSFilterHandle *)other
{
	[self _raiseNotSupported:_cmd];
	return nil;
}

-(void)dealloc
{
	[parent release];
	free(inbuffer);
	[super dealloc];
}

-(off_t)offsetInFile { return pos; }

-(BOOL)atEndOfFile { return eof||[parent atEndOfFile]; }

-(void)seekToFileOffset:(off_t)offs
{
	if(offs==pos) return;

	if(offs<pos)
	{
		[self seekParentToFileOffset:startoffs];
		[self resetFilter];
		pos=0;
		eof=NO;
	}

	if(offs==0) return;

	[self readAndDiscardBytes:offs];
}

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	if(eof) return 0;

	int n=0;

	@try
	{
		while(n<num)
		{
			uint8 byte=producebyte_ptr(self,@selector(produceByte));
			((uint8 *)buffer)[n++]=byte;
			pos++;
		}
	}
	@catch(id e)
	{
		if(![e isKindOfClass:[NSException class]]||![[e name] isEqual:@"CSFilterEOFReachedException"])
		@throw e;
		eof=YES;
	}

	return n;
}

-(void)seekParentToFileOffset:(off_t)offset
{
	[parent seekToFileOffset:offset];
	currbyte=bufbytes=0;
	currbit=7;
}

-(void)resetFilter {}

-(uint8)produceByte { return -1; }

@end





/*
@implementation CSFilterHandle

-(id)initWithHandle:(CSHandle *)handle
{
	if(self=[super initWithName:[handle name]])
	{
		parent=[handle retain];
		readatmost_ptr=(int (*)(id,SEL,int,void *))[parent methodForSelector:@selector(readAtMost:toBuffer:)];

		pos=0;

		coro=nil;
		// start couroutine which returns control immediately
	}
	return self;
}

-(id)initAsCopyOf:(CSFilterHandle *)other
{
	parent=nil; coro=nil; [self release];
	[self _raiseNotImplemented:_cmd];
	return nil;
}

-(void)dealloc
{
	[parent release];
	[coro release];
	[super dealloc];
}

-(off_t)offsetInFile { return pos; }

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	if(!num) return 0;

	ptr=buffer;
	left=num;

	if(!coro)
	{
		coro=[self newCoroutine];
		[(id)coro filter];
	} else [coro switchTo];

	//if(eof)...

	return num-left;
}

-(void)filter {}

@end

*/