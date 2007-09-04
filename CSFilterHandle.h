#import "CSHandle.h"
#import "CSCoroutine.h"
#import "XeeTypes.h"

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
-(void)dealloc;

-(off_t)offsetInFile;
//-(BOOL)atEndOfFile;
-(int)readAtMost:(int)num toBuffer:(void *)buffer;

-(void)filter;

@end

#define CSFilterGet() __CSFilterGet(readatmost_ptr,parent)
#define CSFilterPut(b) __CSFilterPut(b,&pos,&left,&ptr,coro)

static uint8 inline __CSFilterGet(int (*readatmost_ptr)(id,SEL,int,void *),CSHandle *parent)
{
	uint8 b;
	readatmost_ptr(parent,@selector(readAtMost:toBuffer:),1,&b);
	return b;
}

static void inline __CSFilterPut(uint8 b,off_t *pos,int *left,uint8 **ptr,CSCoroutine *coro)
{
	*(*ptr)++=b;
	(*left)--;
	(*pos)++;
	if(*left==0) [coro returnFrom];
}

