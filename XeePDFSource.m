#import "XeePDFSource.h"
#import "PDFParser.h"
#import "XeeRawImage.h"
#import "XeeIndexedRawImage.h"
#import "XeeBitmapRawImage.h"
#import "XeeJPEGLoader.h"
#import "XeeImageIOLoader.h"


static int XeePDFSortPages(id first,id second,void *context)
{
	NSDictionary *order=(NSDictionary *)context;
	NSNumber *firstpage=[order objectForKey:[first reference]];
	NSNumber *secondpage=[order objectForKey:[second reference]];
	if(!firstpage&&!secondpage) return 0;
	else if(!firstpage) return 1;
	else if(!secondpage) return -1;
	else return [firstpage compare:secondpage];
}

@implementation XeePDFSource

+(NSArray *)fileTypes
{
	return [NSArray arrayWithObject:@"pdf"];
}

-(id)initWithFile:(NSString *)pdfname
{
	if(self=[super init])
	{
		filename=[pdfname retain];
		parser=nil;

		[self setIcon:[[NSWorkspace sharedWorkspace] iconForFile:filename]];
		[icon setSize:NSMakeSize(16,16)];

		@try
		{
			parser=[[PDFParser parserForPath:filename] retain];
		}
		@catch(id e) {}

		if(parser) return self;
	}

	[self release];
	return nil;
}

-(void)dealloc
{
	[filename release];
	[parser release];
	[super dealloc];
}

-(void)start
{
	[self startListUpdates];

	@try
	{
		[parser parse];

		if([parser needsPassword])
		{
			for(;;)
			{
				NSString *password=[self demandPassword];
				if(!password) @throw @"Cancelled password request";
				if([parser setPassword:password]) break;
			}
		}

		// Find image objects in object list
		NSMutableArray *images=[NSMutableArray array];
		NSEnumerator *enumerator=[[parser objectDictionary] objectEnumerator];
		id object;
		while(object=[enumerator nextObject])
		{
			if([object isKindOfClass:[PDFStream class]]&&[object isImage])
			[images addObject:object];
		}

		// Traverse page tree to find which images are referenced from which pages
		NSMutableDictionary *order=[NSMutableDictionary dictionary];
		NSDictionary *root=[parser pagesRoot];
		NSMutableArray *stack=[NSMutableArray arrayWithObject:[[root arrayForKey:@"Kids"] objectEnumerator]];
		int page=0;
		while([stack count])
		{
			id curr=[[stack lastObject] nextObject];
			if(!curr) [stack removeLastObject];
			else
			{
				NSString *type=[curr objectForKey:@"Type"];
				if([type isEqual:@"Pages"])
				{
					[stack addObject:[[curr arrayForKey:@"Kids"] objectEnumerator]];
				}
				else if([type isEqual:@"Page"])
				{
					page++;
					NSDictionary *xobjects=[[curr objectForKey:@"Resources"] objectForKey:@"XObject"];
					NSEnumerator *enumerator=[xobjects objectEnumerator];
					id object;
					while(object=[enumerator nextObject])
					{
						if([object isKindOfClass:[PDFStream class]]&&[object isImage])
						[order setObject:[NSNumber numberWithInt:page] forKey:[object reference]];
					}
				}
				else @throw @"Invalid PDF structure";
			}
		}

		// Sort image in page order
		[images sortUsingFunction:XeePDFSortPages context:order];

		enumerator=[images objectEnumerator];
		PDFStream *image;
		while(image=[enumerator nextObject])
		{
			PDFObjectReference *ref=[image reference];
			NSNumber *page=[order objectForKey:ref];
			NSString *name;
			if(page) name=[NSString stringWithFormat:@"Page %@, object %d",page,[ref number]];
			else name=[NSString stringWithFormat:@"Object %d",[ref number]];

			NSString *imgname=[[image dictionary] objectForKey:@"Name"];
			if(imgname) name=[NSString stringWithFormat:@"%@ (%@)",imgname,name];

			[self addEntry:[[[XeePDFEntry alloc] initWithPDFStream:image name:name] autorelease]];
		}
	}
	@catch(id e)
	{
		NSLog(@"Error parsing PDF file %@: %@",filename,e);
	}

	[self endListUpdates];
	[self pickImageAtIndex:0];

	// Don't release parser, as PDFStreams do not retain it
}

