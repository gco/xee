#import "XeePhotoshopLoader.h"
#import "Xee8BIMParser.h"
#import "XeePhotoshopLayerParser.h"

#import "XeeBitmapRawImage.h"
#import "XeeIndexedRawImage.h"
#import "XeePlanarRawImage.h"



@implementation XeePhotoshopImage

+(NSArray *)fileTypes
{
	return [NSArray arrayWithObjects:@"psd",@"'8BPS'",nil];
}

+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes
{
	uint8 *header=(uint8 *)[block bytes];
	if([block length]>6&&XeeBEUInt32(header)=='8BPS'&&XeeBEUInt16(header+4)==1) return YES;
	return NO;
}

-(id)init
{
	if(self=[super init])
	{
	}
	return self;
}

-(void)dealloc
{
	[super dealloc];
}

-(SEL)initLoader
{
	CSFileHandle *fh=[self fileHandle];

	[fh skipBytes:12];

	int channels=[fh readUInt16BE];
	height=[fh readUInt32BE];
	width=[fh readUInt32BE];
	int bitdepth=[fh readUInt16BE];
	int mode=[fh readUInt16BE];

	// Colour data section
	uint32 colourlen=[fh readUInt32BE];
	off_t resourceoffs=[fh offsetInFile]+colourlen;



	// Resources section
	[fh seekToFileOffset:resourceoffs];
	uint32 resourcelen=[fh readUInt32BE];
	off_t layermaskoffs=[fh offsetInFile]+resourcelen;

	Xee8BIMParser *parser=[[Xee8BIMParser alloc] initWithHandle:fh];
	[properties addObjectsFromArray:[parser propertyArray]];
	BOOL hasmerged=[parser hasMergedImage];
	[parser release];



	// Layers section
	[fh seekToFileOffset:layermaskoffs];
	uint32 layermasklen=[fh readUInt32BE];
	off_t imageoffs=[fh offsetInFile]+layermasklen;

	BOOL readlayers=NO;
	BOOL hasalpha=NO;

	uint32 layerlen=[fh readUInt32BE];
	//off_t maskoffs=[fh offsetInFile]+layerlen;
	if(layerlen==0)
	{
		uint32 masklen=[fh readUInt32BE];
		[fh skipBytes:masklen];

		while([fh offsetInFile]+12<=imageoffs)
		{
			uint32 sign=[fh readUInt32BE];
			uint32 marker=[fh readUInt32BE];
			uint32 len=[fh readUInt32BE];

			if(sign!='8BIM') break; // sanity check
			if(marker=='Lr16')
			{
				readlayers=YES;
				break;
			}
			else if(marker=='Mt16')
			{
				hasalpha=YES;
			}

			[fh skipBytes:len];
		}
	}
	else readlayers=YES;

	NSMutableArray *layers=[NSMutableArray array];

	if(readlayers)
	{
		int numlayers=[fh readInt16BE];

		if(numlayers<0)
		{
			hasalpha=YES;
			numlayers=-numlayers;
		}

		for(int i=0;i<numlayers;i++)
		{
			XeePhotoshopLayerParser *layer=[[[XeePhotoshopLayerParser alloc] initWithHandle:fh mode:mode depth:bitdepth] autorelease];
			[layers addObject:layer];
		}

		off_t offset=[fh offsetInFile];
		NSEnumerator *enumerator=[layers objectEnumerator];
		XeePhotoshopLayerParser *layer;
		while(layer=[enumerator nextObject])
		{
			[layer setDataOffset:offset];
			offset+=[layer totalSize];
		}
	}

	switch(mode)
	{
		case XeePhotoshopBitmapMode: [self setDepthBitmap]; break;
		case XeePhotoshopGreyscaleMode: [self setDepthGrey:bitdepth alpha:hasalpha floating:bitdepth==32?YES:NO]; break;
		case XeePhotoshopIndexedMode: [self setDepthIndexed:1<<bitdepth]; break;
		case XeePhotoshopRGBMode: [self setDepthRGB:bitdepth alpha:hasalpha floating:bitdepth==32?YES:NO]; break;
		case XeePhotoshopCMYKMode: [self setDepthCMYK:bitdepth alpha:hasalpha]; break;
		case XeePhotoshopLabMode: [self setDepthLab:bitdepth alpha:hasalpha]; break;

		case XeePhotoshopMultichannelMode:
			[self setDepth:
			[NSString stringWithFormat:NSLocalizedString(@"%d bits multichannel",@"Description for multichannel (Photoshop) images"),bitdepth]
			iconName:@"depth_grey"];
		break;

		case XeePhotoshopDuotoneMode:
		 	[self setDepth:
			[NSString stringWithFormat:NSLocalizedString(@"%d bits duotone",@"Description for duotone (Photoshop) images"),bitdepth]
			iconName:@"depth_rgb"];
		break;
	}



	// Image section

	if(hasmerged)
	{
		[fh seekToFileOffset:imageoffs];

		int bpr=(bitdepth*width+7)/8;
		NSArray *handles=[self channelHandlesForHandle:fh bytesPerRow:bpr rows:height channels:channels];
		XeeImage *mainimage=nil;

		switch(mode)
		{
			case XeePhotoshopBitmapMode:
				mainimage=[[XeeBitmapRawImage alloc] initWithHandle:[handles objectAtIndex:0]
				width:width height:height];
			break;

			case XeePhotoshopGreyscaleMode:
			case XeePhotoshopDuotoneMode:
				if(channels>=hasalpha?2:1)
				{
					mainimage=[[XeePlanarRawImage alloc] initWithHandles:[handles subarrayWithRange:NSMakeRange(0,hasalpha?2:1)]
					type:XeeBitmapType(XeeGreyBitmap,bitdepth,hasalpha?XeeAlphaLast:XeeAlphaNone,bitdepth==32?XeeBitmapFloatingPointFlag:0)
					width:width height:height depth:bitdepth bigEndian:YES preComposed:YES];
				}
			break;

			case XeePhotoshopRGBMode:
				if(channels>=hasalpha?4:3)
				{
					mainimage=[[XeePlanarRawImage alloc] initWithHandles:[handles subarrayWithRange:NSMakeRange(0,hasalpha?4:3)]
					type:XeeBitmapType(XeeRGBBitmap,bitdepth,hasalpha?XeeAlphaLast:XeeAlphaNone,bitdepth==32?XeeBitmapFloatingPointFlag:0)
					width:width height:height depth:bitdepth bigEndian:YES preComposed:YES];
				}
			break;
		}

		if(mainimage)
		{
			[mainimage setDepth:[self depth]];
			[mainimage setDepthIcon:[self depthIcon]];
			[self addSubImage:mainimage];
			[mainimage release];
		}
	}

	NSEnumerator *enumerator=[layers objectEnumerator];
	XeePhotoshopLayerParser *layer;
	while(layer=[enumerator nextObject])
	{
		XeeImage *image=[layer image];
		if(image) [self addSubImage:image];
	}

	[self setFormat:@"PSD"];

/*XeeBitmapImage *img=[[[XeeBitmapImage alloc] initWithType:XeeBitmapTypeRGB8 width:width height:height] autorelease];
[img setCompleted];
[self addSubImage:img];*/

	loadersel=NULL;
	loaderframe=-1;

	return @selector(load);
}

