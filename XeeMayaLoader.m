#import "XeeMayaLoader.h"
#import "XeeBitmapImage.h"
#import "XeeIFFHandle.h"

#define MAYA_RGB 1
#define MAYA_ALPHA 2
#define MAYA_ZBUFFER 4

#define MAYA_FORMAT_MASK (MAYA_RGB|MAYA_ALPHA)

#define MAYA_FORMAT_NOTHING 0
#define MAYA_FORMAT_RGB (MAYA_RGB)
#define MAYA_FORMAT_ALPHA (MAYA_ALPHA)
#define MAYA_FORMAT_RGBA (MAYA_RGB|MAYA_ALPHA)

@implementation XeeMayaImage

+(id)fileTypes
{
	return [NSArray arrayWithObjects:@"iff",nil];
}

+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes
{
	uint8_t *header=(uint8_t *)[block bytes];
	if([block length]>12
	&&(XeeBEUInt32(header)=='FORM'||XeeBEUInt32(header)=='FOR4'||XeeBEUInt32(header)=='FOR8')
	&&XeeBEUInt32(header+8)=='CIMG') return YES;
	return NO;
}

-(SEL)initLoader
{
	subiff=nil;
	mainimage=nil;
	zbufimage=nil;

	iff=[[XeeIFFHandle IFFHandleWithPath:[self filename] fileType:'CIMG'] retain];
	if(!iff) return NULL;

	[self setFormat:@"Maya IFF"];

	return @selector(loadChunk);
}

-(void)deallocLoader
{
	[iff release];
	[subiff release];
}

-(SEL)loadChunk
{
	switch([iff nextChunk])
	{
		case 'TBHD':
			width=[iff readUInt32];
			height=[iff readUInt32];
			[iff skipBytes:4];
			flags=[iff readUInt32];
			switch([iff readUInt16])
			{
				case 0: bytedepth=1; break;
				case 1: bytedepth=2; break;
				case 3: bytedepth=4; break;
				default: return NULL;
			}
			tiles=[iff readUInt16];
			compression=[iff readUInt32];
		break;

		case 'FORM':
		case 'FOR4':
		case 'FOR8':
			if([iff readID]=='TBMP')
			{
				subiff=[[iff IFFHandleForChunk] retain];
				return @selector(startLoadingData);
			}
		break;

		case 0:
			return NULL;
	}

	return @selector(loadChunk);
}

-(SEL)startLoadingData
{
	int type;

	switch(flags&MAYA_FORMAT_MASK)
	{
		case MAYA_FORMAT_NOTHING:
			type=0;
			numchannels=0;
		break;
		case MAYA_FORMAT_RGB:
			type=XeeBitmapType(XeeRGBBitmap,8*bytedepth,XeeAlphaNone,bytedepth==4?XeeBitmapFloatingPointFlag:0);
			numchannels=3;
			[self setDepthRGB:8*bytedepth alpha:NO floating:bytedepth==4];
		break;
		case MAYA_FORMAT_ALPHA:
			type=XeeBitmapType(XeeGreyBitmap,8*bytedepth,XeeAlphaNone,bytedepth==4?XeeBitmapFloatingPointFlag:0);
			numchannels=1;
			[self setDepthGrey:8*bytedepth alpha:NO floating:bytedepth==4];
		break;
		case MAYA_FORMAT_RGBA:
			type=XeeBitmapType(XeeRGBBitmap,8*bytedepth,XeeAlphaLast,bytedepth==4?XeeBitmapFloatingPointFlag:0);
			numchannels=4;
			[self setDepthRGB:8*bytedepth alpha:YES floating:bytedepth==4];
		break;
	}

	if(type)
	{
		mainimage=[[[XeeBitmapImage alloc] initWithType:type width:width height:height] autorelease];
		if(!mainimage) return NULL;

		[mainimage setDepth:[self depth]];
		[mainimage setDepthIcon:[self depthIcon]];
		[self addSubImage:mainimage];
	}

	rgbatiles=zbuftiles=0;

	return @selector(loadDataChunk);
}

