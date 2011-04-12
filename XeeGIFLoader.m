#import "XeeGIFLoader.h"
#import "XeeView.h"

@implementation XeeGIFImage

+(NSArray *)fileTypes
{
	return [NSArray arrayWithObjects:@"gif",@"'GIFf'",@"'GIF '",nil];
}

+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes
{
	const char *bytes=[block bytes];
	if([block length]>6&&bytes[0]=='G'&&bytes[1]=='I'&&bytes[2]=='F'&&bytes[3]=='8'
	&&(bytes[4]=='7'||bytes[4]=='9')&&bytes[5]=='a') return YES;
	return NO;
}

-(id)init
{
	if(self=[super init])
	{
		gif=NULL;
		frames=nil;
		comments=nil;
		backup=NULL;
		globalpal=nil;
		animationtimer=nil;
	}
	return self;
}

-(void)dealloc
{
	[frames release];
	free(backup);

	[globalpal release];
	[animationtimer release];

	[super dealloc];
}

static int XeeGIFReadData(GifFileType *gif,GifByteType *buf,int len)
{
	return [(CSHandle *)gif->UserData readAtMost:len toBuffer:buf];
}

-(SEL)initLoader
{
	gif=DGifOpen([self handle],XeeGIFReadData);
	if(!gif) return NULL;

	width=gif->SWidth;
	height=gif->SHeight;
	[self setDepthIndexed:1<<gif->SColorResolution];
	[self setFormat:@"GIF"];

	background=gif->SBackGroundColor;

	currframe=0;
	frametime=0;
	transindex=-1;
	disposal=0;
	backupneeded=NO;

	return @selector(startLoading);
}

-(void)deallocLoader
{
	if(gif) DGifCloseFile(gif);
}

-(SEL)startLoading
{
	if(![self allocWithType:XeeBitmapTypeARGB8 width:width height:height]) return NULL;
	transparent=NO; // hack transparent status

	frames=[[NSMutableArray array] retain];
	globalpal=[[XeeGIFPalette alloc] initWithColorMap:gif->SColorMap];

	return @selector(loadRecord);
}

