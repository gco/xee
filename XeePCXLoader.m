#import "XeePCXLoader.h"



struct pcx_header
{
	uint8_t manufacturer; // Constant Flag, 10 = ZSoft .pcx 
	uint8_t version; // Version information 
	               // 0 = Version 2.5 of PC Paintbrush 
	               // 2 = Version 2.8 w/palette information 
	               // 3 = Version 2.8 w/o palette information 
	               // 4 = PC Paintbrush for Windows(Plus for
	               //     Windows uses Ver 5) 
	               // 5 = Version 3.0 and > of PC Paintbrush
	               //     and PC Paintbrush +, includes
	               //     Publisher's Paintbrush . Includes
	               //     24-bit .PCX files 
	uint8_t encoding; // 1 = .PCX run length encoding 
	uint8_t bitsperpixel; // Number of bits to represent a pixel
	                   // (per Plane) - 1, 2, 4, or 8 
	eint16 xmin; // Image Dimensions: Xmin,Ymin,Xmax,Ymax 
	eint16 ymin;
	eint16 xmax;
	eint16 ymax;
	eint16 hdpi; // Horizontal Resolution of image in DPI
	eint16 vdpi; // Vertical Resolution of image in DPI
	uint8_t colormap[48]; // Color palette setting, see text 
	uint8_t reserved; // Should be set to 0. 
	uint8_t nplanes; // Number of color planes 
	eint16 bytesperline; // Number of bytes to allocate for a scanline
	                     // plane.  MUST be an EVEN number.  Do NOT
	                     // calculate from Xmax-Xmin. 
	eint16 paletteinfo; // How to interpret palette- 1 = Color/BW,
	                    // 2 = Grayscale (ignored in PB IV/ IV +) 
	eint16 hscreensize; // Horizontal screen size in pixels. New field
	                    // found only in PB IV/IV Plus 
	eint16 vscreensize; // Vertical screen size in pixels. New field
	                    // found only in PB IV/IV Plus 
	uint8_t filler[54]; // Blank to fill out 128 uint8_t header.  Set all
	                  // bytes to 0 
};



@implementation XeePCXImage


+(NSArray *)fileTypes
{
	return [NSArray arrayWithObjects:@"pcx",@"'PCX '",@"'PCXf'",nil];
}

+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes
{
	if([block length]>128)
	{
		struct pcx_header *pcx=(struct pcx_header *)[block bytes];

		if(pcx->manufacturer==10
		&&(pcx->version==0||pcx->version==2||pcx->version==3||pcx->version==4||pcx->version==5)
		&&((pcx->nplanes==3&&pcx->bitsperpixel==8)||(pcx->nplanes==1||pcx->bitsperpixel==8)
		  ||(pcx->nplanes==4||pcx->bitsperpixel==1)||(pcx->nplanes==1||pcx->bitsperpixel==1))) return YES;
	}

	return NO;
}

-(SEL)initLoader
{
	CSHandle *fh=[self handle];

	header=[[fh readDataOfLength:128] retain];
	struct pcx_header *pcx=(struct pcx_header *)[header bytes];

	width=XeeLEUInt16(pcx->xmax)-XeeLEUInt16(pcx->xmin)+1;
	height=XeeLEUInt16(pcx->ymax)-XeeLEUInt16(pcx->ymin)+1;

	if(pcx->nplanes==3) [self setDepthRGB:24];
	else [self setDepthIndexed:1<<(pcx->bitsperpixel*pcx->nplanes)];

	int pixelsperline=(8*XeeLEUInt16(pcx->bytesperline))/pcx->bitsperpixel;

	if(pixelsperline<width) return NULL; // sanity check

	[self setFormat:@"PCX"];

	current_line=0;

	return @selector(startLoading);
}

-(void)deallocLoader
{
	[header release];
}

-(SEL)startLoading
{
	CSHandle *fh=[self handle];
	struct pcx_header *pcx=(struct pcx_header *)[header bytes];

	if(![self allocWithType:XeeBitmapTypeRGB8 width:width height:height]) return NULL;

	if(pcx->version==5&&pcx->bitsperpixel==8)
	{
		[fh seekToEndOfFile];
		[fh skipBytes:-769];

		if([fh readUInt8]!=12) return NULL;
		[fh readBytes:768 toBuffer:palette];

		[fh seekToFileOffset:128];
	}
	else if(pcx->version==3) // no palette
	{
		uint8_t defaultpalette[48]={0,0,0,0,0,170,0,170,0,0,170,170,170,0,0,170,0,170,170,85,0,
		170,85,85,85,85,85,0,0,255,0,255,0,0,255,255,255,0,0,255,0,255,255,255,0,255,255,255};
		memcpy(defaultpalette,pcx->colormap,48);
	}
	else
	{
		memcpy(palette,pcx->colormap,48);
	}

	return @selector(loadImage);
}

-(SEL)loadImage
{
	CSHandle *fh=[self handle];
	struct pcx_header *pcx=(struct pcx_header *)[header bytes];

	int bytesperline=XeeLEUInt16(pcx->bytesperline);
	int totalbytes=pcx->nplanes*bytesperline;
	uint8_t line[totalbytes];
	int bytesread=0;

	while(bytesread<totalbytes)
	{
		uint8_t b=[fh readUInt8];
		if(b<192) line[bytesread++]=b;
		else
		{
			uint8_t c=[fh readUInt8];
			int count=b-192;
			if(bytesread+count>totalbytes) count=totalbytes-bytesread;
			while(count--) line[bytesread++]=c;
		}
	}

	uint8_t *imagerow=data+current_line*bytesperrow;

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
			uint8_t *paletteentry=palette+line[i]*3;
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
			uint8_t *paletteentry=palette+col*3;
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
			uint8_t *paletteentry=palette+col*3;
			*imagerow++=*paletteentry++;
			*imagerow++=*paletteentry++;
			*imagerow++=*paletteentry++;
		}
	}

	current_line++;
	[self setCompletedRowCount:current_line];
	if(current_line>=height)
	{
		loaded=YES;
		return NULL;
	}
	return @selector(loadImage);
}


@end

