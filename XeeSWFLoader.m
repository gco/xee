#import "XeeSWFLoader.h"
#import "XeeJPEGLoader.h"
#import "XeeRawImage.h"
#import "XeeIndexedRawImage.h"
#import "CSMultiHandle.h"
#import "CSZlibHandle.h"


@implementation XeeSWFImage

+(NSArray *)fileTypes
{
	return [NSArray arrayWithObjects:@"swf",nil];
}

+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes
{
	if([block length]>4)
	{
		const char *magic=[block bytes];
		if((magic[0]=='F'||magic[0]=='C')&&magic[1]=='W'&&magic[2]=='S') return YES;
	}
	return NO;
}

-(id)init
{
	if(self=[super init])
	{
		jpegtables=nil;
	}
	return self;
}

-(void)dealloc
{
	[jpegtables release];
	[parser release];
	[super dealloc];
}

-(void)load
{
	parser=[[SWFParser alloc] initWithHandle:[self handle]];
	if(!parser) { XeeImageLoaderDone(NO); }
	CSHandle *fh=[parser handle];

	[self setFormat:@"SWF"];

	int tag;
	while(tag=[parser nextTag])
	switch(tag)
	{
		case SWFJPEGTables:
			jpegtables=[[CSMemoryHandle alloc] initWithData:[fh readDataOfLength:[parser tagLength]-2]];
		break;

		case SWFDefineBitsJPEGTag:
		{
			[fh skipBytes:4];
			CSHandle *subhandle=[fh subHandleOfLength:[parser tagBytesLeft]];
			XeeJPEGImage *image=[[[XeeJPEGImage alloc] initWithHandle:
			[CSMultiHandle multiHandleWithHandles:[[jpegtables copy] autorelease],subhandle,nil]] autorelease];
			[self addAndLoadSubImage:image];
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
				XeeJPEGImage *image=[[[XeeJPEGImage alloc] initWithHandle:
				[fh subHandleOfLength:[parser tagBytesLeft]]] autorelease];
				[self addAndLoadSubImage:image];
			}
			else if(first==0xffd8)
			{
				CSMemoryHandle *tables=[CSMemoryHandle memoryHandleForWriting];
				[tables writeUInt16BE:first];
				for(;;)
				{
					int marker=[fh readUInt16BE];
					if(marker==0xffd9)
					{
						[fh skipBytes:2];
						[tables seekToFileOffset:0];
						CSHandle *subhandle=[fh subHandleOfLength:[parser tagBytesLeft]];
						XeeJPEGImage *image=[[[XeeJPEGImage alloc] initWithHandle:
						[CSMultiHandle multiHandleWithHandles:tables,subhandle,nil]] autorelease];
						[self addAndLoadSubImage:image];
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
			else NSLog(@"XeeSWFImage: invalid JPEG data in tag %d",[parser tag]);
		}
		break;

		case SWFDefineBitsLosslessTag:
		case SWFDefineBitsLossless2Tag:
		{
			[fh skipBytes:2];
			int formatnum=[fh readUInt8];
			int framewidth=[fh readUInt16LE];
			int frameheight=[fh readUInt16LE];

			XeeImage *image=nil;
			switch(formatnum)
			{
				case 3:
				{
					int numcols=[fh readUInt8];
					CSZlibHandle *zh=[CSZlibHandle zlibHandleWithHandle:fh];
					XeePalette *pal=[XeePalette palette];
					for(int i=0;i<numcols;i++)
					{
						if(tag==SWFDefineBitsLosslessTag)
						{
							int r=[zh readUInt8];
							int g=[zh readUInt8];
							int b=[zh readUInt8];
							[pal setColourAtIndex:i red:r green:g blue:b];
						}
						else
						{
							int r=[zh readUInt8];
							int g=[zh readUInt8];
							int b=[zh readUInt8];
							int a=[zh readUInt8];
							[pal setColourAtIndex:i red:r green:g blue:b alpha:a];
						}
					}
					for(int i=numcols;i<256;i++) [pal setColourAtIndex:i red:255 green:255 blue:255];

					image=[[[XeeIndexedRawImage alloc] initWithHandle:zh width:framewidth height:frameheight
					palette:pal bytesPerRow:(framewidth+3)&~3] autorelease];
					[image setDepthIndexed:numcols];
				}
				break;

				case 4:
					NSLog(@"XeeSWFImage: unsupported lossless format 4. Please send the author of this program the file, so he can add support for it.");
				break;

				case 5:
				{
					CSZlibHandle *zh=[CSZlibHandle zlibHandleWithHandle:fh];

					image=[[[XeeRawImage alloc] initWithHandle:zh width:framewidth height:frameheight
					depth:8 colourSpace:XeeRGBRawColourSpace
					flags:XeeAlphaFirstRawFlag|(tag==SWFDefineBitsLossless2Tag?XeeSkipAlphaRawFlag:0)] autorelease];
					[image setDepthRGB:8 alpha:tag==SWFDefineBitsLossless2Tag floating:NO];
				}
				break;

				default:
					NSLog(@"XeeSWFImage: unsupported lossless format %d",formatnum);
				break;
			}
			[self addAndLoadSubImage:image];
		}
		break;

		default:
			XeeImageLoaderYield();
		break;
	}

	[jpegtables release];
	jpegtables=nil;
	[parser release];
	parser=nil;

	XeeImageLoaderDone(YES);
}

-(void)addAndLoadSubImage:(XeeImage *)image
{
	if(!image)
	{
		NSLog(@"XeeSWFImage error: Loading image from tag %d failed.",[parser tag]);
		return;
	}

	[self addSubImage:image];

	if([subimages count]==1) { XeeImageLoaderHeaderDone(); }
	else
	{
		[self triggerPropertyChangeAction];
		XeeImageLoaderYield();
	}

	[self runLoaderOnSubImage:image];
}

@end
