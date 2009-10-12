#import "XeeDreamcastLoader.h"

#define PIXEL_ARGB1555 0
#define PIXEL_RGB565 1
#define PIXEL_ARGB4444 2
#define PIXEL_YUV422 3
#define PIXEL_BUMP 4
#define PIXEL_4BIT 5
#define PIXEL_8BIT 6
#define PIXEL_LAST_EXPANDABLE PIXEL_ARGB4444


static int CalculateMipmapSize(int width,int height)
{
	int sum=0;
	while(width&&height)
	{
		width/=2;
		height/=2;
		sum+=width*height;
	}
	return sum+1;
}

static uint32_t InterleavedCoords(uint32_t x,uint32_t y)
{
	x=(x|(x<<8))&0x00ff00ff;
	x=(x|(x<<4))&0x0f0f0f0f;
	x=(x|(x<<2))&0x33333333;
	x=(x|(x<<1))&0x55555555;

	y=(y|(y<<8))&0x00ff00ff;
	y=(y|(y<<4))&0x0f0f0f0f;
	y=(y|(y<<2))&0x33333333;
	y=(y|(y<<1))&0x55555555;

	return (x<<1)|y;
}

static uint32_t UnInterleavedXCoord(uint32_t n)
{
	n=(n>>1)&0x55555555;
	n=(n|(n>>1))&0x33333333;
	n=(n|(n>>2))&0x0f0f0f0f;
	n=(n|(n>>4))&0x00ff00ff;
	n=(n|(n>>8))&0x0000ffff;
	return n;
}

static uint32_t UnInterleavedYCoord(uint32_t n)
{
	n=n&0x55555555;
	n=(n|(n>>1))&0x33333333;
	n=(n|(n>>2))&0x0f0f0f0f;
	n=(n|(n>>4))&0x00ff00ff;
	n=(n|(n>>8))&0x0000ffff;
	return n;
}

static uint32_t ExpandColour(int col,int pixelformat)
{
	switch(pixelformat)
	{
		case PIXEL_ARGB1555:
			return XeeMakeARGB8(
			(-(col>>15))&0xff,
			((col>>7)&0xf8)|((col>>12)&0x07),
			((col>>2)&0xf8)|((col>>7)&0x07),
			((col<<3)&0xf8)|((col>>2)&0x07));

		case PIXEL_RGB565:
			return XeeMakeNRGB8(
			((col>>8)&0xf8)|((col>>13)&0x07),
			((col>>3)&0xfc)|((col>>9)&0x03),
			((col<<3)&0xf8)|((col>>2)&0x07));

		case PIXEL_ARGB4444:
			return XeeMakeARGB8(
			((col>>8)&0xf0)|((col>>12)&0x0f),
			((col>>4)&0xf0)|((col>>8)&0x0f),
			(col&0xf0)|((col>>4)&0x0f),
			((col<<4)&0xf0)|(col&0x0f));

		case PIXEL_YUV422:
			return XeeMakeNRGB8(col>>8,col>>8,col>>8);

		default: return 0;
	}
}

#define ONE_HALF (1<<15)
#define FIX(x) ((int)((x)*(1<<16)+0.5))
#define LIMIT(x) ((x)<0?0:(x)>255?255:(x))

static uint32_t ConvertYUV(int y,int u,int v)
{
	int r=y+((FIX(1.40200)*(v-128)+ONE_HALF)>>16);
	int g=y+((-FIX(0.34414)*(u-128)-FIX(0.71414)*(v-128)+ONE_HALF)>>16);
	int b=y+((FIX(1.77200)*(u-128)+ONE_HALF)>>16);
	return XeeMakeNRGB8(LIMIT(r),LIMIT(g),LIMIT(b));
}

@implementation XeeDreamcastImage

static void WritePixel(XeeDreamcastImage *self,int x,int y,uint32_t col)
{
	if(x<self->width&&y<self->height) ((uint32_t *)&self->data[y*self->bytesperrow])[x]=col;
}


