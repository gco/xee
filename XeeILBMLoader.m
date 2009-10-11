#import "XeeILBMLoader.h"
#import "XeeIFFHandle.h"



#define ALPHA_MASK XeeMakeARGB8(0xff,0,0,0)
#define R_MASK XeeMakeARGB8(0,0xff,0,0)
#define G_MASK XeeMakeARGB8(0,0,0xff,0)
#define B_MASK XeeMakeARGB8(0,0,0,0xff)
#define COLOR_MASK XeeMakeARGB8(0,0xff,0xff,0xff)
#define NOTR_MASK XeeMakeARGB8(0xff,0,0xff,0xff)
#define NOTG_MASK XeeMakeARGB8(0xff,0xff,0,0xff)
#define NOTB_MASK XeeMakeARGB8(0xff,0xff,0xff,0)
#define OCS_MASK XeeMakeARGB8(0,0x0f,0x0f,0x0f)
#define EHB_SHIFT_MASK XeeMakeARGB8(0,0x7f,0x7f,0x7f)
#define EMPTY_COLOUR XeeMakeARGB8(0x80,0,0,0)
#define BLACK_COLOUR XeeMakeARGB8(0xff,0,0,0)

@implementation XeeILBMImage

+(NSArray *)fileTypes
{
	return [NSArray arrayWithObjects:@"iff",@"ilbm",@"lbm",@"'ILBM'",nil]; //@"'PNG '",@"'PNGf'",nil];
}

+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes
{
	uint8_t *header=(uint8_t *)[block bytes];
	if([block length]>12&&XeeBEUInt32(header)=='FORM'&&XeeBEUInt32(header+8)=='ILBM') return YES;
	return NO;
}

-(id)init
{
	if(self=[super init])
	{
		image=NULL;
		mask=NULL;
		iff=nil;
		ranges=[[NSMutableArray array] retain];
		comments=nil;
		clock=0;
		animationtimer=nil;
	}
	return self;
}

-(void)dealloc
{
	if(image) free(image);
	if(mask) free(mask);

	[ranges release];
	[animationtimer release];

	[super dealloc];
}

-(SEL)initLoader
{
	iff=[[XeeIFFHandle IFFHandleWithPath:[self filename] fileType:'ILBM'] retain];
	if(!iff) return NULL;

	ham=ham8=ehb=ocscol=transparency=NO;

	[self setFormat:@"IFF-ILBM"];

	return @selector(loadChunk);
}

-(void)deallocLoader
{
	[iff release];
}

