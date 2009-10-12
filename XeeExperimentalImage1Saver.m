#import "XeeExperimentalImage1Saver.h"
#import "XeeBitmapImage.h"

#import <XADMaster/CSFileHandle.h>

static void f(int n,int *xp,int *yp);
static int fi(int x,int y);

@implementation XeeExperimentalImage1Saver

+(BOOL)canSaveImage:(XeeImage *)img
{
	return YES;
/*	CGImageRef cgimage=[img createCGImage];
	if(!img) return NO;
	int depth=CGImageGetBitsPerComponent(cgimage);
	int info=CGImageGetBitmapInfo(cgimage);
	CGImageRelease(cgimage);
	return depth==8;*/
}

-(id)initWithImage:(XeeImage *)img
{
	if(self=[super initWithImage:img])
	{
	}
	return self;
}

-(NSString *)format { return @"Xee Experimental Image Format 1"; }

-(NSString *)extension { return @"xei1"; }

-(BOOL)save:(NSString *)filename
{
	BOOL res=NO;
	CGImageRef cgimage=[image createCGImage];
	if(cgimage)
	{
		int pixelwidth=CGImageGetWidth(cgimage);
		int pixelheight=CGImageGetHeight(cgimage);

		XeeBitmapImage *bmimage=[[[XeeBitmapImage alloc] initWithType:XeeBitmapTypeNRGB8 width:pixelwidth height:pixelheight] autorelease];

		if(image)
		{
			CGContextRef cgcontext=[bmimage createCGContext];
			if(cgcontext)
			{
				CGContextDrawImage(cgcontext,CGRectMake(0,0,pixelwidth,pixelheight),cgimage);
				CGContextRelease(cgcontext);

				CSFileHandle *fh=[CSFileHandle fileHandleForWritingAtPath:filename];

				if(fh)
				{
					[fh writeInt32BE:'XEI1'];
					[fh writeInt32BE:pixelwidth];
					[fh writeInt32BE:pixelheight];

					uint8_t *data=[bmimage data];
					int bpr=[bmimage bytesPerRow];
					int left,n,x,y;
					uint8_t prev;

					left=pixelwidth*pixelheight;
					n=0;
					prev=0;
					while(left)
					{
						f(n++,&x,&y);
						if(x<pixelwidth&y<pixelheight)
						{
							uint32_t *row=(uint32_t *)(data+y*bpr);
							uint8_t val=XeeGetRFromNRGB8(row[x]);
							[fh writeUInt8:(uint8_t)(val-prev)];
							prev=val;
							left--;
						}
					}

					left=pixelwidth*pixelheight;
					n=0;
					prev=0;
					while(left)
					{
						f(n++,&x,&y);
						if(x<pixelwidth&y<pixelheight)
						{
							uint32_t *row=(uint32_t *)(data+y*bpr);
							uint8_t val=XeeGetGFromNRGB8(row[x]);
							[fh writeUInt8:(uint8_t)(val-prev)];
							prev=val;
							left--;
						}
					}

					left=pixelwidth*pixelheight;
					n=0;
					prev=0;
					while(left)
					{
						f(n++,&x,&y);
						if(x<pixelwidth&y<pixelheight)
						{
							uint32_t *row=(uint32_t *)(data+y*bpr);
							uint8_t val=XeeGetBFromNRGB8(row[x]);
							[fh writeUInt8:(uint8_t)(val-prev)];
							prev=val;
							left--;
						}
					}

					res=YES;
				}
			}
		}

		CGImageRelease(cgimage);
	}
	return res;
}

@end


static int transform_table[4][4]={{0,1,2,3},{0,2,1,3},{3,2,1,0},{3,1,2,0}};
static int locations[4]={0,1,3,2};

static void f(int n,int *xp,int *yp)
{
   static int transforms[4]={1,0,0,3};
   int x=0,y=0;
   int trans=0;
   for(int i=30;i>=0;i-=2)
   {
      int m=(n>>i)&3;
      int bits=transform_table[trans][locations[m]];

      x=(x<<1)|((bits>>1)&1);
      y=(y<<1)|(bits&1);

      trans^=transforms[m];
   }
   *xp=x; *yp=y;
}

static int fi(int x,int y)
{
   static int transforms[4]={1,0,3,0};
   int n=0;
   int trans=0;
   for(int i=15;i>=0;i--)
   {
      int m=transform_table[trans][((y>>i)&1)|(((x>>i)&1)<<1)];
      int bits=locations[m];

      n=(n<<2)|bits;

      trans^=transforms[m];
   }
   return n;
}