+(NSArray *)fileTypes
{
	return [NSArray arrayWithObject:@"pvr"];
}

+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes
{
	if([block length]>16)
	{
		uint32_t magic=XeeBEUInt32([block bytes]);
		if(magic=='GBIX') return YES;
		if(magic=='PVRT') return YES;
	}

	return NO;
}


-(void)load
{
	CSHandle *fh=[self handle];

	uint32_t magic=[fh readID];
	if(magic=='GBIX')
	{
		uint32_t size=[fh readUInt32LE];
		[fh skipBytes:size];
		magic=[fh readID];
	}

	if(magic!='PVRT') return;

	/*uint32_t length=*/[fh readUInt32LE];
	int pixelformat=[fh readUInt8];
	int packingtype=[fh readUInt8];
	[fh skipBytes:2];
	width=[fh readUInt16LE];
	height=[fh readUInt16LE];

	[self setFormat:@"Dreamcast PVR"];

	switch(pixelformat)
	{
		case PIXEL_ARGB1555:
			[self setDepth:@"1:5:5:5 bit ARGB" iconName:@"depth_rgba"];
			transparent=YES;
		break;
		case PIXEL_RGB565:
			[self setDepth:@"5:6:5 bit RGB" iconName:@"depth_rgb"];
		break;
		case PIXEL_ARGB4444:
			[self setDepthRGBA:4];
			transparent=YES;
		break;
		case PIXEL_YUV422:
			[self setDepth:@"YUV422" iconName:@"depth_rgb"];
		break;
		case PIXEL_BUMP:
		break;
		case PIXEL_4BIT:
			[self setDepthIndexed:16];
		break;
		case PIXEL_8BIT:
			[self setDepthIndexed:256];
		break;
		default:
			return;
	}

	[properties addObject:[XeePropertyItem subSectionItemWithLabel:
	NSLocalizedString(@"PVR properties",@"PVR properties section title")
	identifier:@"pvr.properites"
	labelsAndValues:
		NSLocalizedString(@"Pixel format",@"PVR pixel format property label"),
		[NSString stringWithFormat:@"0x%02x",pixelformat],
		NSLocalizedString(@"Pixel packing",@"PVR pixel packing property label"),
		[NSString stringWithFormat:@"0x%02x",packingtype],
	nil]];

	XeeImageLoaderHeaderDone();

	[self allocWithType:XeeBitmapTypeARGB8 width:width height:height];

	switch(packingtype)
	{
		case 0x01: // square twiddled
		case 0x0d: // rectangle twiddled
			if(pixelformat<=PIXEL_LAST_EXPANDABLE) [self loadTwiddledWithOffset:0 pixelFormat:pixelformat];
			else if(pixelformat==PIXEL_YUV422) [self loadTwiddledYUVWithOffset:0];
			else [self raiseFormatMismatchWithPixelFormat:pixelformat packingType:packingtype];
		break;
		case 0x02: // square twiddled with mipmap
		//case 0x0e: // rectangle twiddled with mipmap
			if(pixelformat<=PIXEL_LAST_EXPANDABLE) [self loadTwiddledWithOffset:CalculateMipmapSize(width,height)*2 pixelFormat:pixelformat];
			else if(pixelformat==PIXEL_YUV422) [self loadTwiddledYUVWithOffset:CalculateMipmapSize(width,height)*2];
			else [self raiseFormatMismatchWithPixelFormat:pixelformat packingType:packingtype];
		break;

		case 0x03: // VQ
			if(pixelformat<=PIXEL_LAST_EXPANDABLE) [self loadVQWithOffset:0 entries:256 pixelFormat:pixelformat];
			else [self raiseFormatMismatchWithPixelFormat:pixelformat packingType:packingtype];
		break;
		case 0x04: // VQ with mipmap
			if(pixelformat<=PIXEL_LAST_EXPANDABLE) [self loadVQWithOffset:CalculateMipmapSize(width/2,height/2) entries:256 pixelFormat:pixelformat];
			else [self raiseFormatMismatchWithPixelFormat:pixelformat packingType:packingtype];
		break;

		case 0x05: // 4-bit direct twiddled
			[self load4BitWithPalette:NO pixelFormat:0];
		break;
		//case 0x06: // 4-bit paletted twiddled
		//	if(pixelformat!=PIXEL_8BIT) [self raiseFormatMismatchWithPixelFormat:pixelformat packingType:packingtype];
		//	[self load4BitWithPalette:YES pixelFormat:pixelformat];
		//break;
		case 0x07: // 8-bit direct twiddled
			[self load8BitWithPalette:NO pixelFormat:0];
		break;
		//case 0x08: // 8-bit paletted twiddled
		//	if(pixelformat>PIXEL_LAST_EXPANDABLE) [self raiseFormatMismatchWithPixelFormat:pixelformat packingType:packingtype];
		//	[self load8BitWithPalette:YES pixelFormat:pixelformat];
		//break;

		case 0x09: // rectangle linear
			if(pixelformat<=PIXEL_LAST_EXPANDABLE) [self loadRectangleWithOffset:0 pixelFormat:pixelformat];
			else [self raiseFormatMismatchWithPixelFormat:pixelformat packingType:packingtype];
		break;
		//case 0x0a: // rectangle linear with mipmap
		//	if(pixelformat>PIXEL_LAST_EXPANDABLE) [self raiseFormatMismatchWithPixelFormat:pixelformat packingType:packingtype];
		//	[self loadRectangleWithOffset:CalculateMipmapOffset(width,height)*2 pixelFormat:pixelformat];
		//break;

		case 0x10: // small VQ
			if(pixelformat<=PIXEL_LAST_EXPANDABLE) [self loadVQWithOffset:0 entries:(width*height/32+15)&~15 pixelFormat:pixelformat];
			else [self raiseFormatMismatchWithPixelFormat:pixelformat packingType:packingtype];
		break;
		case 0x11:  // small VQ with mipmap
			if(pixelformat<=PIXEL_LAST_EXPANDABLE) [self loadVQWithOffset:CalculateMipmapSize(width/2,height/2)
			entries:(CalculateMipmapSize(width,height)/8+31)&~31 pixelFormat:pixelformat];
			else [self raiseFormatMismatchWithPixelFormat:pixelformat packingType:packingtype];
		break;

		case 0x12: // square twiddled with mipmap and padding?
			if(pixelformat<=PIXEL_LAST_EXPANDABLE) [self loadTwiddledWithOffset:CalculateMipmapSize(width,height)*2+4 pixelFormat:pixelformat];
			else if(pixelformat==PIXEL_YUV422)  [self loadTwiddledYUVWithOffset:CalculateMipmapSize(width,height)*2+4];
			else [self raiseFormatMismatchWithPixelFormat:pixelformat packingType:packingtype];
		break;

		default:
			[NSException raise:@"XeeDreamcastException" format:@"Unknown PVR packing type %02x",packingtype];
		break;
	}
	[self setCompleted];

	XeeImageLoaderDone(YES);
}