-(SEL)loadChunk
{
	int num,viewmode,col;
	XeeILBMRange *range;

	switch([iff nextChunk])
	{
		case 'BMHD':
			realwidth=[iff readUInt16];
			realheight=[iff readUInt16];
			[iff skipBytes:4]; // x,y
			planes=[iff readUInt8];
			masking=[iff readUInt8];
			compression=[iff readUInt8];
			[iff skipBytes:1]; // pad1
			trans=[iff readUInt16];
			xasp=[iff readUInt8];
			yasp=[iff readUInt8];
			// pagewidth, pageheight;

			if(planes>8&&planes!=24) return NULL;

			if(xasp>yasp) { xscale=(float)xasp/(float)yasp+0.5; yscale=1; }
			else { yscale=(float)yasp/(float)xasp+0.5; xscale=1; }

			if(xscale>4) xscale=4;
			if(yscale>4) yscale=4;

			if(planes<=8)
			{
				width=realwidth*xscale;
				height=realheight*yscale;
			}
			else // no scaling support for 24 bit
			{
				width=realwidth;
				height=realheight;
			}

			rowbytes=2*((realwidth+15)/16);

			//printf("w:%d h:%d planes:%d mask:%d comp:%d transp:%d xasp:%d yasp:%d xscale:%d yscale:%d\n",width,height,planes,masking,compression,trans,xasp,yasp,xscale,yscale);
		break;

		case 'CMAP':
			num=[iff chunkSize]/3;
			if(num>256) num=256;

			col=0;

			for(int i=0;i<num;i++)
			{
				uint8_t r=[iff readUInt8];
				uint8_t g=[iff readUInt8];
				uint8_t b=[iff readUInt8];
				palette[i]=XeeMakeARGB8(0xff,r,g,b);
				if(i<32) col|=palette[i];
			}

			if((col&OCS_MASK)==0) ocscol=YES;
		break;

		case 'DEST':
			//printf("warning: image has DEST chunk\n");
		break;

		case 'FVER': [self addCommentWithLabel:@"Version" data:[iff chunkContents]]; break;
		case 'ANNO': [self addCommentWithLabel:@"Annotation" data:[iff chunkContents]]; break;
		case 'AUTH': [self addCommentWithLabel:@"Author" data:[iff chunkContents]]; break;
		case 'CHRS': [self addCommentWithLabel:@"" data:[iff chunkContents]]; break;
		case 'NAME': [self addCommentWithLabel:@"Name" data:[iff chunkContents]]; break;
		case 'TEXT': [self addCommentWithLabel:@"" data:[iff chunkContents]]; break;
		case '(c) ': [self addCommentWithLabel:@"Copyright" data:[iff chunkContents]]; break;

		case 'CRNG':
		case 'DRNG':
		case 'CCRT':
			range=[[[XeeILBMRange alloc] initWithIFF:iff image:self] autorelease];
			if(range) [ranges addObject:range];
		break;

		case 'CAMG':
			viewmode=[iff readUInt32];

			if((viewmode&0x800)&&(planes==5||planes==6)) ham=YES;
			else if((viewmode&0x800)&&(planes==7||planes==8)) ham8=YES;
			else if(viewmode&0x80) ehb=YES;
		break;

		case 'BODY':
			if(ham)
			{
				[self setDepth:@"Amiga HAM"];
				[self setDepthIconName:@"depth_amiga"];
			}	
			else if(ham8)
			{
				[self setDepth:@"Amiga HAM8"];
				[self setDepthIconName:@"depth_amiga"];
			}
			else if(ehb)
			{
				[self setDepth:@"Amiga EHB"];
				[self setDepthIconName:@"depth_amiga"];
			}
			else if(planes==24) [self setDepthRGB:24];
			else [self setDepthIndexed:1<<planes];

			if(ocscol&&(planes<=5||ehb||ham)) // fix 4-bit OCS palette
			{
				for(int i=0;i<32;i++) palette[i]|=(palette[i]>>4)&OCS_MASK;
			}

			if(ehb) // fix EHB palette
			{
				for(int i=0;i<32;i++) palette[i+32]=((palette[i]>>1)&EHB_SHIFT_MASK)|ALPHA_MASK;
			}

			if(masking)
			{
				int col=palette[trans];

				[self setBackgroundColor:[NSColor
				colorWithCalibratedRed:(float)XeeGetRFromARGB8(col)/255.0
				green:(float)XeeGetGFromARGB8(col)/255.0
				blue:(float)XeeGetBFromARGB8(col)/255.0
				alpha:1]];

				if(masking==1&&[[NSUserDefaults standardUserDefaults] boolForKey:@"ilbmUseMask"])
				{
					transparency=YES;
				}
				else if(masking==2&&[[NSUserDefaults standardUserDefaults] boolForKey:@"ilbmUseTransparentColour"])
				{
					palette[trans]&=COLOR_MASK;
					transparency=YES;
				}
			}

			[ranges makeObjectsPerformSelector:@selector(setup) withObject:nil];

			return @selector(startLoadingImage);

		case 0:
			return NULL;
	}

	return @selector(loadChunk);
}

-(SEL)startLoadingImage
{
	int type;
	if(transparency) type=XeeBitmapTypeARGB8;
	else type=XeeBitmapTypeNRGB8;
	if(![self allocWithType:type width:width height:height]) return NULL;

	if(masking==1)
	{
		mask=malloc(rowbytes*realheight);
		if(!mask) return NULL;
	}

	current_line=0;

	if(planes<=8)
	{
		image=malloc(realwidth*realheight);
		if(!image) return NULL;
		memset(image,0,realwidth*realheight);

		return @selector(loadPaletteImage);
	}
	else return @selector(loadRGBImage);
}

-(SEL)loadPaletteImage
{
	uint8_t *imageline=image+current_line*realwidth;
	uint8_t row[rowbytes];

	@try
	{
		for(int p=0;p<planes;p++)
		{
			[self readRow:row];

			for(int x=0;x<realwidth;x++)
			{
				imageline[x]|=((row[x>>3]>>((x&7)^7))&1)<<p;
			}
		}

		if(masking==1)
		{
			[self readRow:mask+current_line*rowbytes];
		}
	}
	@catch(id e)
	{
		[self renderImage];
		[self setCompleted];
		@throw;
	}

	current_line++;
	if(current_line>=realheight)
	{
		loaded=YES;
		[self renderImage];
		[self setCompleted];
		return @selector(loadChunk);
	}

	return @selector(loadPaletteImage);
}

