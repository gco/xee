#import "XeeBitmapRawImage.h"


@implementation XeeBitmapRawImage

-(id)initWithHandle:(CSHandle *)fh width:(int)w height:(int)h parentImage:(XeeMultiImage *)parent
{
	return [self initWithHandle:fh width:w height:h bytesPerRow:(w+7)/8 parentImage:parent];
}

-(id)initWithHandle:(CSHandle *)fh width:(int)w height:(int)h bytesPerRow:(int)bpr parentImage:(XeeMultiImage *)parent
{
	if(self=[super initWithParentImage:parent])
	{
		handle=[fh retain];
		width=w;
		height=h;
		bytesperfilerow=bpr;
		buffer=NULL;
	}
	return self;
}

-(void)dealloc
{
	free(buffer);
	//[handle release];
	[super dealloc];
}

-(SEL)initLoader
{
	if(!handle) return NULL;

	if(![self allocWithType:XeeBitmapTypeLuma8 width:width height:height]) return NULL;

	buffer=malloc(bytesperfilerow);
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
		[handle readBytes:bytesperfilerow toBuffer:buffer];

		uint8 *rowptr=XeeImageDataRow(self,row);
		for(int x=0;x<width;x++)
		{
			if(buffer[x>>3]&(0x80>>(x&7))) *rowptr++=0x00;
			else *rowptr++=0xff;
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
