#import "XeeGIFLoader.h"
#import "XeeView.h"
#import "XeeLoaderMisc.h"

@implementation XeeGIFImage

-(SEL)identifyFile
{
	gif=NULL;
	frames=nil;
	backup=NULL;
	globalpal=nil;
	comments=nil;
	animationtimer=nil;

	const char *headbytes=[header bytes];

	if([header length]<6) return NULL;
	if(headbytes[0]!='G'||headbytes[1]!='I'||headbytes[2]!='F'||headbytes[3]!='8'
	||(headbytes[4]!='7'&&headbytes[4]!='9')||headbytes[5]!='a') return NULL;

	gif=DGifOpenFileName([filename fileSystemRepresentation]);
	if(!gif) return NULL;

	width=gif->SWidth;
	height=gif->SHeight;
	[self setDepthIndexed:1<<gif->SColorResolution];

	background=gif->SBackGroundColor;

	if(gif->SColorMap&&background<gif->SColorMap->ColorCount)
	[self setBackgroundColor:[NSColor colorWithCalibratedRed:(float)gif->SColorMap->Colors[background].Red/255.0
	green:(float)gif->SColorMap->Colors[background].Green/255.0
	blue:(float)gif->SColorMap->Colors[background].Blue/255.0
	alpha:1]];

	currframe=0;
	frametime=0;
	transindex=-1;
	disposal=0;
	backupneeded=NO;

	[self setFormat:@"GIF"];

	return @selector(startLoading);
}

-(void)deallocLoader
{
	if(gif) DGifCloseFile(gif);
	[comments release];

	[super deallocLoader];
}

-(void)dealloc
{
	[frames release];
	free(backup);

	[globalpal release];
	[animationtimer release];

	[super dealloc];
}

-(SEL)startLoading
{
	if(![self allocWithType:XeeBitmapTypeARGB8 width:width height:height]) return NULL;
	transparent=NO; // hack transparent status
	frames=[[NSMutableArray alloc] initWithCapacity:16];
	globalpal=[[XeeGIFPalette alloc] initWithColorMap:gif->SColorMap];

	return @selector(loadRecord);
}

-(SEL)loadRecord
{
	GifRecordType rectype;
	if(DGifGetRecordType(gif,&rectype)==GIF_ERROR) return @selector(errorRecovery);

	if(rectype==EXTENSION_RECORD_TYPE)
	{
		int code;
		GifByteType *ext;

		if(DGifGetExtension(gif,&code,&ext)==GIF_ERROR) return @selector(errorRecovery);

		if(ext)
		{
			if(code==GRAPHICS_EXT_FUNC_CODE&&ext[0]==4) // graphics control extension
			{
				frametime=(ext[2]&0xff)|((ext[3]&0xff)<<8);
				transindex=(ext[1]&0x01)?ext[4]:-1;
				disposal=(ext[1]&0x1c)>>2;

				if(frametime==0||frametime==1) frametime=10; // oh boy, broken software!
				if(disposal==4) disposal=3;

				if(disposal==3) backupneeded=YES;

				if(transindex>=0)
				if([frames count]==0||(disposal==2&&transindex==background)) transparent=YES;
			}
			else if(code==COMMENT_EXT_FUNC_CODE)
			{
				NSString *comment=nil;
				do
				{
					NSString *part=XeeNSStringFromByteBuffer(ext+1,ext[0]);
					if(!comment) comment=part;
					else comment=[comment stringByAppendingString:part];

					if(DGifGetExtensionNext(gif,&ext)==GIF_ERROR) return @selector(errorRecovery);
				}
				while(ext);

				if(!comments) comments=[[NSMutableArray array] retain];
				[comments addObject:@""];
				[comments addObject:comment];
			}

			while(ext) if(DGifGetExtensionNext(gif,&ext)==GIF_ERROR) return @selector(errorRecovery);
		}
	}
	else if(rectype==IMAGE_DESC_RECORD_TYPE)
	{
		if(DGifGetImageDesc(gif)==GIF_ERROR) return @selector(errorRecovery);

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
		[frames addObject:frame];

		if(frame)
		{
			unsigned char *framedata=[frame data];

			if(interlaced)
			{
				for(int y=0;y<frameheight;y+=8)
				{
					unsigned char *line=framedata+y*framewidth;
					if(DGifGetLine(gif,line,framewidth)==GIF_ERROR) return @selector(errorRecovery);
				}
				for(int y=4;y<frameheight;y+=8)
				{
					unsigned char *line=framedata+y*framewidth;
					if(DGifGetLine(gif,line,framewidth)==GIF_ERROR) return @selector(errorRecovery);
				}
				for(int y=2;y<frameheight;y+=4)
				{
					unsigned char *line=framedata+y*framewidth;
					if(DGifGetLine(gif,line,framewidth)==GIF_ERROR) return @selector(errorRecovery);
				}
				for(int y=1;y<frameheight;y+=2)
				{
					unsigned char *line=framedata+y*framewidth;
					if(DGifGetLine(gif,line,framewidth)==GIF_ERROR) return @selector(errorRecovery);
				}
			}
			else
			{
				if(DGifGetLine(gif,framedata,framewidth*frameheight)==GIF_ERROR) return @selector(errorRecovery);
			}
		}

		if([frames count]==1)
		{
			[self clearImage];
			[[frames objectAtIndex:0] draw:self];
			[self setCompleted];
			[self triggerChangeAction];
		}
	}
	else return @selector(finishLoading); // TERMINATE_RECORD_TYPE, all done

	return @selector(loadRecord);
}

