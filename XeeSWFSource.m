#import "XeeSWFSource.h"
#import "XeeJPEGLoader.h"
#import "XeeRawImage.h"
#import "XeeIndexedRawImage.h"

#import <XADMaster/CSMultiHandle.h>
#import <XADMaster/CSZlibHandle.h>


@implementation XeeSWFSource

+(NSArray *)fileTypes
{
	return [NSArray arrayWithObject:@"swf"];
}

-(id)initWithFile:(NSString *)swfname
{
	if(self=[super init])
	{
		filename=[swfname retain];
		parser=nil;

		[self setIcon:[[NSWorkspace sharedWorkspace] iconForFile:filename]];
		[icon setSize:NSMakeSize(16,16)];

		@try
		{
			parser=[[SWFParser parserForPath:filename] retain];
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
		CSMemoryHandle *jpegtables=nil;
		CSHandle *fh=[parser handle];

		int tag,n=0;
		while(tag=[parser nextTag])
		switch(tag)
		{
			case SWFJPEGTables:
				jpegtables=[CSMemoryHandle memoryHandleForReadingData:[fh readDataOfLength:[parser tagLength]-2]];
			break;

			case SWFDefineBitsJPEGTag:
			{
				[fh skipBytes:4];
				CSHandle *subhandle=[fh subHandleOfLength:[parser tagBytesLeft]];

				[self addEntry:[[[XeeSWFJPEGEntry alloc] initWithHandle:
				[CSMultiHandle multiHandleWithHandles:[[jpegtables copy] autorelease],subhandle,nil]
				name:[NSString stringWithFormat:@"Image %d",n++]] autorelease]];
			}
			break;

			case SWFDefineBitsJPEG3Tag:
			case SWFDefineBitsJPEG2Tag:
			{
				[fh skipBytes:2];

				int alphaoffs=0;
				if(tag==SWFDefineBitsJPEG3Tag) alphaoffs=[fh readUInt32LE];

				int first=[fh readUInt16BE];
				if(first==0xffd9)
				{
					[fh skipBytes:2];

					[self addEntry:[[[XeeSWFJPEGEntry alloc] initWithHandle:
					[fh subHandleOfLength:[parser tagBytesLeft]]
					name:[NSString stringWithFormat:@"Image %d",n++]] autorelease]];
				}
				else if(first==0xffd8)
				{
					CSMemoryHandle *tables=[CSMemoryHandle memoryHandleForWriting];
					[tables writeUInt16BE:first];
					for(;;)
					{
						int marker=[fh readUInt16BE];
						if(marker==0xffd9||marker==0xffda)
						{
							if(marker==0xffd9) [fh skipBytes:2];
							else [tables writeUInt16BE:marker];
							[tables seekToFileOffset:0];

							CSHandle *subhandle=[fh subHandleOfLength:[parser tagBytesLeft]];

							[self addEntry:[[[XeeSWFJPEGEntry alloc] initWithHandle:
							[CSMultiHandle multiHandleWithHandles:tables,subhandle,nil]
							name:[NSString stringWithFormat:@"Image %d",n++]] autorelease]];

							break;
						}
						else
						{
							int len=[fh readUInt16BE];
							[tables writeUInt16BE:marker];
							[tables writeUInt16BE:len];
							for(int i=0;i<len-2;i++) [tables writeUInt8:[fh readUInt8]];
						}
					}
				}
				else NSLog(@"Error loading SWF file: invalid JPEG data in tag %d",[parser tag]);
			}
			break;

			case SWFDefineBitsLosslessTag:
			case SWFDefineBitsLossless2Tag:
			{
				[fh skipBytes:2];
				int formatnum=[fh readUInt8];

				switch(formatnum)
				{
					case 3:
						if(tag==SWFDefineBitsLosslessTag)
						[self addEntry:[[[XeeSWFLossless3Entry alloc] initWithHandle:
						[fh subHandleOfLength:[parser tagBytesLeft]]
						name:[NSString stringWithFormat:@"Image %d",n++]] autorelease]];
						else
						[self addEntry:[[[XeeSWFLossless3AlphaEntry alloc] initWithHandle:
						[fh subHandleOfLength:[parser tagBytesLeft]]
						name:[NSString stringWithFormat:@"Image %d",n++]] autorelease]];
					break;

					case 4:
						NSLog(@"Error loading SWF file: unsupported lossless format 4. Please send the author of this program the file, so he can add support for it.");
					break;

					case 5:
						if(tag==SWFDefineBitsLosslessTag)
						[self addEntry:[[[XeeSWFLossless5Entry alloc] initWithHandle:
						[fh subHandleOfLength:[parser tagBytesLeft]]
						name:[NSString stringWithFormat:@"Image %d",n++]] autorelease]];
						else
						[self addEntry:[[[XeeSWFLossless5AlphaEntry alloc] initWithHandle:
						[fh subHandleOfLength:[parser tagBytesLeft]]
						name:[NSString stringWithFormat:@"Image %d",n++]] autorelease]];
					break;

					default:
						NSLog(@"Error loading SWF file: unsupported lossless format %d",formatnum);
					break;
				}
			}
			break;
		}
	}
	@catch(id e)
	{
		NSLog(@"Error parsing SWF file %@: %@",filename,e);
	}

	[self endListUpdates];
	[self pickImageAtIndex:0];

	[parser release];
	parser=nil;
}

-(NSString *)windowTitle
{
	return [NSString stringWithFormat:@"%@ (%@)",[filename lastPathComponent],[currentry descriptiveName]];
}

-(NSString *)windowRepresentedFilename { return filename; }

-(BOOL)canBrowse { return currentry!=nil; }

@end



@implementation XeeSWFEntry

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)descname
{
	if(self=[super init])
	{
		originalhandle=[handle retain];
		name=[descname retain];
	}
	return self;
}

