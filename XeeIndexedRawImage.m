#import "XeeIndexedRawImage.h"


@implementation XeeIndexedRawImage

-(id)initWithHandle:(CSHandle *)fh width:(int)framewidth height:(int)frameheight
palette:(XeePalette *)palette parentImage:(XeeMultiImage *)parent
{
	return [self initWithHandle:fh width:framewidth height:frameheight
	palette:palette bytesPerRow:0 parentImage:parent];
}

-(id)initWithHandle:(CSHandle *)fh width:(int)framewidth height:(int)frameheight
palette:(XeePalette *)palette bytesPerRow:(int)bytesperinputrow parentImage:(XeeMultiImage *)parent
{
	if(self=[super initWithParentImage:parent])
	{
		handle=[fh retain];
		pal=[palette retain];
		width=framewidth;
		height=frameheight;
		inbpr=bytesperinputrow;
	}
	return self;
}

-(void)dealloc
{
	//[handle release];
	[pal release];
	[super dealloc];
}

-(SEL)initLoader
{
	if(!handle) return NULL;

	if(![self allocWithType:[pal isTransparent]?XeeBitmapTypeARGB8:XeeBitmapTypeRGB8 width:width height:height]) return NULL;

	buffer=malloc(width);
	if(!buffer) return NULL;

	row=0;
	return @selector(load);
}


-(void)deallocLoader
{
	[handle release];
	handle=nil;
	free(buffer);
	buffer=NULL;
}

-(SEL)load
{
	while(!stop)
	{
		[handle readBytes:width toBuffer:buffer];
		if(inbpr&&inbpr!=width) [handle skipBytes:inbpr-width];

		uint8 *rowptr=XeeImageDataRow(self,row);
		if(transparent) [pal convertIndexes:buffer count:width toARGB8:rowptr];
		else [pal convertIndexes:buffer count:width toRGB8:rowptr];

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



@implementation XeePalette

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