-(SEL)loadRGBImage
{
	int *imageline=(int *)(data+current_line*bytesperrow);
	uint8_t row[rowbytes];

	for(int i=0;i<width;i++) imageline[i]=0xff000000;

	for(int p=0;p<8;p++)
	{
		[self readRow:row];
		for(int i=0;i<width;i++)
		{
			int r=((row[i>>3]>>((i&7)^7))&1)<<(7-(p^7));
			imageline[i]|=XeeMakeARGB8(0,r,0,0);
		}
	}

	for(int p=0;p<8;p++)
	{
		[self readRow:row];
		for(int i=0;i<width;i++)
		{
			int g=((row[i>>3]>>((i&7)^7))&1)<<(7-(p^7));
			imageline[i]|=XeeMakeARGB8(0,0,g,0);
		}
	}

	for(int p=0;p<8;p++)
	{
		[self readRow:row];
		for(int i=0;i<width;i++)
		{
			int b=((row[i>>3]>>((i&7)^7))&1)<<(7-(p^7));
			imageline[i]|=XeeMakeARGB8(0,0,0,b);
		}
	}

	if(masking==1)
	{
		[self readRow:row];
		for(int i=0;i<width;i++)
		{
			if(!((row[i>>3]>>((i&7)^7))&1)) imageline[i]&=COLOR_MASK;
		}
	}

	current_line++;
	[self setCompletedRowCount:current_line];

	if(current_line>=realheight)
	{
		loaded=YES;
		return @selector(loadChunk);
	}

	return @selector(loadRGBImage);
}

-(void)readRow:(uint8_t *)row
{
	if(compression==0)
	{
		for(int i=0;i<rowbytes;i++) row[i]=[iff readUInt8];
	}
	else
	{
		int count=0;
		while(count<rowbytes)
		{
			int num=[iff readUInt8];

			if(num<128)
			{
				num+=1;

				for(int i=0;i<num;i++)
				{
					if(count<rowbytes) row[count]=[iff readUInt8];
					count++;
				}
			}
			else if(num>128)
			{
				uint8_t b=[iff readUInt8];

				num=257-num;

				if(count+num>rowbytes) num=rowbytes-count;
				for(int i=0;i<num;i++) row[count++]=b;
			}
		}
	}
}

-(void)renderImage
{
	if(planes==24) return;

	if(ham)
	{
		for(int y=0;y<realheight;y++)
		for(int sub_y=0;sub_y<yscale;sub_y++)
		{
			uint8_t *srcline=image+y*realwidth;
			int *destline=(int *)(data+(y*yscale+sub_y)*bytesperrow);
			uint32_t hold=palette[0];

			for(int x=0;x<realwidth;x++)
			{
				int pixel=*srcline++;
				int cmd=pixel>>4;
				int val=pixel&0x0f;
				int col=(val<<4)|val;

				switch(cmd)
				{
					case 0: hold=palette[val]; break;
					case 1: hold=(hold&NOTB_MASK)|XeeMakeARGB8(0,0,0,col); break;
					case 2: hold=(hold&NOTR_MASK)|XeeMakeARGB8(0,col,0,0); break;
					case 3: hold=(hold&NOTG_MASK)|XeeMakeARGB8(0,0,col,0); break;
				}

				for(int sub_x=0;sub_x<xscale;sub_x++) *destline++=hold;
			}
		}
	}
	else if(ham8)
	{
		for(int y=0;y<realheight;y++)
		for(int sub_y=0;sub_y<yscale;sub_y++)
		{
			uint8_t *srcline=image+y*realwidth;
			int *destline=(int *)(data+(y*yscale+sub_y)*bytesperrow);
			uint32_t hold=palette[0];

			for(int x=0;x<realwidth;x++)
			{
				int pixel=*srcline++;
				int cmd=pixel>>6;
				int val=pixel&0x3f;
				int col=(val<<2)|((val&0x30)>>4);

				switch(cmd)
				{
					case 0: hold=palette[val]; break;
					case 1: hold=(hold&NOTB_MASK)|XeeMakeARGB8(0,0,0,col); break;
					case 2: hold=(hold&NOTR_MASK)|XeeMakeARGB8(0,col,0,0); break;
					case 3: hold=(hold&NOTG_MASK)|XeeMakeARGB8(0,0,col,0); break;
				}

				for(int sub_x=0;sub_x<xscale;sub_x++) *destline++=hold;
			}
		}
	}
	else
	{
		for(int y=0;y<realheight;y++)
		for(int sub_y=0;sub_y<yscale;sub_y++)
		{
			uint8_t *srcline=image+y*realwidth;
			int *destline=(int *)(data+(y*yscale+sub_y)*bytesperrow);

			for(int x=0;x<realwidth;x++)
			{
				uint32_t col=palette[*srcline++];
				for(int sub_x=0;sub_x<xscale;sub_x++) *destline++=col;
			}
		}
	}

	if(masking==1&&[[NSUserDefaults standardUserDefaults] boolForKey:@"ilbmUseMask"])
	{
		for(int y=0;y<realheight;y++)
		for(int sub_y=0;sub_y<yscale;sub_y++)
		{
			uint8_t *maskline=mask+y*rowbytes;
			int *destline=(int *)(data+(y*yscale+sub_y)*bytesperrow);

			for(int x=0;x<realwidth;x++)
			{
				if(!((maskline[x>>3]>>((x&7)^7))&1))
				{
					for(int sub_x=0;sub_x<xscale;sub_x++) destline[sub_x]&=COLOR_MASK;
				}
				destline+=xscale;
			}
		}
	}
}