-(SEL)loadRecord
{
	GifRecordType rectype;
	if(DGifGetRecordType(gif,&rectype)==GIF_ERROR) return @selector(failLoading);

	if(rectype==EXTENSION_RECORD_TYPE)
	{
		int code;
		GifByteType *ext;

		if(DGifGetExtension(gif,&code,&ext)==GIF_ERROR) return @selector(failLoading);

		if(ext)
		{
			if(code==GRAPHICS_EXT_FUNC_CODE&&ext[0]==4) // graphics control extension
			{
				frametime=(ext[2]&0xff)|((ext[3]&0xff)<<8);
				if(frametime==0||frametime==1) frametime=10; // oh boy, broken software!

				disposal=(ext[1]&0x1c)>>2;
				if(disposal==4) disposal=3;
				if(disposal==3) backupneeded=YES;

				if(ext[1]&0x01)
				{
					transindex=ext[4];

					if([frames count]==0) transparent=YES;
					if(disposal==2&&transindex==background) transparent=YES;

					if(gif->SColorMap&&transindex<gif->SColorMap->ColorCount)
					[self setBackgroundColor:[NSColor colorWithCalibratedRed:(float)gif->SColorMap->Colors[transindex].Red/255.0
					green:(float)gif->SColorMap->Colors[transindex].Green/255.0
					blue:(float)gif->SColorMap->Colors[transindex].Blue/255.0
					alpha:1]];
				}
				else
				{
					transindex=-1;
				}

				do { if(DGifGetExtensionNext(gif,&ext)==GIF_ERROR) return @selector(failLoading); }
				while(ext);
			}
			else if(code==COMMENT_EXT_FUNC_CODE) // graphics control extension
			{
				if(!comments)
				{
					comments=[NSMutableArray array];
					[properties addObject:[XeePropertyItem itemWithLabel:
					NSLocalizedString(@"File comments",@"File comments section title")
					value:comments identifier:@"common.comments"]];
				}

				NSMutableData *commentdata=[NSMutableData data];
				do
				{
					[commentdata appendBytes:ext+1 length:ext[0]];

					if(DGifGetExtensionNext(gif,&ext)==GIF_ERROR) return @selector(failLoading);
				}
				while(ext);

				[comments addObject:[XeePropertyItem itemWithLabel:@""
				value:[[[NSString alloc] initWithData:commentdata encoding:NSISOLatin1StringEncoding]
				autorelease]]];
			}
			else
			{
				do { if(DGifGetExtensionNext(gif,&ext)==GIF_ERROR) return @selector(failLoading); }
				while(ext);
			}
		}
	}
	else if(rectype==IMAGE_DESC_RECORD_TYPE)
	{
		if(DGifGetImageDesc(gif)==GIF_ERROR) return @selector(failLoading);

		int frameleft=gif->Image.Left;
		int frametop=gif->Image.Top;
		int framewidth=gif->Image.Width;
		int frameheight=gif->Image.Height;
		int interlaced=gif->Image.Interlace;
		XeeGIFPalette *pal;

		if(gif->Image.ColorMap) pal=[[[XeeGIFPalette alloc] initWithColorMap:gif->Image.ColorMap] autorelease];
		else pal=globalpal;

		XeeGIFFrame *frame=[[[XeeGIFFrame alloc] initWithWidth:framewidth height:frameheight left:frameleft top:frametop
		time:frametime transparent:transindex disposal:disposal palette:pal] autorelease];
		if(!frame) return NULL;

		[frames addObject:frame];

		unsigned char *framedata=[frame data];

		if(interlaced)
		{
			for(int y=0;y<frameheight;y+=8)
			{
				unsigned char *line=framedata+y*framewidth;
				if(DGifGetLine(gif,line,framewidth)==GIF_ERROR) return @selector(failLoading);
			}
			for(int y=4;y<frameheight;y+=8)
			{
				unsigned char *line=framedata+y*framewidth;
				if(DGifGetLine(gif,line,framewidth)==GIF_ERROR) return @selector(failLoading);
			}
			for(int y=2;y<frameheight;y+=4)
			{
				unsigned char *line=framedata+y*framewidth;
				if(DGifGetLine(gif,line,framewidth)==GIF_ERROR) return @selector(failLoading);
			}
			for(int y=1;y<frameheight;y+=2)
			{
				unsigned char *line=framedata+y*framewidth;
				if(DGifGetLine(gif,line,framewidth)==GIF_ERROR) return @selector(failLoading);
			}
		}
		else
		{
			if(DGifGetLine(gif,framedata,framewidth*frameheight)==GIF_ERROR) return @selector(failLoading);
		}

		if([frames count]==1)
		{
			[self clearImage];
			[(XeeGIFFrame *)[frames objectAtIndex:0] draw:self];
			[self setCompleted];
		}
	}
	else return @selector(finishLoading);

	return @selector(loadRecord);
}

-(SEL)failLoading
{
	if([frames count]==1)
	{
		[self clearImage];
		[(XeeGIFFrame *)[frames objectAtIndex:0] draw:self];
		[self setCompleted];
	}
	return NULL;
}

-(SEL)finishLoading
{
	if(backupneeded)
	{
		backup=malloc(4*width*height);
		if(!backup) return NULL;
	}

	if([frames count]>1)
	{
		int totaltime=0;
		NSEnumerator *enumerator=[frames objectEnumerator];
		XeeGIFFrame *frame;
		while(frame=[enumerator nextObject]) totaltime+=[frame time];

		[properties addObject:[XeePropertyItem subSectionItemWithLabel:
		NSLocalizedString(@"GIF animation properties",@"GIF animation properties section title")
		identifier:@"gif.animation"
 		labelsAndValues:
			NSLocalizedString(@"Number of frames",@"Number of frames GIF property label"),
			[NSNumber numberWithInt:[frames count]],
			NSLocalizedString(@"Total playing time",@"Total playing time GIF property label"),
			[NSString stringWithFormat:
			NSLocalizedString(@"%.2f seconds",@"A time in seconds with two decimals"),
			(float)totaltime/100.0+0.005],
		nil]];
	}

	loaded=YES;
	[self triggerPropertyChangeAction];

	return NULL;
}



-(int)frames { return frames?[frames count]:0; }

-(void)setFrame:(int)frame
{
	if(frame==currframe) return;

	if(frame<currframe)
	{
		[self clearImage]; // not needed if first image paints all - should check
		currframe=-1;
	}
	else [[frames objectAtIndex:currframe] dispose:self];

	for(int i=currframe+1;i<frame;i++) [[frames objectAtIndex:i] drawAndDispose:self];

	[(XeeGIFFrame *)[frames objectAtIndex:frame] draw:self];
	currframe=frame;

	[self invalidate];
}

-(int)frame { return currframe; }



-(BOOL)animated { return [frames count]>1; }

