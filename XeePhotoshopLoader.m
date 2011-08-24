#import "XeePhotoshopLoader.h"
#import "XeeLoaderMisc.h"


struct psd_header
{
	eint32 signature;
	eint16 version;
	uint8 reserved[6];
	eint16 channels;
	eint32 rows;
	eint32 columns;
	eint16 depth;
	eint16 mode;
};

#define PSDMODE_BITMAP 0
#define PSDMODE_GREYSCALE 1
#define PSDMODE_INDEXED 2
#define PSDMODE_RGB 3
#define PSDMODE_CMYK 4
#define PSDMODE_MULTICHANNEL 7
#define PSDMODE_DUOTONE 8
#define PSDMODE_LAB 9



@implementation XeePhotoshopImage

-(SEL)identifyFile
{
	mainimage=nil;
	palette=NULL;
	palsize=0;

	const struct psd_header *head=[header bytes];

	if([header length]<sizeof(struct psd_header)
	||read_be_uint32(head->signature)!='8BPS'
	||read_be_uint16(head->version)!=1) return NULL;

	width=read_be_uint32(head->columns);
	height=read_be_uint32(head->rows);

NSLog(@"psd: width:%d height:%d channels:%d depth:%d mode:%d",width,height,
read_be_uint16(head->channels),read_be_uint16(head->depth),read_be_uint16(head->mode));

	[self setFormat:@"PSD"];

	return @selector(startLoading);
}

-(void)deallocLoader
{
	free(palette);
	[super deallocLoader];
}