-(void)addCommentWithLabel:(NSString *)label data:(NSData *)commentdata
{
	if(!comments)
	{
		comments=[NSMutableArray array];
		[properties addObject:[XeePropertyItem itemWithLabel:
		NSLocalizedString(@"File comments",@"File comments section title")
		value:comments identifier:@"common.comments"]];
	}

	[comments addObject:[XeePropertyItem itemWithLabel:label
	value:[[[NSString alloc] initWithData:commentdata encoding:NSISOLatin1StringEncoding]
	autorelease]]];

	[self triggerPropertyChangeAction];
}

-(uint32_t *)palette { return palette; }




-(BOOL)animated { return [ranges count]?YES:NO; }

-(void)setAnimating:(BOOL)animating
{
	if(![self animated]) return;

	if(animating)
	{
		if(!animationtimer)
		{
			animationtimer=[[NSTimer scheduledTimerWithTimeInterval:1.0/60.0 target:self selector:@selector(animate:) userInfo:nil repeats:YES] retain];
		}
	}
	else
	{
		if(animationtimer)
		{
			[animationtimer invalidate];
			[animationtimer release];
			animationtimer=nil;
		}
	}
}

-(BOOL)animating { return animationtimer?YES:NO; }

-(void)animate:(NSTimer *)timer
{
	clock++;

	NSEnumerator *enumerator=[ranges objectEnumerator];
	XeeILBMRange *range;
	BOOL triggered=NO;

	while(range=[enumerator nextObject])
	{
		if([range triggerCheck:(float)clock/60.0]) triggered=YES;
	}

	if(triggered)
	{
		[self renderImage];
		[self invalidate];
	}
}




@end



@implementation XeeILBMRange

-(id)initWithIFF:(XeeIFFHandle *)iff image:(XeeILBMImage *)img;
{
	if(self=[super init])
	{
		num=0;
		colours=NULL;
		indexes=NULL;
		image=img;

		switch([iff chunkID])
		{
			case 'CRNG':
			{
				[iff readUInt16]; // pad1
				int rate=[iff readUInt16];
				int flags=[iff readUInt16];
				int low=[iff readUInt8];
				int high=[iff readUInt8];

				if((flags&1)&&rate&&low<high)
				{
					if([self allocBuffers:high-low+1])
					{
						next=interval=16384.0/(float)rate/60.0;

						[self setIndexesFrom:low to:high reverse:(flags&2)?YES:NO];

						return self;
					}
				}
			}
			break;

			case 'CCRT':
			{
				int dir=[iff readUInt16];
				int start=[iff readUInt8];
				int end=[iff readUInt8];
				int secs=[iff readUInt32];
				int micros=[iff readUInt32];

				if((dir==1||dir==2)&&start<end)
				{
					if([self allocBuffers:end-start+1])
					{
						next=interval=(float)secs+(float)micros/1000000.0;

						[self setIndexesFrom:start to:end reverse:dir==2]; // unsure if this should be ==2 or ==1.

						return self;
					}
				}
			}
			break;

			case 'DRNG':
			{
				int min=[iff readUInt8];
				int max=[iff readUInt8];
				int rate=[iff readUInt16]*100;
				int flags=[iff readUInt16];
				int ntrue=[iff readUInt8];
				int nregs=[iff readUInt8];

				//printf("DRNG min:%d max:%d rate:%x flags:%d ntrue:%d nregs:%d\n",min,max,rate,flags,ntrue,nregs);

				if((flags&1)&&rate&&min<max)
				{
					if([self allocBuffers:max-min+1])
					{
						for(int i=0;i<ntrue;i++)
						{
							uint8_t cell=[iff readUInt8];
							uint8_t r=[iff readUInt8];
							uint8_t g=[iff readUInt8];
							uint8_t b=[iff readUInt8];

							if(cell>=min&&cell<=max) colours[cell-min]=XeeMakeARGB8(0xff,r,g,b);
						}

						for(int i=0;i<nregs;i++)
						{
							uint8_t cell=[iff readUInt8];
							uint8_t index=[iff readUInt8];

							if(cell>=min&&cell<=max) indexes[cell-min]=index;
						}

						next=interval=16384.0/(float)rate/60.0;

						return self;
					}
				}
			}
			break;
		}

		[self release];
	}
	return nil;
}