-(SEL)errorRecovery
{
	if([frames count]==1)
	{
		[self clearImage];
		[(XeeGIFFrame *)[frames objectAtIndex:0] draw:self];
		[self setCompleted];
	}
	return @selector(finishLoading);
}

-(SEL)finishLoading
{
	if(backupneeded)
	{
		backup=malloc(4*width*height);
		if(!backup) return NULL;
	}

	BOOL newprops=NO;

	if([frames count]>1)
	{
		int totaltime=0;
		NSEnumerator *enumerator=[frames objectEnumerator];
		XeeGIFFrame *frame;
		while(frame=[enumerator nextObject]) totaltime+=[frame time];

		[properties addObject:@"GIF animation properties"];
		[properties addObject:[NSArray arrayWithObjects:
			@"Number of frames",
			[NSString stringWithFormat:@"%d",[frames count]],
			@"Total playing time",
			[NSString stringWithFormat:@"%d.%02d s",totaltime/100,totaltime%100],
		nil]];
		newprops=YES;
	}

	if(comments)
	{
		[properties addObject:@"GIF comments"];
		[properties addObject:comments];
		newprops=YES;
	}

	if(newprops) [self triggerPropertyChangeAction];

	success=YES;
	return NULL;
}

-(int)frames
{
	if(![self completed]) return 1;
	if(frames) return [frames count];
	return 0;
}

-(void)setFrame:(int)frame
{
	if(![self completed]) return;
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
	if(![self completed]) return;
	if([frames count]<=1) return;

	animticks++;

	if(animticks>=[[frames objectAtIndex:currframe] time])
	{
		int numframes=[frames count];

		[self setFrame:(currframe+1)%numframes];

		animticks=0;
	}
}

-(void)clearImage
{
	unsigned long *ptr=(unsigned long *)data;
	int n=(bytesperrow/4)*height;

	while(n--) *ptr++=0x00000000;
}

-(int)background { return background; }

-(unsigned long *)backup { return backup; }

+(NSArray *)fileTypes
{
	return [NSArray arrayWithObjects:@"gif",@"'GIFf'",@"'GIF '",nil];
}

@end



@implementation XeeGIFFrame

-(id)initWithWidth:(int)framewidth height:(int)frameheight left:(int)frameleft top:(int)frametop time:(int)frametime transparent:(int)trans disposal:(int)disp palette:(XeeGIFPalette *)pal
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

	unsigned long *destdata=(unsigned long *)[image data];
	unsigned long *backup=(unsigned long *)[image backup];
	unsigned long *ptable=[palette table];
	unsigned char *src=data;
	int destwidth=[image bytesPerRow]/4;

	if(disposal==3&&backup)
	for(int y=0;y<height;y++)
	{
		unsigned long *orig=destdata+(top+y)*destwidth+left;
		int n=width;
		while(n--) *backup++=*orig++;
	}

	for(int y=0;y<height;y++)
	{
		unsigned long *dest=destdata+(top+y)*destwidth+left;
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

	unsigned long *destdata=(unsigned long *)[image data];
	int destwidth=[image width];

	if(disposal==2)
	{
		int background=[image background];
		unsigned long colour;

		if(background==transparent) colour=0x00000000;
		else background=[palette table][background];

		for(int y=0;y<height;y++)
		{
			unsigned long *dest=destdata+(top+y)*destwidth+left;
			int n=width;
			while(n--) *dest++=colour;
		}
	}
	else if(disposal==3)
	{
		unsigned long *backup=(unsigned long *)[image backup];

		if(backup)
		for(int y=0;y<height;y++)
		{
			unsigned long *dest=destdata+(top+y)*destwidth+left;
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

-(unsigned long *)table { return table; }

@end