-(SEL)startLoading
{
	const struct psd_header *head=[header bytes];

	XeeFileHandle *fh=[self fileHandle];

	[fh skipBytes:sizeof(struct psd_header)];

	uint32 pallength=[fh readUint32BE];

	if(read_be_uint16(head->mode)==PSDMODE_INDEXED)
	{
		palette=malloc(pallength);
		if(!palette) return NULL;
		[fh readBytes:pallength toBuffer:palette];
		palsize=pallength/3;
	}
	else [fh skipBytes:pallength];

	uint32 reslength=[fh readUint32BE];
	off_t resend=[fh offsetInFile]+reslength;

	BOOL hasmain=YES;
	int alphachannel=-1;
	actualcolours=-1;
	transparentindex=0;

	while([fh offsetInFile]<resend)
	{
		uint32 type=[fh readUint32BE];
		if(type!='8BIM') break;
		uint16 resid=[fh readUint16BE];
		NSLog(@"resid:%04x",resid);
		uint8 namelen=[fh readUint8];
		[fh skipBytes:namelen|1];
		uint32 reslen=[fh readUint32BE];
		off_t nextres=[fh offsetInFile]+((reslen+1)&~1);

		switch(resid)
		{
			case 0x0421:
				[fh skipBytes:4];
				hasmain=[fh readUint8]?YES:NO;
			break;

			case 0x0416:
				actualcolours=[fh readUint16BE];
			break;

			case 0x0417:
				transparentindex=[fh readUint16BE];
			break;

			case 0x041d:
			{
				int count=reslen/4;
				for(int i=0;i<count;i++)
				{
					uint32 val=[fh readUint32BE];
					if(val==0) alphachannel=i;
				}
			}

			case 0x1033: // BGR thumbnail
			case 0x1036: // RGB thumbnail
			break;
		}

		[fh seekToFileOffset:nextres];
	}

	[fh seekToFileOffset:resend];

	uint32 layerlength=[fh readUint32BE];
	off_t pixeloffs=[fh offsetInFile]+layerlength;

	off_t layerstart;
	int layercount=0;

	if(layerlength>0)
	{
		[fh skipBytes:4];

		layercount=[fh readInt16BE];
		if(layercount<0) { layercount=-layercount; alphachannel=0; }

		layerstart=[fh offsetInFile];

		for(int i=0;i<layercount;i++)
		{
			[fh skipBytes:16];
			uint16 channels=[fh readUint16BE];
			[fh skipBytes:6*channels+12];
			uint32 extrasize=[fh readUint32BE];
			[fh skipBytes:extrasize];
		}
	}
	off_t layerchannelstart=[fh offsetInFile];

	int colorchannels=0;
	switch(read_be_uint16(head->mode))
	{
		case PSDMODE_BITMAP: colorchannels=1; break;
		case PSDMODE_INDEXED: colorchannels=1; break;
		case PSDMODE_GREYSCALE: colorchannels=1; break;
		case PSDMODE_RGB: colorchannels=3; break;
		case PSDMODE_CMYK: colorchannels=4; break;
		case PSDMODE_DUOTONE: colorchannels=1; break;
		case PSDMODE_LAB: colorchannels=3; break;
	}

	int numchannels=read_be_uint16(head->channels);
	if(numchannels<colorchannels) return NULL;

	if(hasmain)
	{
		NSMutableArray *channelarray=[NSMutableArray array];
		off_t datasize=0;
		for(int i=0;i<colorchannels;i++)
		{
			XeePhotoshopChannel *channel=[[[XeePhotoshopChannel alloc] initWithFileHandle:fh
			startOffset:pixeloffs previousDataSize:datasize channel:i of:numchannels
			rows:height columns:width depth:read_be_uint16(head->depth)] autorelease];
			datasize+=[channel dataSize];
			[channelarray addObject:channel];
		}

		if(alphachannel>=0&&alphachannel+colorchannels<numchannels)
		{
			for(int i=0;i<alphachannel;i++) // skip channels before alpha channel
			{
				XeePhotoshopChannel *channel=[[XeePhotoshopChannel alloc] initWithFileHandle:fh
				startOffset:pixeloffs previousDataSize:datasize channel:i+colorchannels of:numchannels
				rows:height columns:width depth:read_be_uint16(head->depth)];
				datasize+=[channel dataSize];
				[channel release];
			}

			XeePhotoshopChannel *channel=[[[XeePhotoshopChannel alloc] initWithFileHandle:fh
			startOffset:pixeloffs previousDataSize:datasize channel:alphachannel+colorchannels of:numchannels
			rows:height columns:width depth:read_be_uint16(head->depth)] autorelease];
			[channelarray addObject:channel];
		}

		mainimage=[[[XeePhotoshopSubImage alloc]
		initWithImage:self width:width height:height depth:read_be_uint16(head->depth)
		mode:read_be_uint16(head->mode) channels:channelarray] autorelease];
		if(!mainimage) return NULL;
		if(read_be_uint16(head->mode)==PSDMODE_RGB||read_be_uint16(head->mode)==PSDMODE_GREYSCALE)
		[mainimage setIsPreComposited:YES];
		[self addSubImage:mainimage];
	}

	if(layercount>0)
	{
		[fh seekToFileOffset:layerstart];

		off_t totalsize=0;
		for(int i=0;i<layercount;i++)
		{
			int32 y1=[fh readInt32BE];
			int32 x1=[fh readInt32BE];
			int32 y2=[fh readInt32BE];
			int32 x2=[fh readInt32BE];
			uint16 numlayerchannels=[fh readUint16BE];

			int layerwidth=x2-x1,layerheight=y2-y1;
			BOOL reallayer=layerwidth>0&&layerheight>0;
			BOOL hasalpha=NO;

			XeePhotoshopChannel *layerchannels[colorchannels+1];
			for(int j=0;j<=colorchannels;j++) layerchannels[j]=nil;

			for(int j=0;j<numlayerchannels;j++)
			{
				int16 channelid=[fh readInt16BE];
				if(reallayer)
				if(channelid>=0||channelid==-1)
				{
					XeePhotoshopChannel *channel=[[[XeePhotoshopChannel alloc] initWithFileHandle:fh
					startOffset:layerchannelstart+totalsize previousDataSize:0 channel:0 of:1
					rows:layerheight columns:layerwidth depth:read_be_uint16(head->depth)] autorelease];

					if(channelid>=0) layerchannels[channelid]=channel;
					else
					{
						layerchannels[colorchannels]=channel;
						hasalpha=YES;
					}
				}

				totalsize+=[fh readUint32BE];
			}

			if(reallayer)
			{
				NSArray *channelarray=[NSArray arrayWithObjects:layerchannels count:colorchannels+(hasalpha?1:0)];
				XeePhotoshopSubImage *layer=[[[XeePhotoshopSubImage alloc]
				initWithImage:self width:layerwidth height:layerheight depth:read_be_uint16(head->depth)
				mode:read_be_uint16(head->mode) channels:channelarray] autorelease];
				if(layer) [self addSubImage:layer];
			}

			[fh skipBytes:12];
			uint32 extrasize=[fh readUint32BE];
			[fh skipBytes:extrasize];
		}
	}

	if(!hasmain)
	{
		if([self frames]) mainimage=(XeePhotoshopSubImage *)[self currentSubImage];
		else return NULL;
	}

	return @selector(loadMain);
}