-(void)loadTwiddledWithOffset:(int)offset pixelFormat:(int)pixelformat
{
	CSHandle *fh=[self handle];

	[fh skipBytes:offset];

	int x_offs,y_offs,size;
	if(width>height) { x_offs=height; y_offs=0; size=height*height; }
	else { x_offs=0; y_offs=width; size=width*width; }

	for(int n=0;n<height*width;n++)
	{
		int n_square=n%size;
		int offs=n/size;
		int x=UnInterleavedXCoord(n_square)+offs*x_offs;
		int y=UnInterleavedYCoord(n_square)+offs*y_offs;
		WritePixel(self,x,y,ExpandColour([fh readUInt16LE],pixelformat));

		if(n%1024==0) XeeImageLoaderYield();
	}
}

-(void)loadTwiddledYUVWithOffset:(int)offset
{
	CSHandle *fh=[self handle];

	[fh skipBytes:offset];

	int x_offs,y_offs,size;
	if(width>height) { x_offs=height; y_offs=0; size=height*height; }
	else { x_offs=0; y_offs=width; size=width*width; }

	for(int n=0;n<height*width;n+=4)
	{
		uint16_t val11=[fh readUInt16LE];
		uint16_t val21=[fh readUInt16LE];
		uint16_t val12=[fh readUInt16LE];
		uint16_t val22=[fh readUInt16LE];
		int y11=val11>>8,y21=val21>>8,y12=val12>>8,y22=val22>>8;
		int u1=val11&0xff,u2=val21&0xff,v1=val12&0xff,v2=val22&0xff;

		int n_square=n%size;
		int offs=n/size;
		int x=UnInterleavedXCoord(n_square)+offs*x_offs;
		int y=UnInterleavedYCoord(n_square)+offs*y_offs;
		WritePixel(self,x,y,ConvertYUV(y11,u1,v1));
		WritePixel(self,x,y+1,ConvertYUV(y21,u2,v2));
		WritePixel(self,x+1,y,ConvertYUV(y12,u1,v1));
		WritePixel(self,x+1,y+1,ConvertYUV(y22,u2,v2));

		if(n%1024==0) XeeImageLoaderYield();
	}
}

