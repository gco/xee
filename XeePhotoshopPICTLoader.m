#import "XeePhotoshopPICTLoader.h"
#import "XeeQuicktimeLoader.h"
#import "XeeImageIOLoader.h"

@implementation XeePhotoshopPICTImage

+(NSArray *)fileTypes
{
	return nil;
}

+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;
{
	for(int offs=0;offs<=512;offs+=512)
	{
		if([block length]>offs+18)
		{
			const uint8_t *bytes=(const uint8_t *)[block bytes]+offs;
			if(bytes[10]==0x00&&bytes[11]==0x11&&bytes[12]==0x02
			&&bytes[13]==0xff&&bytes[14]==0x0c&&bytes[15]==0x00
			&&bytes[16]==0xff&&bytes[17]==0xfe) return YES;
		}
	}
	return NO;
}

-(id)init
{
	if(self=[super init])
	{
		image=nil;
	}
	return self;
}

-(void)dealloc
{
	[image release];
	[super dealloc];
}

-(void)load
{
	CSHandle *fh=[self handle];
//[[[[fh copy] autorelease] remainingFileContents] writeToFile:@"/Users/dag/Desktop/ps.pict" atomically:NO];

	/*int size=*/[fh readUInt16BE];
	int top=[fh readUInt16BE];
	int left=[fh readUInt16BE];
	int bottom=[fh readUInt16BE];
	int right=[fh readUInt16BE];
	int versionop=[fh readUInt16BE];
	int version=[fh readUInt16BE];
	int headerop=[fh readUInt16BE];
	int headerversion=[fh readUInt16BE];

	if(versionop!=0x0011||version!=0x02ff||headerop==0x0c00||headerversion!=0xfffe)
	{
		[fh skipBytes:512-18+2];
		top=[fh readUInt16BE];
		left=[fh readUInt16BE];
		bottom=[fh readUInt16BE];
		right=[fh readUInt16BE];
		[fh skipBytes:8];
	}

	[fh skipBytes:22];

	width=right-left;
	height=bottom-top;

	[self setFormat:@"PICT"];

	XeeImageLoaderHeaderDone();

	image=[[XeeBitmapImage alloc] initWithType:XeeBitmapTypeARGB8 width:width height:height];

	for(int y=0;y<height;y++)
	{
		uint32_t *data=(uint32_t *)XeeImageDataRow(image,y);
		for(int x=0;x<width;x++) *data++=XeeMakeARGB8(0xff,0,0,0);
		XeeImageLoaderYield();
	}

	int last_alpha_y=0; // ugly hack

	for(;;)
	{
		int opcode=[fh readUInt16BE];
		switch(opcode)
		{
			case 0x0001: // clip region
			{
				int size=[fh readUInt16BE];
				[fh skipBytes:size-2];
			}
			break;

			case 0x00a1: // long comment
			{
				/*int kind=*/[fh readUInt16BE];
				int size=[fh readUInt16BE];
				[fh skipBytes:size];
			}
			break;

			case 0x8201: // uncompressed quicktime
			{
				uint32_t datasize=[fh readUInt32BE];
				off_t nextop=[fh offsetInFile]+datasize;

				[fh skipBytes:50];

				int headsize=[fh readUInt32BE];
				if(headsize<86) [self fallback];
				off_t datastart=[fh offsetInFile]+headsize-4;

				uint32_t codec=[fh readUInt32BE];
				if(codec!='rle ') [self fallback];

				[fh skipBytes:12];

				uint32_t vendor=[fh readUInt32BE];
				if(vendor!='appl') [self fallback];

				[fh skipBytes:8];

				/*int alphawidth=*/[fh readUInt16BE];
				int alphaheight=[fh readUInt16BE];

				[fh skipBytes:46];

				int bitdepth=[fh readUInt16BE];
				if(bitdepth!=40) [self fallback];

				[fh seekToFileOffset:datastart+4];

				int startrow=0;

				for(;;)
				{
					int flags=[fh readUInt16BE];
					int numrows=alphaheight;
//NSLog(@"%x %@",flags,[[[fh copy] autorelease] readDataOfLength:16]);
					if(flags&0x0008)
					{
						startrow+=[fh readUInt16BE]; // ???
						[fh skipBytes:2];
						numrows=[fh readUInt16BE];
						[fh skipBytes:2];
					}

					for(int row=0;row<numrows;row++)
					{
						int skip=[fh readUInt8];
NSLog(@"%d: %d",row+startrow+last_alpha_y,skip);
						if(skip==0) goto end;

						uint32_t *data=(uint32_t *)XeeImageDataRow(image,row+startrow+last_alpha_y);
						data+=skip-1;

//NSLog(@"row %d",row);
						for(;;)
						{
							uint8_t pixels[4];
							int code=[fh readInt8];
//NSLog(@"code %d",code);
							if(code==-1) break;
							else if(code==0) data+=[fh readUInt8];
							else if(code<0)
							{
								[fh readBytes:4 toBuffer:pixels];
								for(int i=0;i<-code;i++)
								{
									*data++=XeeMakeARGB8(pixels[0],0,0,0);
									*data++=XeeMakeARGB8(pixels[1],0,0,0);
									*data++=XeeMakeARGB8(pixels[2],0,0,0);
									*data++=XeeMakeARGB8(pixels[3],0,0,0);
								}
							}
							else
							{
								for(int i=0;i<code;i++)
								{
									[fh readBytes:4 toBuffer:pixels];
									*data++=XeeMakeARGB8(pixels[0],0,0,0);
									*data++=XeeMakeARGB8(pixels[1],0,0,0);
									*data++=XeeMakeARGB8(pixels[2],0,0,0);
									*data++=XeeMakeARGB8(pixels[3],0,0,0);
								}
							}
						}
					}
					startrow+=numrows;
					XeeImageLoaderYield();
				}
				end:
				last_alpha_y+=alphaheight;
				[fh seekToFileOffset:nextop];
			}
			break;

			case 0x0098: // packbits rectangle
			{
				[fh skipBytes:2];
				int top=[fh readUInt16BE];
				int left=[fh readUInt16BE];
				int bottom=[fh readUInt16BE];
				int right=[fh readUInt16BE];
				[fh skipBytes:2];
				int packtype=[fh readUInt16BE];
				[fh skipBytes:14];
				int bits=[fh readUInt16BE];
				int comps=[fh readUInt16BE];
				int compsize=[fh readUInt16BE];
				[fh skipBytes:14];

				if(packtype!=0||bits!=8||comps!=1||compsize!=8) [self fallback];

				uint8_t palette[3*256];
				[fh skipBytes:4];
				int numcols=[fh readUInt16BE]+1;
				if(numcols>256) [self fallback];

				for(int i=0;i<numcols;i++)
				{
					int index=[fh readUInt16BE];
					if(index>=numcols) [fh skipBytes:6];
					else
					{
						palette[3*i+0]=[fh readInt16BE]>>8;
						palette[3*i+1]=[fh readInt16BE]>>8;
						palette[3*i+2]=[fh readInt16BE]>>8;
					}
				}

				if([fh readUInt16BE]!=top) [self fallback];
				if([fh readUInt16BE]!=left) [self fallback];
				if([fh readUInt16BE]!=bottom) [self fallback];
				if([fh readUInt16BE]!=right) [self fallback];
				if([fh readUInt16BE]!=top) [self fallback];
				if([fh readUInt16BE]!=left) [self fallback];
				if([fh readUInt16BE]!=bottom) [self fallback];
				if([fh readUInt16BE]!=right) [self fallback];

				/*int mode=*/[fh readUInt16BE];

				int rectheight=bottom-top;
				int rectwidth=right-left;

				for(int y=0;y<rectheight;y++)
				{
					uint32_t *data=(uint32_t *)XeeImageDataRow(image,y+top);
					data+=left;

					int bytes;
					if(0) bytes=[fh readUInt8];
					else bytes=[fh readUInt16BE];
					off_t nextline=[fh offsetInFile]+bytes;

					int bytesleft=rectwidth;
					while(bytesleft>0)
					{
						int code=[fh readInt8];
						if(code>0)
						{
							int len=code+1;
							if(len>bytesleft) len=bytesleft;
							for(int i=0;i<len;i++)
							{
								uint8_t val=[fh readUInt8];
								uint8_t r=palette[3*val+0],g=palette[3*val+1],b=palette[3*val+2];
								*data++=XeeMakeARGB8(XeeGetAFromARGB8(*data),r,g,b);
							}
							bytesleft-=len;
						}
						else
						{
							int len=-code+1;
							if(len>bytesleft) len=bytesleft;
							uint8_t val=[fh readUInt8];
							uint8_t r=palette[3*val+0],g=palette[3*val+1],b=palette[3*val+2];
							for(int i=0;i<len;i++)
							{
								*data++=XeeMakeARGB8(XeeGetAFromARGB8(*data),r,g,b);
							}
							bytesleft-=len;
						}
					}
					[fh seekToFileOffset:nextline];
					XeeImageLoaderYield();
				}
				if([fh offsetInFile]&1) [fh skipBytes:1];
			}
			break;

			case 0x009a: // directbits rectangle
			{
				[fh skipBytes:6];
				int top=[fh readUInt16BE];
				int left=[fh readUInt16BE];
				int bottom=[fh readUInt16BE];
				int right=[fh readUInt16BE];
				[fh skipBytes:2];
				int packtype=[fh readUInt16BE];
				[fh skipBytes:14];
				int bits=[fh readUInt16BE];
				int comps=[fh readUInt16BE];
				int compsize=[fh readUInt16BE];
				[fh skipBytes:12];

				if(packtype!=4||bits!=32||comps!=3||compsize!=8) [self fallback];

				if([fh readUInt16BE]!=top) [self fallback];
				if([fh readUInt16BE]!=left) [self fallback];
				if([fh readUInt16BE]!=bottom) [self fallback];
				if([fh readUInt16BE]!=right) [self fallback];
				if([fh readUInt16BE]!=top) [self fallback];
				if([fh readUInt16BE]!=left) [self fallback];
				if([fh readUInt16BE]!=bottom) [self fallback];
				if([fh readUInt16BE]!=right) [self fallback];

				/*int mode=*/[fh readUInt16BE];

				int rectheight=bottom-top;
				int rectwidth=right-left;

				for(int y=0;y<rectheight;y++)
				{
					uint8_t buffer[rectwidth*3];
					uint8_t *ptr=buffer;

					int bytes;
					if(0) bytes=[fh readUInt8];
					else bytes=[fh readUInt16BE];
					off_t nextline=[fh offsetInFile]+bytes;

					int bytesleft=rectwidth*3;
					while(bytesleft>0)
					{
						int code=[fh readInt8];
						if(code>0)
						{
							int len=code+1;
							if(len>bytesleft) len=bytesleft;
							for(int i=0;i<len;i++) *ptr++=[fh readUInt8];
							bytesleft-=len;
						}
						else
						{
							int len=-code+1;
							if(len>bytesleft) len=bytesleft;
							uint8_t val=[fh readUInt8];
							for(int i=0;i<len;i++) *ptr++=val;
							bytesleft-=len;
						}
					}

					uint32_t *data=(uint32_t *)XeeImageDataRow(image,y+top);
					data+=left;

					for(int x=0;x<rectwidth;x++)
					{
						*data++=XeeMakeARGB8(XeeGetAFromARGB8(*data),buffer[0*rectwidth+x],
						buffer[1*rectwidth+x],buffer[2*rectwidth+x]);
					}

					[fh seekToFileOffset:nextline];
					XeeImageLoaderYield();
				}
				if([fh offsetInFile]&1) [fh skipBytes:1];
			}
			break;

			case 0x00ff:
				[image setCompleted];
				[self addSubImage:image];
				XeeImageLoaderDone(YES);
			break;

/*			case 0x001c: //HiliteMode
			case 0x001e: //DefHilite
				// no data
			break;*/

			default:
				NSLog(@"Unsupported PICT opcode %04x at %d",opcode,(int)[fh offsetInFile]-2);
				[self fallback]; // give up and use system handling
				//[NSException raise:@"XeePhotoshopPICTLoaderException" format:@"Unsupported PICT opcode %04x at %d",opcode,(int)[fh offsetInFile]-2];
			break;
		}
	}
}

-(void)fallback
{
NSLog(@"falling back for %@",ref);
	[image release];
	image=nil;

	[handle seekToFileOffset:0];
//	XeeImage *fallbackimage=[[[XeeQuicktimeImage alloc] initWithHandle:handle ref:ref attributes:attrs] autorelease];
	XeeImage *fallbackimage=[[[XeeImageIOImage alloc] initWithHandle:handle ref:ref attributes:attrs] autorelease];
	if(!fallbackimage) XeeImageLoaderDone(NO);

	[self addSubImage:fallbackimage];
	[self runLoaderOnSubImage:fallbackimage];
	XeeImageLoaderDone(YES);
}

@end