-(SEL)loadMain
{
	[mainimage runLoader];

	if([mainimage completed])
	{
		if(![mainimage failed]) success=YES;
		return NULL;
	}

	return @selector(loadMain);
}

-(void)setFrame:(int)frame
{
	[super setFrame:frame];
	if(frame!=0&&![[self currentSubImage] completed]) [[self currentSubImage] runLoader];
}

-(uint8 *)palette { return palette; }

-(int)paletteSize { return palsize; }

-(int)actualColours { return actualcolours>0?actualcolours:palsize; }

-(int)transparentIndex { return transparentindex; }

+(NSArray *)fileTypes
{
	return [NSArray arrayWithObjects:@"psd",@"'8BPS'",nil];
}

@end



@implementation XeePhotoshopSubImage

-(id)initWithImage:(XeePhotoshopImage *)parentimage width:(int)imgwidth height:(int)imgheight
depth:(int)bitdepth mode:(int)imgmode channels:(NSArray *)imgchannels
{
	if(self=[super init])
	{
		width=imgwidth;
		height=imgheight;
		channelarray=[imgchannels retain];
		bits=bitdepth;
		mode=imgmode;
		parent=parentimage;

		rowoffs=NULL;
		inbuf=NULL;
		linebuf=NULL;

		numchannels=[channelarray count];

		switch(mode)
		{
			case PSDMODE_BITMAP:
				[self setDepthBitmap];
			break;
			case PSDMODE_GREYSCALE:
				[self setDepthGrey:bitdepth alpha:numchannels>1 floating:bitdepth==32];
			break;
			case PSDMODE_DUOTONE:
				if(numchannels>1) [self setDepth:[NSString stringWithFormat:@"%d bit duotone+alpha",bitdepth] iconName:@"depth_greyalpha"];
				else [self setDepth:[NSString stringWithFormat:@"%d bit duotone",bitdepth] iconName:@"depth_grey"];
			break;
			case PSDMODE_INDEXED:
				[self setDepthIndexed:[parent actualColours]];
			break;
			case PSDMODE_RGB:
				[self setDepthRGB:bitdepth alpha:numchannels>3 floating:bitdepth==32];
			break;
			break;
			case PSDMODE_CMYK:
				[self setDepthCMYK:bitdepth alpha:numchannels>4];
			break;
			case PSDMODE_LAB:
				[self setDepthLab:bitdepth alpha:numchannels>3];
			break;
		}

		nextselector=@selector(startLoading);

		//[XeePhotoShopImage setDepthForImage:self channels:channels depth:bits mode:colourmode];

		//if(mode==PSDMODE_BITMAP||mode==PSDMODE_GREYSCALE||mode==PSDMODE_INDEXED||mode==PSDMODE_RGB||mode==PSDMODE_DUOTONE)
		{
			return self;
		}

		[self release];
	}

	return nil;
}

-(void)deallocLoader
{
	[channelarray release];
	free(rowoffs);
	free(inbuf);
	free(linebuf);

	[super deallocLoader];
}

