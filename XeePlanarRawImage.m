#import "XeePlanarRawImage.h"


@implementation XeePlanarRawImage

-(id)initWithHandles:(NSArray *)handlearray type:(int)bitmaptype width:(int)framewidth height:(int)frameheight depth:(int)framedepth bigEndian:(BOOL)bigendian preComposed:(BOOL)precomposed
{
	if(self=[super init])
	{
		handles=[handlearray retain];
		type=bitmaptype;
		width=framewidth;
		height=frameheight;
		bitdepth=framedepth;
		big=bigendian;
		precomp=precomposed;

		buffer=NULL;

		int requiredchannels;
		if(XeeBitmapMode(type)==XeeRGBBitmap) requiredchannels=3;
		else requiredchannels=1;

		if(XeeBitmapAlpha(type)==XeeAlphaFirst||XeeBitmapAlpha(type)==XeeAlphaLast||
		XeeBitmapAlpha(type)==XeeAlphaPremultipliedFirst||XeeBitmapAlpha(type)==XeeAlphaPremultipliedLast)
		requiredchannels++;
		else precomp=NO; // sanity correction

		if([handles count]==requiredchannels)
		{
			return self;
		}
		[self release];
	}
	return nil;
}

-(void)dealloc
{
	free(buffer);
	[handles release];
	[super dealloc];
}

-(SEL)initLoader
{
	if(![self allocWithType:type width:width height:height]) return NULL;

	int channels=[handles count];
	int bytesperchannelrow=bitdepth*width/8;
	buffer=malloc(bytesperchannelrow*channels);
	if(!buffer) return NULL;

	row=0;

	return @selector(load);
}

-(void)deallocLoader
{
	[handles release];
	handles=nil;
	free(buffer);
	buffer=NULL;
}

-(SEL)load
{
	int bytesperchannelrow=bitdepth*width/8;

	while(!stop)
	{
		int channels=[handles count];
		for(int i=0;i<channels;i++)
		[[handles objectAtIndex:i] readBytes:bytesperchannelrow toBuffer:&buffer[i*bytesperchannelrow]];

		if(bitdepth==8)
		{
			uint8 *rowptr=data+row*bytesperrow;
			for(int x=0;x<width;x++)
			for(int i=0;i<channels;i++)
			*rowptr++=buffer[x+i*bytesperchannelrow];

			if(precomp)
			{
				uint8 *rowptr=data+row*bytesperrow;
				for(int x=0;x<width;x++)
				{
					if(rowptr[channels-1])
					for(int i=0;i<channels-1;i++) rowptr[i]=((rowptr[i]-255+rowptr[channels-1])*255)/rowptr[channels-1];
					rowptr+=channels;
				}
			}
		}
		else if(bitdepth==16)
		{
			uint16 *rowptr=(uint16 *)(data+row*bytesperrow);
			if(big)
			for(int x=0;x<width;x++)
			for(int i=0;i<channels;i++)
			*rowptr++=XeeBEUInt16(&buffer[2*x+i*bytesperchannelrow]);
			else
			for(int x=0;x<width;x++)
			for(int i=0;i<channels;i++)
			*rowptr++=XeeLEUInt16(&buffer[2*x+i*bytesperchannelrow]);

			if(precomp)
			{
				uint16 *rowptr=(uint16 *)(data+row*bytesperrow);
				for(int x=0;x<width;x++)
				{
					if(rowptr[channels-1])
					for(int i=0;i<channels-1;i++) rowptr[i]=((uint32)(rowptr[i]-65535+rowptr[channels-1])*65535)/rowptr[channels-1];
					rowptr+=channels;
				}
			}
		}
		else if(bitdepth==32)
		{
			uint32 *rowptr=(uint32 *)(data+row*bytesperrow);
			if(big)
			for(int x=0;x<width;x++)
			for(int i=0;i<channels;i++)
			*rowptr++=XeeBEUInt32(&buffer[4*x+i*bytesperchannelrow]);
			else
			for(int x=0;x<width;x++)
			for(int i=0;i<channels;i++)
			*rowptr++=XeeLEUInt32(&buffer[4*x+i*bytesperchannelrow]);
		}

		row++;
		[self setCompletedRowCount:row];
		if(row>=height)
		{
			loaded=YES;
			return NULL;
		}
	}
	return @selector(load);
}

@end
