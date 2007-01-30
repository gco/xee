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
	uint8 *header=(uint8 *)[block bytes];
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
			[iff skipBytes:2];
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
			pixelsize=0;
//			[self setDepthGrey:8 alpha:NO floating:NO];
		break;
		case MAYA_FORMAT_RGB:
			type=XeeBitmapTypeRGB8;
			pixelsize=3;
			[self setDepthRGB:8 alpha:NO floating:NO];
		break;
		case MAYA_FORMAT_ALPHA:
			type=XeeBitmapTypeLuma8;
			pixelsize=1;
			[self setDepthGrey:8 alpha:NO floating:NO];
		break;
		case MAYA_FORMAT_RGBA:
			type=XeeBitmapTypeRGBA8;
			pixelsize=4;
			[self setDepthRGB:8 alpha:YES floating:NO];
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

				if([subiff bytesLeft]>=tile_w*tile_h*pixelsize)
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
		@throw;
	}

	return @selector(loadDataChunk);
}

-(void)readUncompressedAtX:(int)x y:(int)y width:(int)w height:(int)h
{
	uint8 *data=[mainimage data];
	int bprow=[mainimage bytesPerRow];
	for(int i=0;i<h;i++)
	{
		uint8 *ptr=data+(height-y-i-1)*bprow+x*pixelsize;
		[subiff readBytes:w*pixelsize toBuffer:ptr];

		if(pixelsize==3)
		{
			for(int j=0;j<w;j++)
			{
				uint8 b=ptr[0];
				uint8 g=ptr[1];
				uint8 r=ptr[2];
				ptr[0]=r;
				ptr[1]=g;
				ptr[2]=b;
				ptr+=3;
			}
		}
		else if(pixelsize==4)
		{
			for(int j=0;j<w;j++)
			{
				uint8 a=ptr[0];
				uint8 b=ptr[1];
				uint8 g=ptr[2];
				uint8 r=ptr[3];
				ptr[0]=r;
				ptr[1]=g;
				ptr[2]=b;
				ptr[3]=a;
				ptr+=4;
			}
		}
	}
}

-(void)readRLECompressedAtX:(int)x y:(int)y width:(int)w height:(int)h
{
	uint8 *data=[mainimage data];
	int bprow=[mainimage bytesPerRow];

	for(int i=0;i<pixelsize;i++)
	{
		[self readRLECompressedTo:data+(height-y-1)*bprow+x*pixelsize+(pixelsize-i-1)
		num:w*h stride:pixelsize width:w bytesPerRow:bprow];
	}
}

-(void)readRLECompressedTo:(uint8 *)buf num:(int)num stride:(int)stride width:(int)w bytesPerRow:(int)bprow
{
	int x=0;
	uint8 *row=buf;

	for(;;)
	{
		uint8 marker=[subiff readUInt8];
		int count=(marker&0x7f)+1;

		if(marker&0x80)
		{
			uint8 b=[subiff readUInt8];
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
