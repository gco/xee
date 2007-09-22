#import "XeeIndexedRawImage.h"


@implementation XeeIndexedRawImage

-(id)initWithHandle:(CSHandle *)fh width:(int)framewidth height:(int)frameheight
palette:(XeePalette *)palette
{
	return [self initWithHandle:fh width:framewidth height:frameheight palette:palette bytesPerRow:0];
}

-(id)initWithHandle:(CSHandle *)fh width:(int)framewidth height:(int)frameheight
palette:(XeePalette *)palette bytesPerRow:(int)bytesperinputrow
{
	if(self=[super initWithHandle:fh])
	{
		pal=[palette retain];
		width=framewidth;
		height=frameheight;
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

	buffer=malloc(width);
	if(!buffer) XeeImageLoaderDone(NO);

	for(int row=0;row<height;row++)
	{
		[handle readBytes:width toBuffer:buffer];
		if(inbpr&&inbpr!=width) [handle skipBytes:inbpr-width];

		uint8 *rowptr=XeeImageDataRow(self,row);
		if(transparent) [pal convertIndexes:buffer count:width toARGB8:rowptr];
		else [pal convertIndexes:buffer count:width toRGB8:rowptr];

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

-(uint32)colourAtIndex:(int)index { if(index>=0&&index<256) return pal[index]; else return 0; }

-(BOOL)isTransparent { return istrans; }

-(uint32 *)colours { return pal; }

-(void)setColourAtIndex:(int)index red:(uint8)red green:(uint8)green blue:(uint8)blue
{
	[self setColourAtIndex:index red:red green:green blue:blue alpha:0xff];
}

-(void)setColourAtIndex:(int)index red:(uint8)red green:(uint8)green blue:(uint8)blue alpha:(uint8)alpha
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

-(void)convertIndexes:(uint8 *)indexes count:(int)count toRGB8:(uint8 *)dest
{
	while(count--)
	{
		uint32 col=pal[*indexes++];
		*dest++=XeeGetRFromARGB8(col);
		*dest++=XeeGetGFromARGB8(col);
		*dest++=XeeGetBFromARGB8(col);
	}
}

-(void)convertIndexes:(uint8 *)indexes count:(int)count toARGB8:(uint8 *)dest
{
	uint32 *destptr=(uint32 *)dest;
	while(count--) *destptr++=pal[*indexes++];
}

@end