-(SEL)startLoading
{
	int type=0,linebufsize=0;

	switch(mode)
	{
		case PSDMODE_BITMAP:
			if(bits!=1) return NULL;
			type=XeeBitmapTypeLuma8;
			linebufsize=(width+7)/8;
		break;

		case PSDMODE_GREYSCALE:
		case PSDMODE_DUOTONE:
			if(bits==8)
			{
				if(numchannels>1) type=XeeBitmapTypeLumaAlpha8;
				else type=XeeBitmapTypeLuma8;
			}
			else if(bits==16)
			{
				if(numchannels>1) type=XeeBitmapTypeLumaAlpha16;
				else type=XeeBitmapTypeLuma16;
			}
			else if(bits==32)
			{
				if(numchannels>1) type=XeeBitmapTypeLumaAlpha32FP;
				else type=XeeBitmapTypeLuma32FP;
			}
		break;

		case PSDMODE_INDEXED:
			if(bits!=8) return NULL;
			if([parent transparentIndex]>=0) type=XeeBitmapTypeARGB8;
			else type=XeeBitmapTypeRGB8;
			linebufsize=width;
		break;

		case PSDMODE_RGB:
			if(numchannels<3) return NULL;
			if(bits==8)
			{
				if(numchannels>3) type=XeeBitmapTypeARGB8;
				else type=XeeBitmapTypeRGB8;
			}
			else if(bits==16)
			{
				if(numchannels>3) type=XeeBitmapTypeRGBA16;
				else type=XeeBitmapTypeRGB16;
			}
			else if(bits==32)
			{
				if(numchannels>3) type=XeeBitmapTypeRGBA32FP;
				else type=XeeBitmapTypeRGB32FP;
			}
		break;

		case PSDMODE_CMYK:
			if(numchannels<4) return NULL;
			if(bits==8)
			{
				if(numchannels>4) type=XeeBitmapTypeARGB8;
				else type=XeeBitmapTypeRGB8;
			}
			else if(bits==16)
			{
				if(numchannels>4) type=XeeBitmapTypeRGBA16;
				else type=XeeBitmapTypeRGB16;
			}
			linebufsize=width*4*(bits/8);
		break;

		case PSDMODE_LAB:
			if(numchannels<3) return NULL;
			if(bits==8)
			{
				if(numchannels>3) type=XeeBitmapTypeARGB8;
				else type=XeeBitmapTypeRGB8;
			}
			else if(bits==16)
			{
				if(numchannels>3) type=XeeBitmapTypeRGBA16;
				else type=XeeBitmapTypeRGB16;
			}
			linebufsize=width*3*(bits/8);
		break;
	}

	if(!type) return NULL;
	if(![self allocWithType:type width:width height:height]) return NULL;

	if(linebufsize)
	{
		linebuf=malloc(linebufsize);
		if(!linebuf) return NULL;
	}

	int inbufsize=0;
	for(int i=0;i<numchannels;i++)
	{
		channels[i]=[channelarray objectAtIndex:i];
		int currsize=[channels[i] requiredBufferSize];
		if(currsize>inbufsize) inbufsize=currsize;
	}

	inbuf=malloc(inbufsize);
	if(!inbuf) return NULL;

	for(int i=0;i<numchannels;i++) [channels[i] setBuffer:inbuf];

	current_line=0;

	return @selector(load);
}

-(SEL)load
{
	int sampsize=bits/8;
	switch(mode)
	{
		case PSDMODE_BITMAP:
			[channels[0] loadRow:current_line toBuffer:linebuf stride:1];
			[self expandBitmapData:linebuf toImage:data+current_line*bytesperrow];
		break;

		case PSDMODE_GREYSCALE:
		case PSDMODE_DUOTONE:
			[channels[0] loadRow:current_line toBuffer:data+current_line*bytesperrow stride:pixelsize];
			if(numchannels>1) [self loadAlphaChannel:channels[1] row:current_line toBuffer:data+current_line*bytesperrow alphaIndex:1 colorChannels:1 stride:pixelsize];
		break;

		case PSDMODE_INDEXED:
			[channels[0] loadRow:current_line toBuffer:linebuf stride:1];
			[self expandIndexedData:linebuf toImage:data+current_line*bytesperrow];
		break;

		case PSDMODE_RGB:
			if(numchannels>3&&bits==8) // special case to use ARGB
			{
				[channels[0] loadRow:current_line toBuffer:data+current_line*bytesperrow+1 stride:4];
				[channels[1] loadRow:current_line toBuffer:data+current_line*bytesperrow+2 stride:4];
				[channels[2] loadRow:current_line toBuffer:data+current_line*bytesperrow+3 stride:4];
				[self loadAlphaChannel:channels[3] row:current_line toBuffer:data+current_line*bytesperrow alphaIndex:0 colorChannels:3 stride:4];
			}
			else
			{
				[channels[0] loadRow:current_line toBuffer:data+current_line*bytesperrow stride:pixelsize];
				[channels[1] loadRow:current_line toBuffer:data+current_line*bytesperrow+sampsize stride:pixelsize];
				[channels[2] loadRow:current_line toBuffer:data+current_line*bytesperrow+2*sampsize stride:pixelsize];
				if(numchannels>3) [self loadAlphaChannel:channels[3] row:current_line toBuffer:data+current_line*bytesperrow alphaIndex:3 colorChannels:3 stride:pixelsize];
			}
		break;

		case PSDMODE_CMYK:
			[channels[0] loadRow:current_line toBuffer:linebuf stride:4*sampsize];
			[channels[1] loadRow:current_line toBuffer:linebuf+sampsize stride:4*sampsize];
			[channels[2] loadRow:current_line toBuffer:linebuf+2*sampsize stride:4*sampsize];
			[channels[3] loadRow:current_line toBuffer:linebuf+3*sampsize stride:4*sampsize];

			if(numchannels>4&&bits==8)
			{
				[self convertCMYKData:linebuf toImage:data+current_line*bytesperrow+1 stride:4];
				[self loadAlphaChannel:channels[4] row:current_line toBuffer:data+current_line*bytesperrow alphaIndex:0 colorChannels:3 stride:4];
			}
			else
			{
				[self convertCMYKData:linebuf toImage:data+current_line*bytesperrow stride:pixelsize];
				if(numchannels>4) [self loadAlphaChannel:channels[4] row:current_line toBuffer:data+current_line*bytesperrow alphaIndex:3 colorChannels:3 stride:pixelsize];
			}
		break;

		case PSDMODE_LAB:
			[channels[0] loadRow:current_line toBuffer:linebuf stride:3*sampsize];
			[channels[1] loadRow:current_line toBuffer:linebuf+sampsize stride:3*sampsize];
			[channels[2] loadRow:current_line toBuffer:linebuf+2*sampsize stride:3*sampsize];

			if(numchannels>3&&bits==8)
			{
				[self convertLabData:linebuf toImage:data+current_line*bytesperrow+1 stride:4];
				[self loadAlphaChannel:channels[3] row:current_line toBuffer:data+current_line*bytesperrow alphaIndex:0 colorChannels:3 stride:4];
			}
			else
			{
				[self convertLabData:linebuf toImage:data+current_line*bytesperrow stride:pixelsize];
				if(numchannels>3) [self loadAlphaChannel:channels[3] row:current_line toBuffer:data+current_line*bytesperrow alphaIndex:3 colorChannels:3 stride:pixelsize];
			}
		break;
	}

	current_line++;
	[self setCompletedRowCount:current_line];

	if(current_line>=height)
	{
		success=YES;
		return NULL;
	}
	return @selector(load);
}

