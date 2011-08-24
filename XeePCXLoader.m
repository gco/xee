#import "XeePCXLoader.h"
#import "XeeTypes.h"



struct pcx_header
{
	uint8 manufacturer; // Constant Flag, 10 = ZSoft .pcx 
	uint8 version; // Version information 
	               // 0 = Version 2.5 of PC Paintbrush 
	               // 2 = Version 2.8 w/palette information 
	               // 3 = Version 2.8 w/o palette information 
	               // 4 = PC Paintbrush for Windows(Plus for
	               //     Windows uses Ver 5) 
	               // 5 = Version 3.0 and > of PC Paintbrush
	               //     and PC Paintbrush +, includes
	               //     Publisher's Paintbrush . Includes
	               //     24-bit .PCX files 
	uint8 encoding; // 1 = .PCX run length encoding 
	uint8 bitsperpixel; // Number of bits to represent a pixel
	                   // (per Plane) - 1, 2, 4, or 8 
	eint16 xmin; // Image Dimensions: Xmin,Ymin,Xmax,Ymax 
	eint16 ymin;
	eint16 xmax;
	eint16 ymax;
	eint16 hdpi; // Horizontal Resolution of image in DPI
	eint16 vdpi; // Vertical Resolution of image in DPI
	uint8 colormap[48]; // Color palette setting, see text 
	uint8 reserved; // Should be set to 0. 
	uint8 nplanes; // Number of color planes 
	eint16 bytesperline; // Number of bytes to allocate for a scanline
	                     // plane.  MUST be an EVEN number.  Do NOT
	                     // calculate from Xmax-Xmin. 
	eint16 paletteinfo; // How to interpret palette- 1 = Color/BW,
	                    // 2 = Grayscale (ignored in PB IV/ IV +) 
	eint16 hscreensize; // Horizontal screen size in pixels. New field
	                    // found only in PB IV/IV Plus 
	eint16 vscreensize; // Vertical screen size in pixels. New field
	                     // found only in PB IV/IV Plus 
	uint8 filler[54]; // Blank to fill out 128 bytes header.  Set all
	                  // bytes to 0 
};



@implementation XeePCXImage

-(SEL)identifyFile
{
	if([header length]<128) return NULL;

	struct pcx_header *pcx=(struct pcx_header *)[header bytes];

	if(pcx->manufacturer!=10) return NULL;
	if(!(pcx->version==0||pcx->version==2||pcx->version==3||pcx->version==4||pcx->version==5)) return NULL;
	if(!((pcx->nplanes==3&&pcx->bitsperpixel==8)||(pcx->nplanes==1&&pcx->bitsperpixel==8)
	   ||(pcx->nplanes==4&&pcx->bitsperpixel==1)||(pcx->nplanes==1&&pcx->bitsperpixel==1))) return NULL;

	width=read_le_uint16(pcx->xmax)-read_le_uint16(pcx->xmin)+1;
	height=read_le_uint16(pcx->ymax)-read_le_uint16(pcx->ymin)+1;

	if(pcx->nplanes==3) [self setDepthRGB:8];
	else [self setDepthIndexed:1<<(pcx->bitsperpixel*pcx->nplanes)];

	int pixelsperline=(8*read_le_uint16(pcx->bytesperline))/pcx->bitsperpixel;
	if(pixelsperline<width) return NULL; // sanity check

	current_line=0;
	[self setFormat:@"PCX"];

	return @selector(startLoading);
}

-(SEL)startLoading
{
	struct pcx_header *pcx=(struct pcx_header *)[header bytes];
	XeeFileHandle *fh=[self fileHandle];

	if(![self allocWithType:XeeBitmapTypeRGB8 width:width height:height]) return NULL;

	if(pcx->version==5&&pcx->bitsperpixel==8&&pcx->nplanes==1)
	{
		[fh seekToEndOfFile];
		[fh skipBytes:-769];

		if([fh readUint8]!=12) return NULL;

		[fh readBytes:768 toBuffer:palette];
	}
	else if(pcx->version==3) // no palette
	{
		uint8 defaultpalette[48]={0,0,0,0,0,170,0,170,0,0,170,170,170,0,0,170,0,170,170,85,0,
		170,85,85,85,85,85,0,0,255,0,255,0,0,255,255,255,0,0,255,0,255,255,255,0,255,255,255};
		memcpy(palette,defaultpalette,48);
	}
	else
	{
		memcpy(palette,pcx->colormap,48);
	}

	[fh seekToFileOffset:128];

	return @selector(load);
}

-(SEL)load
{
	struct pcx_header *pcx=(struct pcx_header *)[header bytes];
	XeeFileHandle *fh=[self fileHandle];

	int bytesperline=read_le_uint16(pcx->bytesperline);
	int totalbytes=pcx->nplanes*bytesperline;
	uint8 line[totalbytes];

	while(!stop)
	{
		int bytesread=0;

		while(bytesread<totalbytes)
		{
			uint8 b=[fh readUint8];
			if(b<192) line[bytesread++]=b;
			else
			{
				uint8 c=[fh readUint8];
				int count=b-192;
				if(bytesread+count>totalbytes) count=totalbytes-bytesread;
				while(count--) line[bytesread++]=c;
			}
		}

		uint8 *imagerow=data+current_line*bytesperrow;

		if(pcx->nplanes==3&&pcx->bitsperpixel==8)
		{
			for(int i=0;i<width;i++)
			{
				*imagerow++=line[i];
				*imagerow++=line[i+bytesperline];
				*imagerow++=line[i+bytesperline*2];
			}
		}
		else if(pcx->nplanes==1&&pcx->bitsperpixel==8)
		{
			for(int i=0;i<width;i++)
			{
				uint8 *paletteentry=palette+line[i]*3;
				*imagerow++=*paletteentry++;
				*imagerow++=*paletteentry++;
				*imagerow++=*paletteentry++;
			}
		}
		else if(pcx->nplanes==4&&pcx->bitsperpixel==1)
		{
			for(int i=0;i<width;i++)
			{
				int col=0;
				col|=((line[(i>>3)+bytesperline*0]>>((i&7)^7))&1)<<0;
				col|=((line[(i>>3)+bytesperline*1]>>((i&7)^7))&1)<<1;
				col|=((line[(i>>3)+bytesperline*2]>>((i&7)^7))&1)<<2;
				col|=((line[(i>>3)+bytesperline*3]>>((i&7)^7))&1)<<3;
				uint8 *paletteentry=palette+col*3;
				*imagerow++=*paletteentry++;
				*imagerow++=*paletteentry++;
				*imagerow++=*paletteentry++;
			}
		}
		else if(pcx->nplanes==1&&pcx->bitsperpixel==1)
		{
			for(int i=0;i<width;i++)
			{
				int col=(line[i>>3]>>((i&7)^7))&1;
				uint8 *paletteentry=palette+col*3;
				*imagerow++=*paletteentry++;
				*imagerow++=*paletteentry++;
				*imagerow++=*paletteentry++;
			}
		}

		current_line++;
		[self setCompletedRowCount:current_line];

		if(current_line>=height)
		{
			success=YES;
			return NULL;
		}
	}

	return @selector(load);
}

+(NSArray *)fileTypes
{
	return [NSArray arrayWithObjects:@"pcx",@"'PCX '",@"'PCXf'",nil];
}

@end