-(void)dealloc
{
	if(colours) free(colours);
	if(indexes) free(indexes);

	[super dealloc];
}

-(BOOL)allocBuffers:(int)length
{
	if(colours) free(colours);
	if(indexes) free(indexes);

	colours=malloc(sizeof(uint32_t)*length);
	indexes=malloc(sizeof(int)*length);

	if(colours&&indexes)
	{
		num=length;

		for(int i=0;i<num;i++)
		{
			colours[i]=EMPTY_COLOUR;
			indexes[i]=-1;
		}

		return YES;
	}
	else
	{
		num=0;
		return NO;
	}
}

-(void)setIndexesFrom:(int)start to:(int)end reverse:(BOOL)reverse
{
	if(reverse)
	for(int i=0;i<=end-start;i++) indexes[i]=i+start;
	else
	for(int i=0;i<=end-start;i++) indexes[i]=end-i;
}

-(void)setup
{
	uint32_t *palette=[image palette];

	for(int i=0;i<num;i++)
	{
		if(colours[i]==EMPTY_COLOUR&&indexes[i]>=0) colours[i]=palette[indexes[i]];
	}

	for(int i=0;i<num;i++)
	{
		if(colours[i]==EMPTY_COLOUR)
		{
			uint32_t startindex,endindex;
			int startcol,endcol;

			if(i!=0) startcol=colours[i-1];

			startindex=i-1;
			endindex=i+1;

			while(endindex<num&&colours[endindex]==EMPTY_COLOUR) endindex++;

			if(endindex<num)
			{
				endcol=colours[endindex];
				if(startindex>=0) startcol=colours[startindex];
				else startcol=endcol;
			}
			else 
			{
				if(startindex>=0) endcol=startcol=colours[startindex];
				else startcol=endcol=BLACK_COLOUR;
			}

			int start_r=XeeGetRFromARGB8(startcol);
			int start_g=XeeGetGFromARGB8(startcol);
			int start_b=XeeGetBFromARGB8(startcol);
			int end_r=XeeGetRFromARGB8(endcol);
			int end_g=XeeGetGFromARGB8(endcol);
			int end_b=XeeGetBFromARGB8(endcol);
			int total=endindex-startindex;

			for(int j=startindex+1;j<endindex;j++)
			{
				int step=j-startindex;
				int r=start_r+((end_r-start_r)*step)/total;
				int g=start_g+((end_g-start_g)*step)/total;
				int b=start_b+((end_b-start_b)*step)/total;

				colours[j]=XeeMakeARGB8(0xff,r,g,b);
			}

			i=endindex;
		}
	}
}

-(BOOL)triggerCheck:(float)time
{
	if(time>next)
	{
		while(time>next)
		{
			[self cycle];
			next+=interval;
		}
		return YES;
	}
	return NO;
}


-(void)cycle
{
	uint32_t *palette=[image palette];
	uint32_t tmp=colours[0];

	for(int i=1;i<num;i++) colours[i-1]=colours[i];

	colours[num-1]=tmp;

	for(int i=0;i<num;i++)
	{
		if(indexes[i]>=0) palette[indexes[i]]=colours[i];
	}
}

@end