-(void)load8BitWithPalette:(BOOL)haspalette pixelFormat:(int)pixelformat
{
	CSHandle *fh=[self handle];

	uint32_t palette[256];
	if(haspalette)
	{
		for(int i=0;i<256;i++) palette[i]=ExpandColour([fh readUInt16LE],pixelformat);
		[fh skipBytes:1024-256*2];
	}
	else
	{
		for(int i=0;i<256;i++) palette[i]=XeeMakeNRGB8(i,i,i);
	}

	int x_offs,y_offs,size;
	if(width>height) { x_offs=height; y_offs=0; size=height*height; }
	else { x_offs=0; y_offs=width; size=width*width; }

	for(int n=0;n<height*width;n++)
	{
		int n_square=n%size;
		int offs=n/size;
		int x=UnInterleavedXCoord(n_square)+offs*x_offs;
		int y=UnInterleavedYCoord(n_square)+offs*y_offs;
		WritePixel(self,x,y,palette[[fh readUInt8]]);

		if(n%1024==0) XeeImageLoaderYield();
	}
}

-(void)load4BitWithPalette:(BOOL)haspalette pixelFormat:(int)pixelformat
{
	CSHandle *fh=[self handle];

	uint32_t palette[16];
	if(haspalette)
	{
		for(int i=0;i<16;i++) palette[i]=ExpandColour([fh readUInt16LE],pixelformat);
		[fh skipBytes:1024-16*2];
	}
	else
	{
		for(int i=0;i<16;i++) palette[i]=XeeMakeNRGB8(i*0x11,i*0x11,i*0x11);
/*		if([self ref]) @try
		{
			CSHandle *binfile=[CSFileHandle fileHandleForReadingAtPath:
			[[[[self ref] path] stringByDeletingPathExtension] stringByAppendingPathExtension:@"BIN"]];

			[binfile skipBytes:8];
			for(int i=0;i<16;i++) palette[i]=XeeMakeNRGB8([binfile readUInt8],[binfile readUInt8],[binfile readUInt8]);
		}
		@catch(id e) { }*/

//		[NSException raise:@"XeeDreamcastException" format:"Direct palette mode not implemented"];
	}

	int x_offs,y_offs,size;
	if(width>height) { x_offs=height; y_offs=0; size=height*height; }
	else { x_offs=0; y_offs=width; size=width*width; }

	for(int n=0;n<height*width;n+=2)
	{
		uint8_t val=[fh readUInt8];

		int n_square=n%size;
		int offs=n/size;
		int x1=UnInterleavedXCoord(n_square)+offs*x_offs;
		int y1=UnInterleavedYCoord(n_square)+offs*y_offs;
		WritePixel(self,x1,y1,palette[val&0x0f]);

		int x2=x1; //=UnInterleavedXCoord(n+1);
		int y2=y1+1; //=UnInterleavedYCoord(n+1);
		WritePixel(self,x2,y2,palette[val>>4]);

		if(n%1024==0) XeeImageLoaderYield();
	}
}

