#import "XeePhotoshopLayerParser.h"
#import "XeePhotoshopLoader.h"
#import "XeeProperties.h"
#import "XeeTypes.h"

#import "XeeBitmapRawImage.h"
#import "XeeIndexedRawImage.h"
#import "XeePlanarRawImage.h"

#import "CSZlibHandle.h"
#import "CSFilterHandle.h"



@implementation XeePhotoshopLayerParser

-(id)initWithHandle:(CSHandle *)fh mode:(int)colourmode depth:(int)bitdepth
{
	if(self=[super init])
	{
		handle=[fh retain];
		props=[[NSMutableArray array] retain];
		channeloffs=[[NSMutableDictionary dictionary] retain];

		mode=colourmode;
		depth=bitdepth;

		int top=[fh readInt32BE];
		int left=[fh readInt32BE];
		int bottom=[fh readInt32BE];
		int right=[fh readInt32BE];

		width=right-left;
		height=bottom-top;

		channels=[fh readUInt16BE];
		totalsize=0;

		for(int j=0;j<channels;j++)
		{
			int channelid=[fh readInt16BE];
			uint32 channellength=[fh readUInt32BE];

			[channeloffs setObject:[NSNumber numberWithLongLong:totalsize] forKey:[NSNumber numberWithInt:channelid]];
			totalsize+=channellength;
		}

		[fh skipBytes:4]; // '8BIM'
		uint32 blendmode=[fh readUInt32BE];
		int opacity=[fh readUInt8];
		int clipping=[fh readUInt8];
		int flags=[fh readUInt8];
		[fh skipBytes:1];

		uint32 extralen=[fh readUInt32BE];
		off_t nextoffs=[fh offsetInFile]+extralen;

//		if(extralen>=

		[fh seekToFileOffset:nextoffs];


/*		@try
		{

		while(![handle atEndOfFile])
			{
				[props addObject:[XeePropertyItem itemWithLabel:
				NSLocalizedString(@"Copyright URL",@"Copyright URL property title")
				value:[NSURL URLWithString:[[[NSString alloc] initWithData:[handle readDataOfLength:chunklen] encoding:NSISOLatin1StringEncoding] autorelease]]]];
		}
		@catch(id e) { NSLog(@"Error parsing Photoshop metadata: %@",e); }*/

	}
	return self;
}

-(void)dealloc
{
	[handle release];
	[props release];
	[channeloffs release];
	[super dealloc];
}



-(void)setDataOffset:(off_t)offset
{
	dataoffs=offset;
	[handle seekToFileOffset:offset];
	compression=[handle readUInt16BE];
}

-(off_t)totalSize { return totalsize; }



-(XeeImage *)image
{
	XeeImage *image=nil;
	CSHandle *alpha=[self handleForChannel:-1];

	switch(mode)
	{
		case XeePhotoshopBitmapMode:
			image=[[[XeeBitmapRawImage alloc] initWithHandle:[self handleForChannel:0] width:width height:height] autorelease];
			[image setDepthBitmap];
		break;

//		case XeePhotoshopIndexedMode: [self setDepthIndexed:1<<bitdepth]; break;

		case XeePhotoshopGreyscaleMode:
		case XeePhotoshopDuotoneMode:
			image=[[[XeePlanarRawImage alloc] initWithHandles:[NSArray arrayWithObjects:
				[self handleForChannel:0],
				alpha,nil]
			type:XeeBitmapType(XeeGreyBitmap,depth,alpha?XeeAlphaLast:XeeAlphaNone,depth==32?XeeBitmapFloatingPointFlag:0)
			width:width height:height depth:depth bigEndian:YES preComposed:NO] autorelease];

			if(mode==XeePhotoshopGreyscaleMode) [image setDepthGrey:depth alpha:alpha?YES:NO floating:depth==32?YES:NO];
			else [image setDepth:
			[NSString stringWithFormat:NSLocalizedString(@"%d bits duotone",@"Description for duotone (Photoshop) images"),depth]
			iconName:@"depth_rgb"];
		break;

		case XeePhotoshopRGBMode:
			image=[[[XeePlanarRawImage alloc] initWithHandles:[NSArray arrayWithObjects:
				[self handleForChannel:0],
				[self handleForChannel:1],
				[self handleForChannel:2],
				alpha,nil]
			type:XeeBitmapType(XeeRGBBitmap,depth,alpha?XeeAlphaLast:XeeAlphaNone,depth==32?XeeBitmapFloatingPointFlag:0)
			width:width height:height depth:depth bigEndian:YES preComposed:NO] autorelease];

			[image setDepthRGB:depth alpha:alpha?YES:NO floating:depth==32?YES:NO];
 		break;

		default:
			return nil;
	}

	return image;
}

-(CSHandle *)handleForChannel:(int)channel
{
	NSNumber *offs=[channeloffs objectForKey:[NSNumber numberWithInt:channel]];
	if(!offs) return nil;

	off_t start=dataoffs+2+[offs longLongValue];
	CSFileHandle *fh;

	switch(compression)
	{
		case 0:
			fh=[[handle copy] autorelease];
			[fh seekToFileOffset:start];
			return fh;

		case 1:
			fh=[[handle copy] autorelease];
			[fh seekToFileOffset:start];
			return [[[XeePackbitsHandle alloc] initWithHandle:fh rows:height bytesPerRow:(width*depth+7)/8
			channel:0 of:1 previousSize:0] autorelease];

		case 2:
			fh=[[handle copy] autorelease];
			[fh seekToFileOffset:start];
			return [CSZlibHandle zlibHandleWithHandle:fh];

		case 3:
			fh=[[handle copy] autorelease];
			[fh seekToFileOffset:start];
			return [[[XeeDeltaHandle alloc] initWithHandle:[CSZlibHandle zlibHandleWithHandle:fh]
			depth:depth columns:width] autorelease];

		default:
			return nil;
	}
}

-(BOOL)hasAlpha { return [channeloffs objectForKey:[NSNumber numberWithInt:-1]]?YES:NO; }

-(NSArray *)propertyArray { return [[props retain] autorelease]; }

@end
