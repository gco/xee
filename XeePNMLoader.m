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

	if(len>=3)
	if(head[0]=='P')
	if(head[1]>='1'&&head[1]<='6')
	if(isspace(head[2])) return YES;

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
		if(type<'0'||type>'6')return;

		int imgwidth=[self nextIntegerAfterWhiteSpace];
		int imgheight=[self nextIntegerAfterWhiteSpace];

		XeeImage *image=nil;

		int maxval;
		switch(type)
		{
			case '1':
				image=[[[XeeBitmapImage alloc] initWithType:XeeBitmapTypeLuma8 width:imgwidth height:imgheight] autorelease];
			break;

			case '2':
				maxval=[self nextIntegerAfterWhiteSpace];

				if(maxval<=255)
				image=[[[XeeBitmapImage alloc] initWithType:XeeBitmapTypeLuma8 width:imgwidth height:imgheight] autorelease];
				else
				image=[[[XeeBitmapImage alloc] initWithType:XeeBitmapTypeLuma16 width:imgwidth height:imgheight] autorelease];
			break;

			case '3':
				maxval=[self nextIntegerAfterWhiteSpace];

				if(maxval<=255)
				image=[[[XeeBitmapImage alloc] initWithType:XeeBitmapTypeRGB8 width:imgwidth height:imgheight] autorelease];
				else
				image=[[[XeeBitmapImage alloc] initWithType:XeeBitmapTypeRGB16 width:imgwidth height:imgheight] autorelease];
			break;

			case '4':
				image=[[[XeeBitmapRawImage alloc] initWithHandle:fh width:imgwidth height:imgheight] autorelease];
			break;

			case '5':
			{
				maxval=[self nextIntegerAfterWhiteSpace];

				int bitdepth=maxval>=256?16:8;
				image=[[[XeeRawImage alloc] initWithHandle:fh width:imgwidth height:imgheight
				depth:bitdepth colourSpace:XeeGreyRawColourSpace flags:0] autorelease];

				if(maxval!=255&&maxval!=65535)
				{
					float one=(float)((1<<bitdepth)-1)/(float)maxval;
					[(XeeRawImage *)image setZeroPoint:0 onePoint:one forChannel:0];
				}
			}
			break;

			case '6':
			{
				maxval=[self nextIntegerAfterWhiteSpace];

				int bitdepth=maxval>=256?16:8;
				image=[[[XeeRawImage alloc] initWithHandle:fh width:imgwidth height:imgheight
				depth:bitdepth colourSpace:XeeRGBRawColourSpace flags:0] autorelease];

				if(maxval!=255&&maxval!=65535)
				{
					float one=(float)((1<<bitdepth)-1)/(float)maxval;
					[(XeeRawImage *)image setZeroPoint:0 onePoint:one forChannel:0];
					[(XeeRawImage *)image setZeroPoint:0 onePoint:one forChannel:1];
					[(XeeRawImage *)image setZeroPoint:0 onePoint:one forChannel:2];
				}
			}
		}

		[self addSubImage:image];

		if([subimages count]==1) XeeImageLoaderHeaderDone();

		switch(type)
		{
			case '1':
			{
				CSHandle *fh=[self handle];
				uint8_t *data=[(XeeBitmapImage *)image data];
				int bytesperrow=[(XeeBitmapImage *)image bytesPerRow];

				for(int y=0;y<imgheight;y++)
				{
					uint8_t *dest=data+y*bytesperrow;
					for(int i=0;i<imgwidth;i++)
					{
						uint8_t val;
						do { val=[fh readUInt8]; }
						while(val!='0' && val!='1');

						if(val=='0') dest[i]=0;
						else dest[i]=255;
					}
					[(XeeBitmapImage *)image setCompletedRowCount:y+1];
					XeeImageLoaderYield();
				}
			}
			break;

			case '2':
			case '3':
			{
				int channels;
				if(type=='2') channels=1;
				else channels=3;

				uint8_t *data=[(XeeBitmapImage *)image data];
				int bytesperrow=[(XeeBitmapImage *)image bytesPerRow];

				for(int y=0;y<imgheight;y++)
				{
					uint8_t *dest=data+y*bytesperrow;
					for(int i=0;i<imgwidth*channels;i++)
					{
						int val=[self nextIntegerAfterWhiteSpace];
						if(maxval==255)
						{
							dest[i]=val;
						}
						else if(maxval<255)
						{
							dest[i]=(255*val)/maxval;
						}
						else
						{
							((uint16_t *)dest)[i]=(65535*val)/maxval;
						}
					}
					[(XeeBitmapImage *)image setCompletedRowCount:y+1];
					XeeImageLoaderYield();
				}
			}
			break;

			case '4':
			case '5':
			case '6':
				[self runLoaderOnSubImage:image];
			break;
		}
	}
}

-(int)nextIntegerAfterWhiteSpace
{
	char c;
	int val=0;

	do
	{
		c=[self nextCharacterSkippingComments];
		if(c<0) return -1;
	}
	while(isspace(c));

	do
	{
		if(c<'0'||c>'9') @throw @"Error parsing PNM header";
		val=val*10+c-'0';
		c=[self nextCharacterSkippingComments];
	} while(c>=0 && !isspace(c));

	return val;
}

-(int)nextCharacterSkippingComments
{
	CSHandle *fh=[self handle];
	if([fh atEndOfFile]) return -1;

	char c=[fh readUInt8];
	if(c!='#') return c;

	do
	{
		if([fh atEndOfFile]) return -1;
		c=[fh readUInt8];
	}
	while(c!='\n'&&c!='\r');

	if([fh atEndOfFile]) return -1;

	return [fh readUInt8];
}

/* TODO:
# In the raster, the sample values are "nonlinear." They are proportional to the intensity of the ITU-R Recommendation BT.709 red, green, and blue in the pixel, adjusted by the BT.709 gamma transfer function. (That transfer function specifies a gamma number of 2.2 and has a linear section for small intensities). A value of Maxval for all three samples represents CIE D65 white and the most intense color in the color universe of which the image is part (the color universe is all the colors in all images to which this image might be compared).

ITU-R Recommendation BT.709 is a renaming of the former CCIR Recommendation 709. When CCIR was absorbed into its parent organization, the ITU, ca. 2000, the standard was renamed. This document once referred to the standard as CIE Rec. 709, but it isn't clear now that CIE ever sponsored such a standard.

Note that another popular color space is the newer sRGB. A common variation on PPM is to subsitute this color space for the one specified. 
*/

@end