-(void)loadVQWithOffset:(int)offset entries:(int)entries pixelFormat:(int)pixelformat
{
	CSHandle *fh=[self handle];

	uint32_t vqtab[entries][4];
	for(int i=0;i<entries;i++)
	for(int j=0;j<4;j++)
	vqtab[i][j]=ExpandColour([fh readUInt16LE],pixelformat);

	[fh skipBytes:offset];

	for(int n=0;n<(height/2)*(height/2);n++)
	{
		int x=UnInterleavedXCoord(n)*2;
		int y=UnInterleavedYCoord(n)*2;

		uint32_t *vq=vqtab[[fh readUInt8]];
		WritePixel(self,x,y,vq[0]);
		WritePixel(self,x,y+1,vq[1]);
		WritePixel(self,x+1,y,vq[2]);
		WritePixel(self,x+1,y+1,vq[3]);

		if(n%1024==0) XeeImageLoaderYield();
	}
}

-(void)loadRectangleWithOffset:(int)offset pixelFormat:(int)pixelformat
{
	CSHandle *fh=[self handle];

	[fh skipBytes:offset];

	uint8_t rowbuf[width*2];
	for(int row=0;row<height;row++)
	{
		[fh readBytes:width*2 toBuffer:rowbuf];

		uint32_t *dest=(uint32_t *)(data+row*bytesperrow);
		for(int col=0;col<width;col++) dest[col]=ExpandColour(XeeLEUInt16(&rowbuf[2*col]),pixelformat);

		[self setCompletedRowCount:row+1];
		XeeImageLoaderYield();
	}
}

-(void)raiseFormatMismatchWithPixelFormat:(int)pixelformat packingType:(int)packingtype
{
	[NSException raise:@"XeeDreamcastException" format:@"Pixel format %02x not compatible with packing type %02x",pixelformat,packingtype];
}


@end




@implementation XeeDreamcastMultiImage

+(NSArray *)fileTypes
{
	return [NSArray arrayWithObject:@"pvm"];
}

+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes
{
	if([block length]>16)
	{
		uint32_t magic=XeeBEUInt32([block bytes]);
		if(magic=='GBIX') return YES;
		if(magic=='PVMH') return YES;
	}
	
	return NO;
}


-(void)load
{
	CSHandle *fh=[self handle];

	uint32_t magic=[fh readID];
	if(magic=='GBIX')
	{
		uint32_t size=[fh readUInt32LE];
		[fh skipBytes:size];
		magic=[fh readID];
	}
	
	if(magic!='PVMH') return;
	uint32_t headsize=[fh readUInt32LE];
	[fh skipBytes:headsize];

	int numimages=(headsize-4)/38;

	[self setFormat:@"Dreamcast PVM"];

	for(int i=0;i<numimages;i++)
	{
		off_t start=[fh offsetInFile];

		int magic=[fh readID];
		if(magic!='PVRT') break;
		int len=[fh readUInt32LE];

		XeeDreamcastImage *subimage=[[[XeeDreamcastImage alloc]
		initWithHandle:[fh subHandleFrom:start length:len+8]] autorelease];

		[self addSubImage:subimage];

		if(i==0) XeeImageLoaderHeaderDone();

		[self runLoaderOnSubImage:subimage];

		[fh skipBytes:len];
	}

	XeeImageLoaderDone(YES);
}

@end
