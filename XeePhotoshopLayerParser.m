#import "XeePhotoshopLayerParser.h"
#import "XeePhotoshopLoader.h"
#import "XeeProperties.h"
#import "XeeTypes.h"

#import "XeeBitmapRawImage.h"
#import "XeeIndexedRawImage.h"
#import "XeeRawImage.h"

#import "XeeInterleavingHandle.h"

#import <XADMaster/CSZlibHandle.h>

/*static int XeeOffsetOfStringInMemory(const char *str,const void *mem,int len)
{
	int slen=strlen(str);
	const char *memstr=mem;
	for(int i=0;i<=len-slen;i++)
	{
		if(str[0]==memstr[i])
		{
			for(int j=1;j<slen;j++)
			{
				if(str[j]!=memstr[i+j]) goto end;
			}
			return i;
		}
		end: 0;
	}
	return -1;
}*/

@implementation XeePhotoshopLayerParser

+(NSArray *)parseLayersFromHandle:(CSHandle *)fh parentImage:(XeePhotoshopImage *)parent alphaFlag:(BOOL *)hasalpha
{
	NSMutableArray *layers=[NSMutableArray array];
	int numlayers=[fh readInt16BE];

	if(numlayers<0)
	{
		if(hasalpha) *hasalpha=YES;
		numlayers=-numlayers;
	}

	for(int i=0;i<numlayers;i++)
	{
		XeePhotoshopLayerParser *layer=[[[self alloc] initWithHandle:fh parentImage:parent] autorelease];
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

	return layers;
}

-(id)initWithHandle:(CSHandle *)fh parentImage:(XeePhotoshopImage *)parentimage
{
	if(self=[super init])
	{
		handle=[fh retain];
		parent=parentimage;
		props=[NSMutableArray new];
		channeloffs=[NSMutableDictionary new];

		mode=[parent mode];
		depth=[parent bitDepth];

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
			uint32_t channellength=[fh readUInt32BE];

			[channeloffs setObject:[NSNumber numberWithLongLong:totalsize] forKey:[NSNumber numberWithInt:channelid]];
			totalsize+=channellength;
		}

		[fh skipBytes:4]; // '8BIM'
		uint32_t blendmode=[fh readUInt32BE];
		int opacity=[fh readUInt8];
		/*int clipping=*/[fh readUInt8];
		/*int flags=*/[fh readUInt8];
		[fh skipBytes:1];

		uint32_t extralen=[fh readUInt32BE];
		off_t nextoffs=[fh offsetInFile]+extralen;

		int bytesleft=extralen;

		NSString *layername=nil;

		if(bytesleft<4) goto outofbytes;
		uint32_t masksize=[fh readUInt32BE]; bytesleft-=4;
		if(bytesleft<masksize) goto outofbytes;
		[fh skipBytes:masksize]; bytesleft-=masksize;

		if(bytesleft<4) goto outofbytes;
		uint32_t blendsize=[fh readUInt32BE]; bytesleft-=4;
		if(bytesleft<blendsize) goto outofbytes;
		[fh skipBytes:blendsize]; bytesleft-=blendsize;

		if(bytesleft<1) goto outofbytes;
		int namelen=[fh readUInt8]; bytesleft-=1;
		if(bytesleft<namelen) goto outofbytes;
		if(namelen) layername=[[[NSString alloc] initWithData:[fh readDataOfLength:namelen] encoding:NSISOLatin1StringEncoding] autorelease];
		int padbytes=((3-namelen)&3);
		if(bytesleft<padbytes) goto outofbytes;
		[fh skipBytes:padbytes]; bytesleft-=padbytes;

		NSString *adjustmentname=nil;
		NSArray *typetoolfonts=nil,*typetooltext=nil;

		while(bytesleft>=12)
		{
			uint32_t signature=[fh readUInt32BE];
			if(signature!='8BIM') break;
			uint32_t key=[fh readUInt32BE];
			uint32_t chunklen=[fh readUInt32BE];
			off_t nextchunk=[fh offsetInFile]+chunklen;
			bytesleft-=12;
			if(chunklen>bytesleft) break;

			switch(key)
			{
				case 'levl': // levels adjustment layer
					adjustmentname=NSLocalizedString(@"Levels",@"Photoshop levels adjustment layer name property value");
				break;
				case 'curv': // curves adjustment layer
					adjustmentname=NSLocalizedString(@"Curves",@"Photoshop curves adjustment layer name property value");
				break;
				case 'brit': // brightness adjustment layer
					adjustmentname=NSLocalizedString(@"Brightness",@"Photoshop brightness adjustment layer name property value");
				break;
				case 'blnc': // color balance adjustment layer
					adjustmentname=NSLocalizedString(@"Color balance",@"Photoshop color balance adjustment layer name property value");
				break;
				case 'hue ': // old hue/saturation adjustment layer
					adjustmentname=NSLocalizedString(@"Hue/saturation (old)",@"Photoshop old hue/saturations adjustment layer name property value");
				break;
				case 'hue2': // new hue/saturation adjustment layer
					adjustmentname=NSLocalizedString(@"Hue/saturation",@"Photoshop hue/saturation adjustment layer name property value");
				break;
				case 'selc': // selective color adjustment layer
					adjustmentname=NSLocalizedString(@"Selective color",@"Photoshop selective color adjustment layer name property value");
				break;
				case 'thrs': // threshold adjustment layer
					adjustmentname=NSLocalizedString(@"Threshold",@"Photoshop threshold adjustment layer name property value");
				break;
				case 'nvrt': // invert adjustment layer
					adjustmentname=NSLocalizedString(@"Invert",@"Photoshop invert adjustment layer name property value");
				break;
				case 'post': // posterize adjustment layer
					adjustmentname=NSLocalizedString(@"Posterize",@"Photoshop posterize adjustment layer name property value");
				break;

				case 'lrFX': // effects layer
				break;

				case 'tySh': // type tool
				{
					NSMutableArray *fonts=[NSMutableArray array];

					[fh skipBytes:52];
					int numfonts=[fh readUInt16BE];
					for(int i=0;i<numfonts;i++)
					{
						[fh skipBytes:6];
						int len=[fh readUInt8];
						NSString *fontname=[[[NSString alloc] initWithData:[fh readDataOfLength:len] encoding:NSISOLatin1StringEncoding] autorelease];
						len=[fh readUInt8];
						[fh skipBytes:len]; // family
						len=[fh readUInt8];
						NSString *fontstyle=[[[NSString alloc] initWithData:[fh readDataOfLength:len] encoding:NSISOLatin1StringEncoding] autorelease];
						[fh skipBytes:2];
						int vecnum=[fh readUInt32BE];
						[fh skipBytes:vecnum*4];

						[fonts addObject:[NSString stringWithFormat:@"%@ %@",fontname,fontstyle]];
					}

					typetoolfonts=[XeePropertyItem itemsWithLabel:
					NSLocalizedString(@"Text layer fonts",@"Photoshop text layer fonts property title")
					valueArray:fonts];

					int numstyles=[fh readUInt16BE];
					[fh skipBytes:numstyles*26+26];

					NSMutableString *str=[NSMutableString string];
					int numlines=[fh readUInt16BE];
					for(int i=0;i<numlines;i++)
					{
						int numchars=[fh readUInt32BE];
						[fh skipBytes:4];
						for(int j=0;j<numchars;j++)
						{
							int c=[fh readUInt16BE];
							[fh skipBytes:2];
							if(c=='\n') continue; // skip \n
							if(c=='\r') c='\n'; // and turn \r into \n;
							[str appendFormat:@"%C",c];
						}
					}

					typetooltext=[XeePropertyItem itemsWithLabel:
					NSLocalizedString(@"Text layer contents",@"Photoshop text layer contents property title")
					textValue:str];
				}
				break;

				case 'luni': // unicode layer name
				{
					if(chunklen<4) break;
					int len=[fh readUInt32BE];
					if(chunklen<4+len*2) break;
					layername=[[[NSString alloc] initWithData:[fh readDataOfLength:len*2]
					encoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingUTF16BE)]
					autorelease];
				}
				break;

				case 'lyid': // layer ID name
				break;
				case 'lfx2': // object based effects layer
				break;
				case 'Patt': // patterns
				break;
				case 'clbl': // blend clipping elements
				break;
				case 'infx': // blend interior elements
				break;
				case 'knko': // knockout setting
				break;
				case 'lspf': // protected setting
				break;
				case 'lclr': // sheet color setting
				break;
				case 'fxrp': // reference point
				break;
				case 'grdm': // gradient settings
				break;
				case 'lsct': // section divider setting
				break;
				case 'brst': // channel blending restrictions setting
				break;
				case 'SoCo': // solid color sheet setting
				break;
				case 'PtFl': // pattern fill setting
				break;
				case 'GdFl': // gradient fill setting
				break;
				case 'vmsk': // vector mask setting
				break;

				case 'TySh': // type tool object setting
				{
					[fh skipBytes:50];
					if([fh readUInt16BE]!=50) break; // text descriptor version
					if([fh readUInt32BE]!=16) break; // descriptor version
					int classlen=[fh readUInt32BE];
					[fh skipBytes:classlen*2];
					if([fh readUInt32BE]!=0) break;
					if([fh readUInt32BE]!='TxLr') break;

					int numitems=[fh readUInt32BE];

					if(numitems==0) break;
					if([fh readUInt32BE]!=0) break;
					if([fh readUInt32BE]!='Txt ') break;
					if([fh readUInt32BE]!='TEXT') break;

					int textlen=[fh readUInt32BE];

					NSMutableString *str=[[[NSMutableString alloc] initWithData:[fh readDataOfLength:textlen*2]
					encoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingUTF16BE)]
					autorelease];

					int len=[str length];
					for(int i=0;i<len;i++)
					if([str characterAtIndex:i]=='\r') [str replaceCharactersInRange:NSMakeRange(i,1) withString:@"\n"];

					typetooltext=[XeePropertyItem itemsWithLabel:
					NSLocalizedString(@"Text layer contents",@"Photoshop text layer contents property title")
					textValue:str];

/*					NSData *rest=[fh readDataOfLength:nextchunk-[fh offsetInFile]];
					const uint8_t *restbytes=[rest bytes];
					int restlen=[rest length];
					int offs=XeeOffsetOfStringInMemory("EngineDatatdta",restbytes,restlen);
					if(offs>=0)
					{
						int blocklen=XeeBEUInt32(restbytes+offs+14);
						if(offs+18+blocklen>restlen) break;
//						NSData *block=[rest subdataWithRange:NSMakeRange(offs+18,blocklen)];
						NSMutableData *block=[NSMutableData dataWithData:[rest subdataWithRange:NSMakeRange(offs+18,blocklen)]];
						uint8_t *bytes=[block mutableBytes];
						for(int i=0;i<[block length];i++) if(!isspace(bytes[i])&&bytes[i]<=0x20) bytes[i]='.';
						NSLog(@"%@",[[[NSString alloc] initWithData:block encoding:NSISOLatin1StringEncoding] autorelease]);
					}*/
				}
				break;

				case 'ffxi': // foreign effect ID
				break;
				case 'lnsr': // layer name source setting
				break;
				case 'shpa': // pattern data
				break;
				case 'shmd': // meta data setting
					NSLog(@"found layer metadata");
				break;
				case 'Layr': // layer data - what
				break;
			}
			[fh seekToFileOffset:nextchunk];
		}

		outofbytes:
		if(layername) [props addObject:[XeePropertyItem itemWithLabel:
		NSLocalizedString(@"Layer name",@"Photoshop layer name property title")
		value:layername]];

		[props addObject:[XeePropertyItem itemWithLabel:
		NSLocalizedString(@"Opacity",@"Photoshop layer opacity property title")
		value:[NSString stringWithFormat:@"%d%%",(opacity*100)/255]]];

		NSString *blendname;
		switch(blendmode)
		{
			case 'norm': blendname=NSLocalizedString(@"Normal",@"Photoshop layer normal blending mode name property value"); break;
			case 'dark': blendname=NSLocalizedString(@"Darken",@"Photoshop layer darken blending mode name property value"); break;
			case 'lite': blendname=NSLocalizedString(@"Lighten",@"Photoshop layer lighten blending mode name property value"); break;
			case 'hue ': blendname=NSLocalizedString(@"Hue",@"Photoshop layer hue blending mode name property value"); break;
			case 'sat ': blendname=NSLocalizedString(@"Saturation",@"Photoshop layer normal blending mode name property value"); break;
			case 'colr': blendname=NSLocalizedString(@"Color",@"Photoshop layer color blending mode name property value"); break;
			case 'lum ': blendname=NSLocalizedString(@"Luminosity",@"Photoshop layer luminosity blending mode name property value"); break;
			case 'mul ': blendname=NSLocalizedString(@"Multiply",@"Photoshop layer multiply blending mode name property value"); break;
			case 'scrn': blendname=NSLocalizedString(@"Screen",@"Photoshop layer screen blending mode name property value"); break;
			case 'diss': blendname=NSLocalizedString(@"Dissolve",@"Photoshop layer dissolve blending mode name property value"); break;
			case 'over': blendname=NSLocalizedString(@"Overlay",@"Photoshop layer overlay blending mode name property value"); break;
			case 'hLit': blendname=NSLocalizedString(@"Hard light",@"Photoshop layer hard light blending mode name property value"); break;
			case 'sLit': blendname=NSLocalizedString(@"Soft light",@"Photoshop layer soft light blending mode name property value"); break;
			case 'diff': blendname=NSLocalizedString(@"Difference",@"Photoshop layer difference blending mode name property value"); break;
			case 'smud': blendname=NSLocalizedString(@"Exclusion",@"Photoshop layer exclusion blending mode name property value"); break;
			case 'div ': blendname=NSLocalizedString(@"Color dodge",@"Photoshop layer color dodge blending mode name property value"); break;
			case 'idiv': blendname=NSLocalizedString(@"Color burn",@"Photoshop layer color burn blending mode name property value"); break;
			default:
				blendname=[NSString stringWithFormat:
				NSLocalizedString(@"Unknown (%c%c%c%c)",@"Photoshop layer unknown blending mode name property value"),
				(blendmode>>24)&0xff,(blendmode>>16)&0xff,(blendmode>>8)&0xff,blendmode&0xff];
			break;
		}
		[props addObject:[XeePropertyItem itemWithLabel:
		NSLocalizedString(@"Blending mode",@"Photoshop layer blending mode property title")
		value:blendname]];

		if(adjustmentname) [props addObject:[XeePropertyItem itemWithLabel:
		NSLocalizedString(@"Adjustment layer",@"Photoshop adjustment layer property title")
		value:adjustmentname]];

		if(typetooltext) [props addObjectsFromArray:typetooltext];
		if(typetoolfonts) [props addObjectsFromArray:typetoolfonts];

		[fh seekToFileOffset:nextoffs];
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
	BOOL hasalpha=[self hasAlpha];

	switch(mode)
	{
		case XeePhotoshopBitmapMode:
			image=[[[XeeBitmapRawImage alloc] initWithHandle:[self handleForChannel:0] width:width height:height] autorelease];
			[image setDepthBitmap];
		break;

//		case XeePhotoshopIndexedMode: [self setDepthIndexed:1<<bitdepth]; break;

		case XeePhotoshopGreyscaleMode:
		case XeePhotoshopDuotoneMode:
			image=[[[XeeRawImage alloc] initWithHandle:[self handleForNumberOfChannels:1]
			width:width height:height depth:depth colourSpace:XeeGreyRawColourSpace
			flags:XeeBigEndianRawFlag|(hasalpha?XeeAlphaLastRawFlag:0)|(depth==32?XeeFloatingPointRawFlag:0)]
			autorelease];

			if(mode==XeePhotoshopGreyscaleMode) [image setDepthGrey:depth alpha:hasalpha floating:depth==32?YES:NO];
			else [image setDepth:[NSString stringWithFormat:NSLocalizedString(@"%d bits duotone",@"Description for duotone (Photoshop) images"),depth]
			iconName:@"depth_rgb"];
		break;

		case XeePhotoshopRGBMode:
			image=[[[XeeRawImage alloc] initWithHandle:[self handleForNumberOfChannels:3]
			width:width height:height depth:depth colourSpace:XeeRGBRawColourSpace
			flags:XeeBigEndianRawFlag|(hasalpha?XeeAlphaLastRawFlag:0)|(depth==32?XeeFloatingPointRawFlag:0)]
			autorelease];

			[image setDepthRGB:depth alpha:hasalpha floating:depth==32?YES:NO];
 		break;

		case XeePhotoshopCMYKMode:
			image=[[[XeeRawImage alloc] initWithHandle:[self handleForNumberOfChannels:4]
			width:width height:height depth:depth colourSpace:XeeCMYKRawColourSpace
			flags:XeeBigEndianRawFlag|(hasalpha?XeeAlphaLastRawFlag:0)]
			autorelease];

			[(XeeRawImage *)image setZeroPoint:1 onePoint:0 forChannel:0];
			[(XeeRawImage *)image setZeroPoint:1 onePoint:0 forChannel:1];
			[(XeeRawImage *)image setZeroPoint:1 onePoint:0 forChannel:2];
			[(XeeRawImage *)image setZeroPoint:1 onePoint:0 forChannel:3];

			[image setDepthCMYK:depth alpha:hasalpha];
 		break;

		case XeePhotoshopLabMode:
			image=[[[XeeRawImage alloc] initWithHandle:[self handleForNumberOfChannels:3]
			width:width height:height depth:depth colourSpace:XeeLabRawColourSpace
			flags:XeeBigEndianRawFlag|(hasalpha?XeeAlphaLastRawFlag:0)]
			autorelease];

			[image setDepthLab:depth alpha:hasalpha];
 		break;

		default:
			return nil;
	}

	[image setProperties:[NSArray arrayWithObject:[XeePropertyItem itemWithLabel:
	NSLocalizedString(@"Photoshop layer properties",@"Photoshop layer properties section title")
	value:props identifier:@"pslayer"]]];

	return image;
}

-(CSHandle *)handleForNumberOfChannels:(int)requiredchannels
{
	NSMutableArray *array=[NSMutableArray array];
	for(int i=0;i<requiredchannels;i++)
	{
		CSHandle *fh=[self handleForChannel:i];
		if(!handle) return nil;
		[array addObject:fh];
	}
	CSHandle *alphahandle=[self handleForChannel:-1];
	if(alphahandle) [array addObject:alphahandle];

	if([array count]==1) return [array objectAtIndex:0];
	else return [[[XeeInterleavingHandle alloc] initWithHandles:array elementSize:depth] autorelease];
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

@end
