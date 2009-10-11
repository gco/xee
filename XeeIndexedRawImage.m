#import "XeeIndexedRawImage.h"


@implementation XeeIndexedRawImage

-(id)initWithHandle:(CSHandle *)fh width:(int)framewidth height:(int)frameheight
palette:(XeePalette *)palette
{
	return [self initWithHandle:fh width:framewidth height:frameheight depth:8 palette:palette bytesPerRow:0];
}

-(id)initWithHandle:(CSHandle *)fh width:(int)framewidth height:(int)frameheight
palette:(XeePalette *)palette bytesPerRow:(int)bytesperinputrow
{
	return [self initWithHandle:fh width:framewidth height:frameheight depth:8 palette:palette bytesPerRow:bytesperinputrow];
}

-(id)initWithHandle:(CSHandle *)fh width:(int)framewidth height:(int)frameheight
depth:(int)framedepth palette:(XeePalette *)palette
{
	return [self initWithHandle:fh width:framewidth height:frameheight depth:framedepth palette:palette bytesPerRow:0];
}

-(id)initWithHandle:(CSHandle *)fh width:(int)framewidth height:(int)frameheight
depth:(int)framedepth palette:(XeePalette *)palette bytesPerRow:(int)bytesperinputrow
{
	if(self=[super initWithHandle:fh])
	{
		pal=[palette retain];
		width=framewidth;
		height=frameheight;
		bitdepth=framedepth;
		inbpr=bytesperinputrow;
	}
	return self;
}

-(void)dealloc
{
	free(buffer);
	[pal release];
	[super dealloc];
}

-(void)load
{
	if(!handle) XeeImageLoaderDone(NO);
	XeeImageLoaderHeaderDone();

	if(![self allocWithType:[pal isTransparent]?XeeBitmapTypeARGB8:XeeBitmapTypeRGB8 width:width height:height]) XeeImageLoaderDone(NO);

	int buffersize=(width*bitdepth+7)/8;
	buffer=malloc(buffersize);
	if(!buffer) XeeImageLoaderDone(NO);

	for(int row=0;row<height;row++)
	{
		[handle readBytes:buffersize toBuffer:buffer];
		if(inbpr&&inbpr!=buffersize) [handle skipBytes:inbpr-buffersize];

		uint8_t *rowptr=XeeImageDataRow(self,row);
		if(transparent) [pal convertIndexes:buffer count:width depth:bitdepth toARGB8:rowptr];
		else [pal convertIndexes:buffer count:width depth:bitdepth toRGB8:rowptr];

		[self setCompletedRowCount:row+1];
		XeeImageLoaderYield();
	}

	free(buffer);
	buffer=NULL;

	XeeImageLoaderDone(YES);
}

@end



@implementation XeePalette

+(XeePalette *)palette { return [[[self alloc] init] autorelease]; }

-(id)init
{
	if(self=[super init])
	{
		numcolours=0;
		istrans=NO;
	}
	return self;
}

-(int)numberOfColours { return numcolours; }

-(uint32_t)colourAtIndex:(int)index { if(index>=0&&index<256) return pal[index]; else return 0; }

-(BOOL)isTransparent { return istrans; }

-(uint32_t *)colours { return pal; }

-(void)setColourAtIndex:(int)index red:(uint8_t)red green:(uint8_t)green blue:(uint8_t)blue
{
	[self setColourAtIndex:index red:red green:green blue:blue alpha:0xff];
}

-(void)setColourAtIndex:(int)index red:(uint8_t)red green:(uint8_t)green blue:(uint8_t)blue alpha:(uint8_t)alpha
{
	if(index<0||index>=256) return;
	pal[index]=XeeMakeARGB8(alpha,red,green,blue);
	if(index>=numcolours) numcolours=index+1;
	if(alpha!=0xff) istrans=YES;
}

-(void)setTransparent:(int)index
{
	[self setColourAtIndex:index red:0 green:0 blue:0 alpha:0];
}

-(void)convertIndexes:(uint8_t *)indexes count:(int)count depth:(int)depth toRGB8:(uint8_t *)dest
{
	switch(depth)
	{
		case 1:
			for(int i=0;i<count;i++)
			{
 				uint32_t col=pal[(indexes[i>>3]>>((i&7)^7))&0x01];
				*dest++=XeeGetRFromARGB8(col);
				*dest++=XeeGetGFromARGB8(col);
				*dest++=XeeGetBFromARGB8(col);
			}
		break;

		case 2:
			for(int i=0;i<count;i++)
			{
 				uint32_t col=pal[(indexes[i>>2]>>(((i&3)^3)<<1))&0x03];
				*dest++=XeeGetRFromARGB8(col);
				*dest++=XeeGetGFromARGB8(col);
				*dest++=XeeGetBFromARGB8(col);
			}
		break;

		case 4:
			for(int i=0;i<count;i++)
			{
 				uint32_t col=pal[(indexes[i>>1]>>(((i&1)^1)<<2))&0x0f];
				*dest++=XeeGetRFromARGB8(col);
				*dest++=XeeGetGFromARGB8(col);
				*dest++=XeeGetBFromARGB8(col);
			}
		break;

		case 8:
			for(int i=0;i<count;i++)
			{
 				uint32_t col=pal[indexes[i]];
				*dest++=XeeGetRFromARGB8(col);
				*dest++=XeeGetGFromARGB8(col);
				*dest++=XeeGetBFromARGB8(col);
			}
		break;
	}
}

-(void)convertIndexes:(uint8_t *)indexes count:(int)count depth:(int)depth toARGB8:(uint8_t *)dest
{
	uint32_t *destptr=(uint32_t *)dest;

	switch(depth)
	{
		case 1:
			for(int i=0;i<count;i++) destptr[i]=pal[(indexes[i>>3]>>((i&7)^7))&0x01];
		break;

		case 2:
			for(int i=0;i<count;i++) destptr[i]=pal[(indexes[i>>2]>>(((i&3)^3)<<1))&0x03];
		break;

		case 4:
			for(int i=0;i<count;i++) destptr[i]=pal[(indexes[i>>1]>>(((i&1)^1)<<2))&0x0f];
		break;

		case 8:
			for(int i=0;i<count;i++) destptr[i]=pal[indexes[i]];
		break;
	}
}

@end