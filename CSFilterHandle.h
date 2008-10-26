#import "CSHandle.h"
#import "CSCoroutine.h"
#import "XeeTypes.h"



@interface CSFilterHandle:CSHandle
{
	@public
	CSHandle *parent;
	uint8 (*producebyte_ptr)(id,SEL);
	off_t startoffs,pos;
	BOOL eof;

	@public
	uint8 *inbuffer;
	int bufsize,bufbytes,currbyte,currbit;
}

-(id)initWithHandle:(CSHandle *)handle;
-(id)initWithHandle:(CSHandle *)handle bufferSize:(int)buffersize;
-(id)initAsCopyOf:(CSFilterHandle *)other;
-(void)dealloc;

-(off_t)offsetInFile;
-(BOOL)atEndOfFile;
-(void)seekToFileOffset:(off_t)offs;
-(int)readAtMost:(int)num toBuffer:(void *)buffer;

-(void)seekParentToFileOffset:(off_t)offset;

-(void)resetFilter;
-(uint8)produceByte;

@end

static inline void CSFilterEOF() { [NSException raise:@"CSFilterEOFReachedException" format:@""]; }

static inline int CSFilterNextByte(CSFilterHandle *self)
{
	if(self->currbyte>=self->bufbytes)
	{
		self->bufbytes=[self->parent readAtMost:self->bufsize toBuffer:self->inbuffer];
		if(!self->bufbytes) CSFilterEOF();
		self->currbyte=0;
	}
	return self->inbuffer[self->currbyte++];
}

static inline int CSFilterNextBit(CSFilterHandle *self)
{
	if(self->currbyte>=self->bufbytes)
	{
		self->bufbytes=[self->parent readAtMost:self->bufsize toBuffer:self->inbuffer];
		if(!self->bufbytes) CSFilterEOF();
		self->currbyte=0;
	}
	int bit=(self->inbuffer[self->currbyte]>>self->currbit)&1;
	self->currbit--;
	if(self->currbit<0)
	{
		self->currbit=7;
		self->currbyte++;
	}
	return bit;
}



/*
@interface CSFilterHandle:CSHandle
{
	CSHandle *parent;
	int (*readatmost_ptr)(id,SEL,int,void *);
	CSCoroutine *coro;

	off_t pos;
	int left;
	uint8 *ptr;
}

-(id)initWithHandle:(CSHandle *)handle;
-(id)initAsCopyOf:(CSFilterHandle *)other;
-(void)dealloc;

-(off_t)offsetInFile;
//-(BOOL)atEndOfFile;
-(int)readAtMost:(int)num toBuffer:(void *)buffer;

-(void)filter;

@end

#define CSFilterGet() __CSFilterGet(readatmost_ptr,parent,coro)
#define CSFilterPut(b) __CSFilterPut(b,&pos,&left,&ptr,coro)

static uint8 inline __CSFilterGet(int (*readatmost_ptr)(id,SEL,int,void *),CSHandle *parent,CSCoroutine *coro)
{
	uint8 b;
	if(readatmost_ptr(parent,@selector(readAtMost:toBuffer:),1,&b)!=1) [coro returnFrom];
	return b;
}

static void inline __CSFilterPut(uint8 b,off_t *pos,int *left,uint8 **ptr,CSCoroutine *coro)
{
	*(*ptr)++=b;
	(*left)--;
	(*pos)++;
	if(*left==0) [coro returnFrom];
}

*/