-(void)dealloc
{
	[originalhandle release];
	[name release];
	[super dealloc];
}

-(NSString *)descriptiveName { return name; }

-(CSHandle *)newHandle { return [[originalhandle copy] autorelease]; }

@end



@implementation XeeSWFJPEGEntry

-(XeeImage *)produceImage
{
	XeeJPEGImage *image=[[[XeeJPEGImage alloc] initWithHandle:[self newHandle]] autorelease];
	[image setFormat:@"SWF JPEG"];
	return image;
}

@end



@implementation XeeSWFLossless3Entry

-(XeeImage *)produceImage
{
	CSHandle *fh=[self newHandle];

	int framewidth=[fh readUInt16LE];
	int frameheight=[fh readUInt16LE];
	int numcols=[fh readUInt8];

	CSZlibHandle *zh=[CSZlibHandle zlibHandleWithHandle:fh];

	XeePalette *pal=[XeePalette palette];
	for(int i=0;i<numcols+1;i++)
	[pal setColourAtIndex:i red:[zh readUInt8] green:[zh readUInt8] blue:[zh readUInt8]];

	XeeIndexedRawImage *image=[[[XeeIndexedRawImage alloc] initWithHandle:zh width:framewidth height:frameheight
	palette:pal bytesPerRow:(framewidth+3)&~3] autorelease];

	[image setDepthIndexed:numcols+1];
	[image setFormat:@"SWF Lossless"];

	return image;
}

@end



@implementation XeeSWFLossless3AlphaEntry

-(XeeImage *)produceImage
{
	CSHandle *fh=[self newHandle];

	int framewidth=[fh readUInt16LE];
	int frameheight=[fh readUInt16LE];
	int numcols=[fh readUInt8];

	CSZlibHandle *zh=[CSZlibHandle zlibHandleWithHandle:fh];

	XeePalette *pal=[XeePalette palette];
	for(int i=0;i<numcols+1;i++)
	[pal setColourAtIndex:i red:[zh readUInt8] green:[zh readUInt8] blue:[zh readUInt8] alpha:[zh readUInt8]];

	XeeIndexedRawImage *image=[[[XeeIndexedRawImage alloc] initWithHandle:zh width:framewidth height:frameheight
	palette:pal bytesPerRow:(framewidth+3)&~3] autorelease];

	[image setDepthIndexed:numcols+1];
	[image setFormat:@"SWF Lossless"];

	return image;
}

@end



@implementation XeeSWFLossless5Entry

-(XeeImage *)produceImage
{
	CSHandle *fh=[self newHandle];

	int framewidth=[fh readUInt16LE];
	int frameheight=[fh readUInt16LE];

	CSZlibHandle *zh=[CSZlibHandle zlibHandleWithHandle:fh];

	XeeRawImage *image=[[[XeeRawImage alloc] initWithHandle:zh width:framewidth height:frameheight
	depth:8 colourSpace:XeeRGBRawColourSpace flags:XeeAlphaFirstRawFlag|XeeSkipAlphaRawFlag] autorelease];

	[image setDepthRGB:8 alpha:NO floating:NO];
	[image setFormat:@"SWF Lossless"];

	return image;
}

@end

@implementation XeeSWFLossless5AlphaEntry

-(XeeImage *)produceImage
{
	CSHandle *fh=[self newHandle];

	int framewidth=[fh readUInt16LE];
	int frameheight=[fh readUInt16LE];

	CSZlibHandle *zh=[CSZlibHandle zlibHandleWithHandle:fh];

	XeeRawImage *image=[[[XeeRawImage alloc] initWithHandle:zh width:framewidth height:frameheight
	depth:8 colourSpace:XeeRGBRawColourSpace flags:XeeAlphaFirstRawFlag] autorelease];

	[image setDepthRGB:8 alpha:YES floating:NO];
	[image setFormat:@"SWF Lossless"];

	return image;
}

@end