-(void)expandBitmapData:(uint8 *)bitmap toImage:(uint8 *)dest
{
	for(int i=0;i<width;i++) *dest++=bitmap[i/8]&(0x80>>(i&7))?0:0xff;
}

-(void)expandIndexedData:(uint8 *)indexed toImage:(uint8 *)dest
{
	uint8 *palette=[parent palette];
	int palsize=[parent paletteSize];
	int transparentindex=[parent transparentIndex];

	for(int i=0;i<width;i++)
	{
		uint8 val=indexed[i];

		if(transparentindex>0)
		{
			if(val==transparentindex) *dest++=0;
			else *dest++=0xff;
		}

		if(val<palsize)
		{
			*dest++=palette[val];
			*dest++=palette[val+palsize];
			*dest++=palette[val+palsize*2];
		}
		else *dest++=*dest++=*dest++=0;
	}
}

-(void)convertCMYKData:(uint8 *)cmyk toImage:(uint8 *)dest stride:(int)stride
{
	if(bits==8) for(int i=0;i<width;i++)
	{ dest[0]=*cmyk++; dest[1]=*cmyk++; dest[2]=*cmyk++; cmyk++; dest+=stride; }
	else
	{
		uint16 *cmyk16=(uint16 *)cmyk;
		for(int i=0;i<width;i++)
		{
			uint16 *dest16=(uint16 *)dest;
			dest16[0]=*cmyk16++; dest16[1]=*cmyk16++; dest16[2]=*cmyk16++; cmyk16++;
			dest+=stride;
		}
	}
}

-(void)convertLabData:(uint8 *)lab toImage:(uint8 *)dest stride:(int)stride
{
	if(bits==8) for(int i=0;i<width;i++)
	{ dest[0]=*lab++; dest[1]=*lab++; dest[2]=*lab++; dest+=stride; }
	else
	{
		uint16 *lab16=(uint16 *)lab;
		for(int i=0;i<width;i++)
		{
			uint16 *dest16=(uint16 *)dest;
			dest16[0]=*lab16++; dest16[1]=*lab16++; dest16[2]=*lab16++;
			dest+=stride;
		}
	}
}

