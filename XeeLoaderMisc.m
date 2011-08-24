#import "XeeLoaderMisc.h"
#import "XeeFileHandle.h"


#define RLE_IMPL(readbytecode,copytest,copysize,repeattest,repeatsize,destsize,stride) \
	int total=0; \
	while(total<destsize) \
	{ \
		uint8 marker=(readbytecode); \
		if(copytest) \
		{ \
			int count=(copysize); \
			if(total+count>destsize) count=destsize-total; \
			total+=count; \
			while(count--) { *dest=(readbytecode); dest+=(stride); } \
		} \
		else if(repeattest) \
		{ \
			uint8 val=(readbytecode); \
			int count=(repeatsize); \
			if(total+count>destsize) count=destsize-total; \
			total+=count; \
			for(int i=0;i<count;i++) { *dest=val; dest+=(stride); } \
		} \
	}

#define XeePackBitsNextByte(ptr,count) ({ \
	if((count)==0) return; \
	(count)--; \
	*(ptr)++; \
})

void XeeUnPackBitsFromMemory(uint8 *src,uint8 *dest,int srcsize,int destsize,int stride)
{
	RLE_IMPL(XeePackBitsNextByte(src,srcsize),
	marker<128,marker+1,
	marker>128,257-marker,
	destsize,stride)
}

void XeeUnPackBitsFromFile(XeeFileHandle *fh,uint8 *dest,int destsize,int stride)
{
	RLE_IMPL([fh readUint8],
	marker<128,marker+1,
	marker>128,257-marker,
	destsize,stride)
}

NSString *XeeNSStringFromByteBuffer(void *buffer,int len)
{
	// Should use UniversalDetector!
	return [[[NSString alloc] initWithBytes:buffer length:len encoding:NSISOLatin1StringEncoding] autorelease];
}

/*	int total=0;

	while(total<destsize)
	{
		uint8 marker=XeePackBitsNextByte(src,srcsize);

		if(marker<128)
		{
			int count=marker+1;
			if(total+count>destsize) count=destsize-total;
			total+=count;

			while(count--) { *dest=XeePackBitsNextByte(src,srcsize); dest+=stride; }
		}
		else if(marker>128)
		{
			uint8 val=XeePackBitsNextByte(src,srcsize);
			int count=257-marker;
			if(total+count>destsize) count=destsize-total;
			total+=count;

			for(int i=0;i<count;i++) { *dest=val; dest++; }
		}
	}
}

void XeeUnPackBitsFromFile(XeeFileHandle *fh,uint8 *dest,int destsize,int stride)
{
	int total=0;

	while(total<destsize)
	{
		uint8 marker=[fh readUint8];

		if(marker<128)
		{
			int count=marker+1;
			if(total+count>destsize) count=destsize-total;
			total+=count;

			while(count--) { *dest=[fh readUint8]; dest+=stride; }
		}
		else if(marker>128)
		{
			uint8 val=[fh readUint8];
			int count=257-marker;
			if(total+count>destsize) count=destsize-total;
			total+=count;

			for(int i=0;i<count;i++) { *dest=val; dest++; }
		}
	}
}*/