-(void)deallocLoader
{
}

-(SEL)load
{
	if(!loadersel)
	{
		if(loaderframe>=0) [[subimages objectAtIndex:loaderframe] deallocLoader];
		loaderframe++;
		if(loaderframe>=[self frames])
		{
			loaded=YES;
			return NULL;
		}
		loadersel=@selector(initLoader);
	}
	loadersel=(SEL)[[subimages objectAtIndex:loaderframe] performSelector:loadersel];
	return @selector(load);
}

-(NSArray *)channelHandlesForHandle:(CSHandle *)handle bytesPerRow:(int)bpr rows:(int)rows channels:(int)numchannels
{
	NSMutableArray *array=[NSMutableArray array];
	off_t totalsize=0;

	int compression=[handle readUInt16BE];
	switch(compression)
	{
		case 0:
			for(int i=0;i<numchannels;i++)
			{
				CSFileHandle *fh=[[handle copy] autorelease];
				[fh skipBytes:i*bpr*rows];
				[array addObject:fh];
			}
		break;

		case 1:
			for(int i=0;i<numchannels;i++)
			{
				XeePackbitsHandle *ph=[[[XeePackbitsHandle alloc] initWithHandle:[[handle copy] autorelease]
				rows:height bytesPerRow:bpr channel:i of:numchannels previousSize:totalsize] autorelease];
				totalsize+=[ph totalSize];
				[array addObject:ph];
			}
		break;
	}
	return array;
}