-(void)loadAlphaChannel:(XeePhotoshopChannel *)channel row:(int)row toBuffer:(uint8 *)buf alphaIndex:(int)alphaindex colorChannels:(int)colorchannels stride:(int)stride
{
	int sampsize=bits/8;

	[channel loadRow:row toBuffer:buf+alphaindex*sampsize stride:stride];

	if(premultiplied)
	{
		if(bits==8) for(int i=0;i<width;i++)
		{
			if(alphaindex==0)
			for(int j=0;j<colorchannels;j++) buf[j+1]-=buf[0]^0xff;
			else
			for(int j=0;j<colorchannels;j++) buf[j]-=buf[colorchannels]^0xff;
			buf+=stride;
		}
		else if(bits==16) for(int i=0;i<width;i++)
		{
			if(alphaindex==0)
			for(int j=0;j<colorchannels;j++) ((uint16 *)buf)[j+1]-=((uint16 *)buf)[0]^0xffff;
			else
			for(int j=0;j<colorchannels;j++) ((uint16 *)buf)[j]-=((uint16 *)buf)[colorchannels]^0xffff;
			buf+=stride;
		}
	}
}

-(void)setIsPreComposited:(BOOL)precomp { premultiplied=precomp; }

@end



@implementation XeePhotoshopChannel

-(id)initWithFileHandle:(XeeFileHandle *)file startOffset:(off_t)startoffs previousDataSize:(off_t)prevsize channel:(int)channel of:(int)channels rows:(int)imgrows columns:(int)imgcols depth:(int)bitdepth
{
	if(self=[super init])
	{
		fh=[file retain];
		rows=imgrows;
		cols=imgcols;
		depth=bitdepth;
		inbufsize=0;
		inbuf=NULL;

		rowoffs=malloc((rows+1)*sizeof(off_t));
		if(!rowoffs) [NSException raise:@"XeePhotoshopLoaderException" format:@"Out of memory"];

		off_t prevoffs=[fh offsetInFile];
		[fh seekToFileOffset:startoffs];
		compression=[fh readUint16BE];

		if(compression==0)
		{
			int bpr=(depth*cols+7)/8;

			for(int y=0;y<rows;y++) rowoffs[y]=startoffs+2+prevsize+y*bpr;
			rowoffs[rows]=startoffs+2+prevsize+rows*bpr;

			inbufsize=bpr;
		}
		else if(compression==1)
		{
			if(depth!=1&&depth!=8) return NULL;

			[fh skipBytes:2*channel*rows];
			off_t offs=startoffs+2+2*channels*rows+prevsize;

			for(int y=0;y<rows;y++)
			{
				rowoffs[y]=offs;
				int rowlen=[fh readUint16BE];
				offs+=rowlen;
				if(rowlen>inbufsize) inbufsize=rowlen;
			}
			rowoffs[rows]=offs;
		}
		else [NSException raise:@"XeePhotoshopLoaderException" format:@"Unknown compression type"];

		[fh seekToFileOffset:prevoffs];
	}
	return self;
}

-(void)dealloc
{
	[fh release];
	free(rowoffs);
	[super dealloc];
}

-(off_t)dataSize { return rowoffs[rows]-rowoffs[0]; }

-(int)requiredBufferSize { return inbufsize; }

-(void)setBuffer:(uint8 *)newbuf { inbuf=newbuf; }

-(void)loadRow:(int)row toBuffer:(uint8 *)dest stride:(int)stride
{
	if(row<0||row>=rows) return;
	int size=rowoffs[row+1]-rowoffs[row];

	[fh seekToFileOffset:rowoffs[row]];
	[fh readBytes:size toBuffer:inbuf];

	if(compression==0)
	{
		if(depth==16)
		{
			for(int i=0;i<cols;i++)
			#ifdef BIG_ENDIAN
			{ *((uint16 *)dest)=*(((uint16 *)inbuf)+i); dest+=stride; }
			#else
			{ *dest++=inbuf[2*i+1]; *dest++=inbuf[2*i]; dest+=stride; }
			#endif
		}
		else if(depth==32)
		{
			for(int i=0;i<cols;i++)
			#ifdef BIG_ENDIAN
			{ *((uint32 *)dest)=*(((uint32 *)inbuf)+i); dest+=stride; }
			#else
			{ *dest++=inbuf[4*i+3]; *dest++=inbuf[4*i+2]; *dest++=inbuf[4*i+1]; *dest++=inbuf[4*i]; dest+=stride; }
			#endif
		}
		else for(int i=0;i<cols;i++) { *dest=inbuf[i]; dest+=stride; }
	}
	else if(compression==1)
	{
		XeeUnPackBitsFromMemory(inbuf,dest,size,cols,stride);
	}
}

@end
