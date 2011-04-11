#import "XeeImageThumbnailing.h"

@implementation XeeImage (Thumbnailing)

-(CGImageRef)makeRGBThumbnailOfSize:(int)size
{
	CGImageRef cgimage=[self createCGImage];
	CGImageRef thumbnail=NULL;

	if(cgimage)
	{
		int cgwidth=CGImageGetWidth(cgimage);
		int cgheight=CGImageGetHeight(cgimage);
		int thumbwidth,thumbheight;

		if(cgwidth>cgheight)
		{
			thumbwidth=size;
			thumbheight=(size*cgheight)/cgwidth;
		}
		else
		{
			thumbwidth=(size*cgwidth)/cgheight;
			thumbheight=size;
		}

		CFMutableDataRef thumbdata=CFDataCreateMutable(kCFAllocatorDefault,thumbwidth*thumbheight*4);
		if(thumbdata)
		{
			CGContextRef context=CGBitmapContextCreate(CFDataGetMutableBytePtr(thumbdata),
			thumbwidth,thumbheight,8,thumbwidth*4,CGImageGetColorSpace(cgimage),
			kCGImageAlphaPremultipliedLast);
			if(context)
			{
				CGContextSetInterpolationQuality(context,kCGInterpolationHigh);
				CGContextDrawImage(context,CGRectMake(0,0,thumbwidth,thumbheight),cgimage);
				thumbnail=CGBitmapContextCreateImage(context);

				CGContextRelease(context);
			}
			CFRelease(thumbdata);
		}
		CGImageRelease(cgimage);
	}
	return thumbnail;
}

-(NSData *)makeJPEGThumbnailOfSize:(int)size maxBytes:(int)maxbytes
{
	CGImageRef thumbnail=[self makeRGBThumbnailOfSize:size];
	if(!thumbnail) return NULL;

	CFMutableDataRef thumbdata=NULL;
	int quality=60;
	do
	{
		CFMutableDataRef data=CFDataCreateMutable(kCFAllocatorDefault,0);
		if(data)
		{
			CGImageDestinationRef dest=CGImageDestinationCreateWithData(data,
			kUTTypeJPEG,1,NULL);
			if(dest)
			{
				NSDictionary *options=[NSDictionary dictionaryWithObjectsAndKeys:
					[NSNumber numberWithFloat:(float)quality/100.0],(NSString *)kCGImageDestinationLossyCompressionQuality,
				nil];

				CGImageDestinationAddImage(dest,thumbnail,(CFDictionaryRef)options);

				if(CGImageDestinationFinalize(dest))
				{
					if(CFDataGetLength(data)<maxbytes)
					{
						thumbdata=(CFMutableDataRef)CFRetain(data);
					}
				}
				CFRelease(dest);
			}
			CFRelease(data);
		}
		quality-=10;
	}
	while(!thumbdata&&quality>0);

	if(thumbdata) return [(id)thumbdata autorelease];

	return nil;
}

@end
