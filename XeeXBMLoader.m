#import "XeeXBMLoader.h"

#import <XADMaster/XADRegex.h>



@implementation XeeXBMImage

+(NSArray *)fileTypes
{
	return [NSArray arrayWithObject:@"xbm"];
}

+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;
{
	const unsigned char *head=[block bytes];
	int len=[block length];
	if(len>=8&&!memcmp(head,"#define ",8))
	{
		return [[[[NSString alloc] initWithData:block encoding:NSASCIIStringEncoding] autorelease]
		matchedByPattern:@"^#define [^_ \t\r\n]+_(width|height|[xy]_hot) [0-9]+"];
	}

	return NO;

}

-(void)load
{
	CSHandle *fh=[self handle];

	BOOL shorts;

	for(;;)
	{
		NSString *line=[fh readLineWithEncoding:NSASCIIStringEncoding];
		NSArray *matches;

		if(matches=[line substringsCapturedByPattern:@"^#define( [^ ]+_| )([^ ]+) ([0-9]+)"])
		{
			NSString *name=[matches objectAtIndex:2];
			int value=[[matches objectAtIndex:3] intValue];

			if([name isEqual:@"width"]) width=value;
			else if([name isEqual:@"height"]) height=value;
		}
		else if(matches=[line substringsCapturedByPattern:@"^static short( [^ ]+_| )([^ ]+)\\[\\] = {"])
		{
			shorts=YES;
			break;
		}
		else if((matches=[line substringsCapturedByPattern:@"^static unsigned char( [^ ]+_| )([^ ]+)\\[\\] = {"])
		||(matches=[line substringsCapturedByPattern:@"^static char( [^ ]+_| )([^ ]+)\\[\\] = {"]))
		{
			shorts=NO;
			break;
		}
	}

	if(!width||!height) return;

	[self setDepthBitmap];
	[self setFormat:@"XBM"];

	[self allocWithType:XeeBitmapTypeLuma8 width:width height:height];

	int shortsperrow=(width+15)/16;
	int intsperrow=shortsperrow*(shorts?1:2);
	int pixelsperint=shorts?16:8;

	for(int y=0;y<height;y++)
	{
		uint8_t *row=data+y*bytesperrow;
		int x=0;

		for(int i=0;i<intsperrow;i++)
		{
			int val=[self nextInteger];
			for(int j=0;j<pixelsperint;j++)
			if(x++<width) *row++=(val&(1<<j))?0:0xff;
		}

		[self setCompletedRowCount:y+1];
		XeeImageLoaderYield();
	}

	XeeImageLoaderDone(YES);
}

-(int)nextInteger
{
	CSHandle *fh=[self handle];
	int val=0;

	for(;;)
	{
		char c=[fh readUInt8];
		if(c==','||c=='}') return val;
		else if(c>='0'&&c<='9') val=val*16+c-'0';
		else if(c>='A'&&c<='F') val=val*16+c-'A'+10;
		else if(c>='a'&&c<='f') val=val*16+c-'a'+10;
	}
}

@end