-(void)setAnimating:(BOOL)animating
{
	if(animating)
	{
		animticks=0;
		if(!animationtimer)
		{
			animationtimer=[[NSTimer scheduledTimerWithTimeInterval:1.0/100.0 target:self selector:@selector(animate:) userInfo:nil repeats:YES] retain];
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

-(void)setAnimatingDefault { [self setAnimating:YES]; }

-(BOOL)animating { return animationtimer?YES:NO; }

-(void)animate:(NSTimer *)timer
{
	if([frames count]<=1) return;
	if(![self loaded]) return;

	animticks++;

	if(animticks>=[[frames objectAtIndex:currframe] time])
	{
		int numframes=[frames count];

		[self setFrame:(currframe+1)%numframes];

		//[self triggerUpdateAction];

		animticks=0;
	}
}

-(void)clearImage
{
	uint32_t *ptr=(uint32_t *)data;
	int n=(bytesperrow/4)*height;
	uint32_t val;

	if(transindex>=0) val=0x00000000;
	else val=[globalpal table][background];

	while(n--) *ptr++=val;
}

-(int)background { return background; }

-(uint32_t *)backup { return backup; }


@end



@implementation XeeGIFFrame

-(id)initWithWidth:(int)framewidth height:(int)frameheight left:(int)frameleft
top:(int)frametop time:(int)frametime transparent:(int)trans disposal:(int)disp
palette:(XeeGIFPalette *)pal
{
	if(self=[super init])
	{
		width=framewidth;
		height=frameheight;
		left=frameleft;
		top=frametop;
		time=frametime;
		transparent=trans;
		disposal=disp;
		palette=[pal retain];

		data=malloc(width*height);
		if(data)
		{
			return self;
		}

		[self release];
	}
	return nil;
}

-(void)dealloc
{
	[palette release];
	free(data);

	[super dealloc];
}

-(void)draw:(XeeGIFImage *)image
{
	if(left<0||top<0||left+width>[image width]||top+height>[image height]) return;

	uint32_t *destdata=(uint32_t *)[image data];
	uint32_t *backup=(uint32_t *)[image backup];
	uint32_t *ptable=[palette table];
	uint8_t *src=data;
	int destwidth=[image bytesPerRow]/4;

	if(disposal==3&&backup)
	for(int y=0;y<height;y++)
	{
		uint32_t *orig=destdata+(top+y)*destwidth+left;
		int n=width;
		while(n--) *backup++=*orig++;
	}

	for(int y=0;y<height;y++)
	{
		uint32_t *dest=destdata+(top+y)*destwidth+left;
		int n=width;
		while(n--)
		{
			int col=*src++;
			if(col!=transparent) *dest=ptable[col];
			dest++;
		}
	}
}

-(void)dispose:(XeeGIFImage *)image
{
	if(left<0||top<0||left+width>[image width]||top+height>[image height]) return;

	uint32_t *destdata=(uint32_t *)[image data];
	int destwidth=[image width];

	if(disposal==2)
	{
		int background=[image background];
		uint32_t colour;

		if(background==transparent) colour=0x00000000;
		else colour=[palette table][background];

		for(int y=0;y<height;y++)
		{
			uint32_t *dest=destdata+(top+y)*destwidth+left;
			int n=width;
			while(n--) *dest++=colour;
		}
	}
	else if(disposal==3)
	{
		uint32_t *backup=(uint32_t *)[image backup];

		if(backup)
		for(int y=0;y<height;y++)
		{
			uint32_t *dest=destdata+(top+y)*destwidth+left;
			int n=width;
			while(n--) *dest++=*backup++;
		}
	}
}

-(void)drawAndDispose:(XeeGIFImage *)image
{
	if(disposal==3) return;
	else if(disposal==2) [self dispose:image];
	else [self draw:image];
}

-(unsigned char *)data { return data; }

-(int)time { return time; }

@end



@implementation XeeGIFPalette

-(id)initWithColorMap:(ColorMapObject *)cmap
{
	if(self=[super init])
	{
		if(cmap)
		{
			int shift=7-cmap->BitsPerPixel;
			shift=0;
			for(int i=0;i<cmap->ColorCount;i++)
			{
				int r=cmap->Colors[i].Red<<shift;
				int g=cmap->Colors[i].Green<<shift;
				int b=cmap->Colors[i].Blue<<shift;
				table[i]=XeeMakeARGB8(0xff,r,g,b);
			}
		}
	}

	return self;
}

-(uint32_t *)table { return table; }

@end