@end




@implementation XeePackbitsHandle

-(id)initWithHandle:(CSHandle *)handle rows:(int)numrows bytesPerRow:(int)bpr channel:(int)channel of:(int)numchannels previousSize:(off_t)prevsize
{
	if(self=[super initWithName:[handle name]])
	{
		parent=[handle retain];
		readatmost_ptr=(int (*)(id,SEL,int,void *))[parent methodForSelector:@selector(readAtMost:toBuffer:)];

		rows=numrows;
		bytesperrow=bpr;

		pos=0;
		totalsize=0;
		offsets=malloc(sizeof(off_t)*rows);
		off_t firstrow=[handle offsetInFile]+numchannels*rows*2+prevsize;

		[parent skipBytes:2*rows*channel];
		for(int i=0;i<rows;i++)
		{
			offsets[i]=firstrow+totalsize;
			totalsize+=[parent readUInt16BE];
		}
	}
	return self;
}

-(void)dealloc
{
	free(offsets);
	[parent release];
	[super dealloc];
}


-(off_t)offsetInFile { return pos; }

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	uint8 *ptr=buffer;
	int left=num;

	while(left)
	{
		if(pos%bytesperrow==0)
		{
			[parent seekToFileOffset:offsets[pos/bytesperrow]];
			spanleft=0;
		}

		if(!spanleft)
		{
			uint8 b;
			//do {
				if(readatmost_ptr(parent,@selector(readAtMost:toBuffer:),1,&b)!=1) goto end;
			//} while(b==0xff);

			if(b&0x80)
			{
				spanleft=(b^0xff)+2;
				if(readatmost_ptr(parent,@selector(readAtMost:toBuffer:),1,&spanbyte)!=1) goto end;
				literal=NO;
			}
			else
			{
				spanleft=b+1;
				literal=YES;
			}
		}

		if(literal)
		{
			if(readatmost_ptr(parent,@selector(readAtMost:toBuffer:),1,ptr++)!=1) goto end;
		}
		else
		{
			*ptr++=spanbyte;
		}

		spanleft--;
		left--;
		pos++;
	}

	end:
	return num-left;
}

-(off_t)totalSize { return totalsize; }

@end



@implementation XeeDeltaHandle

-(id)initWithHandle:(CSHandle *)handle depth:(int)bitdepth columns:(int)columns
{
	if(self=[super initWithName:[handle name]])
	{
		parent=[handle retain];
//		readatmost_ptr=(int (*)(id,SEL,int,void *))[parent methodForSelector:@selector(readAtMost:toBuffer:)];

		depth=bitdepth;
		cols=columns;
		curr=0;
	}
	return self;
}

-(void)dealloc
{
	[parent release];
	[super dealloc];
}

-(off_t)offsetInFile { return [parent offsetInFile]; }

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	off_t start=[parent offsetInFile];
	int actual=[parent readAtMost:num toBuffer:buffer];

	if(depth==16)
	{
		uint8 *ptr=(uint8 *)buffer;
		int first=(start/2)%cols;

		for(int i=0;i<actual/2;i++)
		{
			if((first+i)%cols==0) curr=XeeBEUInt16(ptr);
			else XeeSetBEUInt16(ptr,curr+=XeeBEUInt16(ptr));
			ptr+=2;
		}
	}

	return actual;
}

@end