-(NSString *)windowTitle
{
	return [NSString stringWithFormat:@"%@ (%@)",[filename lastPathComponent],[currentry descriptiveName]];
}

-(NSString *)windowRepresentedFilename { return filename; }

-(BOOL)canBrowse { return currentry!=nil; }

@end




@implementation XeePDFEntry

-(id)initWithPDFStream:(PDFStream *)stream name:(NSString *)descname
{
	if(self=[super init])
	{
		object=[stream retain];
		name=[descname retain];
		complained=NO;
	}
	return self;
}

-(void)dealloc
{
	[object release];
	[name release];
	[super dealloc];
}

-(NSString *)descriptiveName { return name; }

-(XeeImage *)produceImage
{
	NSDictionary *dict=[object dictionary];
	XeeImage *newimage=nil;
	NSArray *decode=[object decodeArray];
	int bpc=[object bitsPerComponent];

	if([object isJPEG])
	{
		CSHandle *subhandle=[object JPEGHandle];
		if(subhandle) newimage=[[[XeeJPEGImage alloc] initWithHandle:subhandle] autorelease];
	}
	else if([object isJPEG2000])
	{
		CSHandle *subhandle=[object JPEGHandle];
		if(subhandle) newimage=[[[XeeImageIOImage alloc] initWithHandle:subhandle] autorelease];
	}
	else if([object isBitmap]||[object isMask])
	{
		CSHandle *subhandle=[object handle];

		newimage=[[[XeeBitmapRawImage alloc] initWithHandle:subhandle
		width:[dict intValueForKey:@"Width" default:0] height:[dict intValueForKey:@"Height" default:0]]
		autorelease];

		if(decode) [(XeeBitmapRawImage *)newimage setZeroPoint:[[decode objectAtIndex:0] floatValue] onePoint:[[decode objectAtIndex:1] floatValue]];
		else [(XeeBitmapRawImage *)newimage setZeroPoint:0 onePoint:1];

		[newimage setDepthBitmap];
	}
	else if((bpc==8||bpc==16)&&[object isGrey])
	{
		CSHandle *subhandle=[object handle];

		if(subhandle) newimage=[[[XeeRawImage alloc] initWithHandle:subhandle
		width:[dict intValueForKey:@"Width" default:0] height:[dict intValueForKey:@"Height" default:0]
		depth:bpc colourSpace:XeeGreyRawColourSpace flags:XeeNoAlphaRawFlag] autorelease];

		if(decode) [(XeeRawImage *)newimage setZeroPoint:[[decode objectAtIndex:0] floatValue] onePoint:[[decode objectAtIndex:1] floatValue] forChannel:0];

		[newimage setDepthGrey:bpc];
		//[newimage setFormat:@"Raw greyscale // TODO - add format names
	}
	else if((bpc==8||bpc==16)&&[object isRGB])
	{
		CSHandle *subhandle=[object handle];

		if(subhandle) newimage=[[[XeeRawImage alloc] initWithHandle:subhandle
		width:[dict intValueForKey:@"Width" default:0] height:[dict intValueForKey:@"Height" default:0]
		depth:bpc colourSpace:XeeRGBRawColourSpace flags:XeeNoAlphaRawFlag] autorelease];

		if(decode)
		{
			[(XeeRawImage *)newimage setZeroPoint:[[decode objectAtIndex:0] floatValue] onePoint:[[decode objectAtIndex:1] floatValue] forChannel:0];
			[(XeeRawImage *)newimage setZeroPoint:[[decode objectAtIndex:2] floatValue] onePoint:[[decode objectAtIndex:3] floatValue] forChannel:1];
			[(XeeRawImage *)newimage setZeroPoint:[[decode objectAtIndex:4] floatValue] onePoint:[[decode objectAtIndex:5] floatValue] forChannel:2];
		}

		[newimage setDepthRGB:bpc];
	}
	else if((bpc==8||bpc==16)&&[object isCMYK])
	{
		CSHandle *subhandle=[object handle];

		if(subhandle) newimage=[[[XeeRawImage alloc] initWithHandle:subhandle
		width:[dict intValueForKey:@"Width" default:0] height:[dict intValueForKey:@"Height" default:0]
		depth:bpc colourSpace:XeeCMYKRawColourSpace flags:XeeNoAlphaRawFlag] autorelease];

		if(decode)
		{
			[(XeeRawImage *)newimage setZeroPoint:[[decode objectAtIndex:0] floatValue] onePoint:[[decode objectAtIndex:1] floatValue] forChannel:0];
			[(XeeRawImage *)newimage setZeroPoint:[[decode objectAtIndex:2] floatValue] onePoint:[[decode objectAtIndex:3] floatValue] forChannel:1];
			[(XeeRawImage *)newimage setZeroPoint:[[decode objectAtIndex:4] floatValue] onePoint:[[decode objectAtIndex:5] floatValue] forChannel:2];
			[(XeeRawImage *)newimage setZeroPoint:[[decode objectAtIndex:6] floatValue] onePoint:[[decode objectAtIndex:7] floatValue] forChannel:3];
		}

		[newimage setDepthCMYK:bpc alpha:NO];
	}
	else if((bpc==8||bpc==16)&&[object isLab])
	{
		CSHandle *subhandle=[object handle];

		if(subhandle) newimage=[[[XeeRawImage alloc] initWithHandle:subhandle
		width:[dict intValueForKey:@"Width" default:0] height:[dict intValueForKey:@"Height" default:0]
		depth:bpc colourSpace:XeeLabRawColourSpace flags:XeeNoAlphaRawFlag] autorelease];

		if(decode)
		{
			[(XeeRawImage *)newimage setZeroPoint:[[decode objectAtIndex:0] floatValue] onePoint:[[decode objectAtIndex:1] floatValue] forChannel:0];
			[(XeeRawImage *)newimage setZeroPoint:[[decode objectAtIndex:2] floatValue] onePoint:[[decode objectAtIndex:3] floatValue] forChannel:1];
			[(XeeRawImage *)newimage setZeroPoint:[[decode objectAtIndex:4] floatValue] onePoint:[[decode objectAtIndex:5] floatValue] forChannel:2];
		}

		[newimage setDepthLab:bpc alpha:NO];
	}
	else if([object isIndexed])
	{
		NSString *subcolourspace=[object subColourSpaceOrAlternate];
		if([subcolourspace isEqual:@"DeviceRGB"]||[subcolourspace isEqual:@"CalRGB"])
		{
			int colours=[object numberOfColours];
			NSData *palettedata=[object paletteData];

			if(palettedata)
			{
				const uint8_t *palettebytes=[palettedata bytes];
				int count=[palettedata length]/3;
				if(count>256) count=256;

				XeePalette *pal=[XeePalette palette];
				for(int i=0;i<count;i++)
				[pal setColourAtIndex:i red:palettebytes[3*i] green:palettebytes[3*i+1] blue:palettebytes[3*i+2]];

				int subwidth=[[dict objectForKey:@"Width"] intValue];
				int subheight=[[dict objectForKey:@"Height"] intValue];
				CSHandle *subhandle=[object handle];

				if(subhandle) newimage=[[[XeeIndexedRawImage alloc] initWithHandle:subhandle
				width:subwidth height:subheight depth:bpc palette:pal] autorelease];
				[newimage setDepthIndexed:colours];
			}
		}
	}

	if(!newimage&&!complained)
	{
		NSLog(@"Unsupported image in PDF: ColorSpace=%@, BitsPerComponent=%@, Filter=%@, DecodeParms=%@",
		[dict objectForKey:@"ColorSpace"],[dict objectForKey:@"BitsPerComponent"],[dict objectForKey:@"Filter"],[dict objectForKey:@"DecodeParms"]);
		complained=YES;
	}

	return newimage;
}


@end
