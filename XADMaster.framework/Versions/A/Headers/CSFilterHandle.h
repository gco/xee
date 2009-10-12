#import "CSStreamHandle.h"



@interface CSFilterHandle:CSStreamHandle
{
	@public
	CSHandle *parent;
	off_t startoffs;
	uint8_t (*producebyte_ptr)(id,SEL,off_t);

	@public
	uint8_t *filterbuffer;
	int filterbufsize,filterbufbytes,currfilterbyte,currfilterbit;
}

-(id)initWithHandle:(CSHandle *)handle;
-(id)initWithHandle:(CSHandle *)handle bufferSize:(int)buffersize;
-(id)initAsCopyOf:(CSFilterHandle *)other;
-(void)dealloc;

-(void)seekParentToFileOffset:(off_t)offset;

-(int)streamAtMost:(int)num toBuffer:(void *)buffer;
-(void)resetStream;

-(void)resetFilter;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end

extern NSString *CSFilterEOFReachedException;

static inline void CSFilterEOF() { [NSException raise:CSFilterEOFReachedException format:@""]; }

static inline void CSFilterCheckAndFillBuffer(CSFilterHandle *self)
{
	if(self->currfilterbyte>=self->filterbufbytes)
	{
		self->filterbufbytes=[self->parent readAtMost:self->filterbufsize toBuffer:self->filterbuffer];
		if(!self->filterbufbytes) CSFilterEOF();
		self->currfilterbyte=0;
	}
}

static inline int CSFilterPeekByte(CSFilterHandle *self) { return self->filterbuffer[self->currfilterbyte]; }

static inline void CSFilterByteConsumed(CSFilterHandle *self) { self->currfilterbyte++; }

static inline int CSFilterNextByte(CSFilterHandle *self)
{
	CSFilterCheckAndFillBuffer(self);

	int byte=CSFilterPeekByte(self);

	CSFilterByteConsumed(self);

	return byte;
}

static inline int CSFilterNextBit(CSFilterHandle *self)
{
	CSFilterCheckAndFillBuffer(self);

	int bit=(CSFilterPeekByte(self)>>self->currfilterbit)&1;

	self->currfilterbit--;
	if(self->currfilterbit<0)
	{
		self->currfilterbit=7;
		CSFilterByteConsumed(self);
	}

	return bit;
}

static inline int CSFilterNextBitString(CSFilterHandle *self,int bits)
{
	int res=0;

	while(bits)
	{
		CSFilterCheckAndFillBuffer(self);

		int num=bits;
		if(num>self->currfilterbit+1) num=self->currfilterbit+1;
		res=(res<<num)| ((CSFilterPeekByte(self)>>(self->currfilterbit+1-num))&((1<<num)-1));

		bits-=num;
		self->currfilterbit-=num;

		if(self->currfilterbit<0)
		{
			self->currfilterbit=7;
			CSFilterByteConsumed(self);
		}
	}
	return res;
}


/*
@interface CSFilterHandle:CSHandle
{
	CSHandle *parent;
	int (*readatmost_ptr)(id,SEL,int,void *);
	CSCoroutine *coro;

	off_t pos;
	int left;
	uint8_t *ptr;
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

static uint8_t inline __CSFilterGet(int (*readatmost_ptr)(id,SEL,int,void *),CSHandle *parent,CSCoroutine *coro)
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