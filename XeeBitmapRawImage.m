#import "XeeBitmapRawImage.h"


@implementation XeeBitmapRawImage

-(id)initWithHandle:(CSHandle *)fh width:(int)w height:(int)h
{
	return [self initWithHandle:fh width:w height:h bytesPerRow:(w+7)/8];
}

-(id)initWithHandle:(CSHandle *)fh width:(int)w height:(int)h bytesPerRow:(int)bpr
{
	if(self=[super initWithHandle:fh])
	{
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
	[super dealloc];
}

-(void)load
{
	if(!handle) XeeImageLoaderDone(NO);
	XeeImageLoaderHeaderDone();

	if(![self allocWithType:XeeBitmapTypeLuma8 width:width height:height]) XeeImageLoaderDone(NO);

	buffer=malloc(bytesperfilerow);
	if(!buffer) XeeImageLoaderDone(NO);

	for(int row=0;row<height;row++)
	{
		[handle readBytes:bytesperfilerow toBuffer:buffer];

		uint8 *rowptr=XeeImageDataRow(self,row);
		for(int x=0;x<width;x++)
		{
			if(buffer[x>>3]&(0x80>>(x&7))) *rowptr++=0x00;
			else *rowptr++=0xff;
		}

		[self setCompletedRowCount:row+1];
		XeeImageLoaderYield();
	}

	free(buffer);
	buffer=NULL;

	XeeImageLoaderDone(YES);
}

@end