-(SEL)loadDataChunk
{
	int x1,y1,x2,y2,tile_w,tile_h;

	@try
	{
		switch([subiff nextChunk])
		{
			case 'RGBA':
				if(!mainimage) break;

				rgbatiles++;

				x1=[subiff readUInt16];
				y1=[subiff readUInt16];
				x2=[subiff readUInt16];
				y2=[subiff readUInt16];
				tile_w=x2-x1+1;
				tile_h=y2-y1+1;

//NSLog(@"%d %d %@",[subiff bytesLeft],tile_w*tile_h*numchannels,[self filename]);

				if([subiff bytesLeft]>=tile_w*tile_h*numchannels*bytedepth)
				{
					[self readUncompressedAtX:x1 y:y1 width:tile_w height:tile_h];
				}
				else
				{
					[self readRLECompressedAtX:x1 y:y1 width:tile_w height:tile_h];
				}
			break;

			case 'ZBUF':
				zbuftiles++;
			break;

			case 0:
				[mainimage setCompleted];
				[zbufimage setCompleted];

				if(mainimage&&rgbatiles!=tiles) return NULL;
				if(zbufimage&&zbuftiles!=tiles) return NULL;

				loaded=YES;

				return NULL;
		}
	}
	@catch(id e)
	{
		[mainimage setCompleted];
		[zbufimage setCompleted];
		@throw e;
	}

	return @selector(loadDataChunk);
}

-(void)readUncompressedAtX:(int)x y:(int)y width:(int)w height:(int)h
{
/*	uint8_t *data=[mainimage data];
	int bprow=[mainimage bytesPerRow];
	for(int i=0;i<h;i++)
	{
		uint8_t *ptr=data+(height-y-i-1)*bprow+x*numchannels;
		[subiff readBytes:w*numchannels toBuffer:ptr];

		if(numchannels==3)
		{
			for(int j=0;j<w;j++)
			{
				uint8_t b=ptr[0];
				uint8_t g=ptr[1];
				uint8_t r=ptr[2];
				ptr[0]=r;
				ptr[1]=g;
				ptr[2]=b;
				ptr+=3;
			}
		}
		else if(numchannels==4)
		{
			for(int j=0;j<w;j++)
			{
				uint8_t a=ptr[0];
				uint8_t b=ptr[1];
				uint8_t g=ptr[2];
				uint8_t r=ptr[3];
				ptr[0]=r;
				ptr[1]=g;
				ptr[2]=b;
				ptr[3]=a;
				ptr+=4;
			}
		}
	}*/

	uint8_t *data=[mainimage data];
	int bprow=[mainimage bytesPerRow];

	int bytesperpixel=numchannels*bytedepth;

	for(int dy=0;dy<h;dy++)
	{
		uint8_t *ptr=data+(height-y-dy-1)*bprow+x*bytesperpixel;
		for(int dx=0;dx<w;dx++)
		{
			for(int i=0;i<numchannels;i++)
			for(int j=0;j<bytedepth;j++)
			{
				#ifdef __BIG_ENDIAN__
				ptr[(numchannels-i-1)*bytedepth+j]=[subiff readUInt8];
				#else
				ptr[(numchannels-i-1)*bytedepth+bytedepth-j-1]=[subiff readUInt8];
				#endif
			}
			ptr+=bytesperpixel;
		}
	}
}

-(void)readRLECompressedAtX:(int)x y:(int)y width:(int)w height:(int)h
{
	uint8_t *data=[mainimage data];
	int bprow=[mainimage bytesPerRow];

	int bytesperpixel=numchannels*bytedepth;

	for(int j=0;j<bytedepth;j++)
	for(int i=0;i<numchannels;i++)
	{
		#ifdef __BIG_ENDIAN__
		[self readRLECompressedTo:data+(height-y-1)*bprow+x*bytesperpixel+(numchannels-i-1)*bytedepth+j
		num:w*h stride:bytesperpixel width:w bytesPerRow:bprow];
		#else
		[self readRLECompressedTo:data+(height-y-1)*bprow+x*bytesperpixel+(numchannels-i-1)*bytedepth+bytedepth-j-1
		num:w*h stride:bytesperpixel width:w bytesPerRow:bprow];
		#endif
	}
}

-(void)readRLECompressedTo:(uint8_t *)buf num:(int)num stride:(int)stride width:(int)w bytesPerRow:(int)bprow
{
	int x=0;
	uint8_t *row=buf;

	for(;;)
	{
		uint8_t marker=[subiff readUInt8];
		int count=(marker&0x7f)+1;

		if(marker&0x80)
		{
			uint8_t b=[subiff readUInt8];
			for(int i=0;i<count;i++)
			{
				if(x>=w)
				{
					x=0;
					row-=bprow;
				}
				row[(x++)*stride]=b;
				if(!--num) return;
			}
		}
		else
		{
			for(int i=0;i<count;i++)
			{
				if(x>=w)
				{
					x=0;
					row-=bprow;
				}
				row[(x++)*stride]=[subiff readUInt8];
				if(!--num) return;
			}
		}
	}
}

@end
