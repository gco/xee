#import "XeePNMLoader.h"
#import "XeeBitmapRawImage.h"
#import "XeeRawImage.h"

@implementation XeePNMImage

+(NSArray *)fileTypes
{
	return [NSArray arrayWithObjects:@"pbm",@"pgm",@"ppm",@"pnm",nil];
}

+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;
{
	const unsigned char *head=[block bytes];
	int len=[block length];

	if(len>=3&&head[0]=='P'&&(head[1]=='4'||head[1]=='5'||head[1]=='6')&&isspace(head[2])) return YES;

	return NO;

}

-(void)load
{
	CSHandle *fh=[self handle];

	[self setFormat:@"PNM"];

	for(;;)
	{
		char first;
		@try { first=[fh readUInt8]; } @catch(id e) { first=0; }

		if(first!='P')
		{
			if([subimages count]) XeeImageLoaderDone(YES);
			return;
		}

		int type=[fh readUInt8];
		if(type!='4'&&type!='5'&&type!='6') return;

		int imgwidth=[self nextIntegerAfterWhiteSpace];
		int imgheight=[self nextIntegerAfterWhiteSpace];

		XeeImage *image=nil;

		if(type=='4')
		{
			image=[[[XeeBitmapRawImage alloc] initWithHandle:fh width:imgwidth height:imgheight] autorelease];
		}
		else
		{
			int maxval=[self nextIntegerAfterWhiteSpace];
			int colourspace=type=='5'?XeeGreyRawColourSpace:XeeRGBRawColourSpace;
			int bitdepth=maxval>=256?16:8;

			image=[[[XeeRawImage alloc] initWithHandle:fh width:imgwidth height:imgheight
			depth:bitdepth colourSpace:colourspace flags:0] autorelease];

			if(maxval!=255&&maxval!=65535)
			{
				float one=(float)((1<<bitdepth)-1)/(float)maxval;
				[(XeeRawImage *)image setZeroPoint:0 onePoint:one forChannel:0];
				if(type=='6')
				{
					[(XeeRawImage *)image setZeroPoint:0 onePoint:one forChannel:1];
					[(XeeRawImage *)image setZeroPoint:0 onePoint:one forChannel:2];
				}
			}
		}

		[self addSubImage:image];

		if([subimages count]==1) XeeImageLoaderHeaderDone();

		[self runLoaderOnSubImage:image];
	}
}

-(int)nextIntegerAfterWhiteSpace
{
	char c;
	int val=0;

	do { c=[self nextCharacterSkippingComments]; }
	while(isspace(c));

	do
	{
		if(c<'0'||c>'9') @throw @"Error parsing PNM header";
		val=val*10+c-'0';
		c=[self nextCharacterSkippingComments];
	} while(!isspace(c));

	return val;
}

-(char)nextCharacterSkippingComments
{
	CSHandle *fh=[self handle];
	char c=[fh readUInt8];

	if(c!='#') return c;

	do { c=[fh readUInt8]; }
	while(c!='\n'&&c!='\r');

	return [fh readUInt8];
}

/* TODO:
# In the raster, the sample values are "nonlinear." They are proportional to the intensity of the ITU-R Recommendation BT.709 red, green, and blue in the pixel, adjusted by the BT.709 gamma transfer function. (That transfer function specifies a gamma number of 2.2 and has a linear section for small intensities). A value of Maxval for all three samples represents CIE D65 white and the most intense color in the color universe of which the image is part (the color universe is all the colors in all images to which this image might be compared).

ITU-R Recommendation BT.709 is a renaming of the former CCIR Recommendation 709. When CCIR was absorbed into its parent organization, the ITU, ca. 2000, the standard was renamed. This document once referred to the standard as CIE Rec. 709, but it isn't clear now that CIE ever sponsored such a standard.

Note that another popular color space is the newer sRGB. A common variation on PPM is to subsitute this color space for the one specified. 
*/

@end
