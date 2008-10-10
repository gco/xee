#import "PDFStream.h"
#import "PDFParser.h"
#import "PDFEncryptionUtils.h"

#import "CSZlibHandle.h"
#import "CSMemoryHandle.h"
#import "CSMultiHandle.h"



@implementation PDFStream

-(id)initWithDictionary:(NSDictionary *)dictionary fileHandle:(CSHandle *)filehandle
reference:(PDFObjectReference *)reference parser:(PDFParser *)owner
{
	if(self=[super init])
	{
		dict=[dictionary retain];
		fh=[filehandle retain];
		offs=[fh offsetInFile];
		ref=[reference retain];
		parser=owner;
	}
	return self;
}

-(void)dealloc
{
	[dict release];
	[fh release];
	[ref release];
	[super dealloc];
}




-(NSDictionary *)dictionary { return dict; }

-(PDFObjectReference *)reference { return ref; }



-(BOOL)isImage
{
	NSString *type=[dict objectForKey:@"Type"];
	NSString *subtype=[dict objectForKey:@"Subtype"];
	return (!type||[type isEqual:@"XObject"])&&subtype&&[subtype isEqual:@"Image"]; // kludge for broken Ghostscript PDFs
}

-(BOOL)isJPEG
{
	return [[self finalFilter] isEqual:@"DCTDecode"];
}

-(BOOL)isTIFF
{
	return [[self finalFilter] isEqual:@"CCITTFaxDecode"];
}

-(NSString *)finalFilter
{
	id filter=[dict objectForKey:@"Filter"];

	if(!filter) return NO;
	else if([filter isKindOfClass:[NSArray class]]) return [filter lastObject];
	else return filter;
}

-(int)bitsPerComponent
{
	NSNumber *val=[dict objectForKey:@"BitsPerComponent"];
	if([val isKindOfClass:[NSNumber class]]) return [val intValue];
	else return 0;
}




-(CSHandle *)handle
{
	return [self handleExcludingLast:NO];
}

-(CSHandle *)JPEGHandle
{
	return [self handleExcludingLast:YES];
}

-(CSHandle *)TIFFHandle
{
	NSDictionary *decodeparms;
	id parmsval=[dict objectForKey:@"DecodeParms"];
	if(!parmsval) decodeparms=[NSDictionary dictionary];
	else if([parmsval isKindOfClass:[NSArray class]]) decodeparms=[parmsval lastObject];
	else decodeparms=parmsval;

//NSLog(@"%@",decodeparms);
	if([[self finalFilter] isEqual:@"CCITTFaxDecode"])
	{
		int k=[decodeparms intValueForKey:@"K" default:0];

		NSData *imagedata=[[self handleExcludingLast:YES] remainingFileContents];
		CSMemoryHandle *header=[CSMemoryHandle memoryHandleForWriting];

		[header writeInt32BE:0x4d4d002a]; // magic
		[header writeInt32BE:0x00000008]; // IFD offset
		[header writeInt16BE:12]; // number of directory entries
		[header writeInt32BE:0x00fe0004]; // newsubfiletype
		[header writeInt32BE:1];
		[header writeInt32BE:0];
		[header writeInt32BE:0x01000004]; // imagewidth
		[header writeInt32BE:1];
		[header writeInt32BE:[decodeparms intValueForKey:@"Columns" default:1728]];
		[header writeInt32BE:0x01010004]; // imagelength
		[header writeInt32BE:1];
		[header writeInt32BE:[dict intValueForKey:@"Height" default:0]];
		[header writeInt32BE:0x01030003]; // compression
		[header writeInt32BE:1];
		[header writeInt32BE:k<0?0x00040000:0x00030000];
		[header writeInt32BE:0x01060003]; // photometricinterpretation
		[header writeInt32BE:1];
		[header writeInt32BE:[decodeparms intValueForKey:@"Blackls1" default:NO]?0x00000000:0x00010000];
		// ^ Wrong way around?
		[header writeInt32BE:0x01110004]; // stripoffsets
		[header writeInt32BE:1];
		[header writeInt32BE:162];
		[header writeInt32BE:0x01160004]; // rowsperstrip
		[header writeInt32BE:1];
		[header writeInt32BE:[dict intValueForKey:@"Height" default:0]];
		[header writeInt32BE:0x01170004]; // stripbytecounts
		[header writeInt32BE:1];
		[header writeInt32BE:[imagedata length]];
		[header writeInt32BE:0x011a0005]; // xresolution
		[header writeInt32BE:1];
		[header writeInt32BE:154];
		[header writeInt32BE:0x011b0005]; // yresolution
		[header writeInt32BE:1];
		[header writeInt32BE:154];
		[header writeInt32BE:0x01280003]; // resolutionunit
		[header writeInt32BE:1];
		[header writeInt32BE:0x00010000];

		if(k<0)
		{
			[header writeInt32BE:0x01250004]; // t6options
			[header writeInt32BE:1];
			[header writeInt32BE:0];
		}
		else
		{
			[header writeInt32BE:0x01240004]; // t4options
			[header writeInt32BE:1];
			[header writeInt32BE:(k==0?0:1)|([dict boolValueForKey:@"EncodedByteAlign" default:NO]?4:0)];
		}

		[header writeInt32BE:0x0000012c]; // resolution
		[header writeInt32BE:0x00000001]; // "

		[header seekToFileOffset:0];

[[[CSMultiHandle multiHandleWithHandles:header,[CSMemoryHandle memoryHandleForReadingData:imagedata],nil]
remainingFileContents] writeToFile:@"/Users/dag/Desktop/test.tif" atomically:NO];

		return [CSMultiHandle multiHandleWithHandles:header,[CSMemoryHandle memoryHandleForReadingData:imagedata],nil];
	}
	else return nil;
}

-(CSHandle *)handleExcludingLast:(BOOL)excludelast
{
	CSHandle *handle=[fh subHandleWithRange:NSMakeRange(offs,[dict intValueForKey:@"Length" default:0])];

	PDFEncryptionHandler *encryption=[parser encryptionHandler];
	if(encryption) handle=[encryption decryptedHandle:handle reference:ref];

	NSArray *filter=[dict arrayForKey:@"Filter"];
	NSArray *decodeparms=[dict arrayForKey:@"DecodeParms"];

	if(filter)
	{
		int count=[filter count];
		if(excludelast) count--;

		for(int i=0;i<count;i++)
		{
			handle=[self handleForFilterName:[filter objectAtIndex:i]
			decodeParms:[decodeparms objectAtIndex:i] parentHandle:handle];
			if(!handle) return nil;
		}
	}

	return handle;
}

-(CSHandle *)handleForFilterName:(NSString *)filtername decodeParms:(NSDictionary *)decodeparms parentHandle:(CSHandle *)parent
{
	if([filtername isEqual:@"FlateDecode"])
	{
		return [self predictorHandleForDecodeParms:decodeparms
		parentHandle:[CSZlibHandle zlibHandleWithHandle:parent]];
	}
	else if([filtername isEqual:@"CCITTFaxDecode"])
	{
		NSLog(@"%@",decodeparms);
		return nil;
	}
//	else if([filtername isEqual:@"LZWDecode"])
//	{
//		return [self predictorHandleForDecodeParms:decodeparms
//		parentHandle:[[[PDFLZWHandle alloc] initWithHandle:parent decodeParms:decodeparms] autorelease]];
//	}
	else if([filtername isEqual:@"ASCII85Decode"])
	{
		return [[[PDFASCII85Handle alloc] initWithHandle:parent] autorelease];
	}
	return nil;
}

-(CSHandle *)predictorHandleForDecodeParms:(NSDictionary *)decodeparms parentHandle:(CSHandle *)parent
{
	if(!decodeparms) return parent;

	NSNumber *predictor=[decodeparms objectForKey:@"Predictor"];
	if(!predictor) return parent;

	int pred=[predictor intValue];
	if(pred==1) return parent;

	NSNumber *columns=[decodeparms objectForKey:@"Columns"];
	NSNumber *colors=[decodeparms objectForKey:@"Colors"];
	NSNumber *bitspercomponent=[decodeparms objectForKey:@"BitsPerComponent"];

	int cols=columns?[columns intValue]:1;
	int comps=colors?[colors intValue]:1;
	int bpc=bitspercomponent?[bitspercomponent intValue]:8;

	if(pred==2) return [[[PDFTIFFPredictorHandle alloc] initWithHandle:parent columns:cols components:comps bitsPerComponent:bpc] autorelease];
	else if(pred>=10&&pred<=15) return [[[PDFPNGPredictorHandle alloc] initWithHandle:parent columns:cols components:comps bitsPerComponent:bpc] autorelease];
	else [NSException raise:@"PDFStreamPredictorException" format:@"PDF Predictor %d not supported",pred];
	return nil;
}



-(NSString *)colourSpaceOrAlternate
{
	id colourspace=[dict objectForKey:@"ColorSpace"];
	return [self _parseColourSpace:colourspace];

}

-(NSString *)subColourSpaceOrAlternate
{
	id colourspace=[dict objectForKey:@"ColorSpace"];

	if(![colourspace isKindOfClass:[NSArray class]]) return nil;
	if([colourspace count]!=4) return nil;
	if(![[colourspace objectAtIndex:0] isEqual:@"Indexed"]) return nil;

	return [self _parseColourSpace:[colourspace objectAtIndex:1]];
}

-(NSString *)_parseColourSpace:(id)colourspace
{
	if([colourspace isKindOfClass:[NSString class]]) return colourspace;
	else if([colourspace isKindOfClass:[NSArray class]])
	{
		int count=[colourspace count];
		if(count<1) return nil;

		NSString *name=[colourspace objectAtIndex:0];
		if([name isEqual:@"ICCBased"])
		{
			PDFStream *def=[colourspace objectAtIndex:1];
			if(![def isKindOfClass:[PDFStream class]]) return nil;
			return [[def dictionary] objectForKey:@"Alternate"];
		}
		else return name;
	}
	else return nil;
}

-(int)numberOfColours
{
	id colourspace=[dict objectForKey:@"ColorSpace"];

	if(![colourspace isKindOfClass:[NSArray class]]) return nil;
	if([colourspace count]!=4) return nil;
	if(![[colourspace objectAtIndex:0] isEqual:@"Indexed"]) return nil;

	return [[colourspace objectAtIndex:2] intValue]+1;
}

-(NSData *)paletteData
{
	id colourspace=[dict objectForKey:@"ColorSpace"];

	if(![colourspace isKindOfClass:[NSArray class]]) return nil;
	if([colourspace count]!=4) return nil;
	if(![[colourspace objectAtIndex:0] isEqual:@"Indexed"]) return nil;

	id palette=[colourspace objectAtIndex:3];
	if([palette isKindOfClass:[PDFStream class]]) return [[palette handle] remainingFileContents];
	else if([palette isKindOfClass:[PDFString class]]) return [palette data];
	else return nil;
}

-(NSString *)description { return [NSString stringWithFormat:@"<Stream with dictionary: %@>",dict]; }

@end




@implementation PDFASCII85Handle

-(void)resetFilter
{
	finalbytes=0;
}

static uint8_t ASCII85NextByte(PDFASCII85Handle *self)
{
	uint8_t b;
	do { b=CSFilterNextByte(); }
	while(!((b>=33&&b<=117)||b=='z'||b=='~'));
	return b;
}

-(uint8_t)produceByte
{
	int byte=pos&3;
	if(byte==0)
	{
		uint8_t c1=ASCII85NextByte(self);

		if(c1=='z') val=0;
		else if(c1=='~') CSFilterEOF();
		else
		{
			uint8_t c2,c3,c4,c5;

			c2=ASCII85NextByte(self);
			if(c2!='~')
			{
				c3=ASCII85NextByte(self);
				if(c3!='~')
				{
					c4=ASCII85NextByte(self);
					if(c4!='~')
					{
						c5=ASCII85NextByte(self);
						if(c5=='~') { c5=33; finalbytes=3; }
					}
					else { c4=c5=33; finalbytes=2; }
				}
				else { c3=c4=c5=33; finalbytes=1; }
			}
			else CSFilterEOF();

			val=((((c1-33)*85+c2-33)*85+c3-33)*85+c4-33)*85+c5-33;
		}
		return val>>24;
	}
	else
	{
		if(finalbytes&&byte>=finalbytes) CSFilterEOF();
		return val>>24-byte*8;
	}
}

@end




@implementation PDFTIFFPredictorHandle

-(id)initWithHandle:(CSHandle *)handle columns:(int)columns
components:(int)components bitsPerComponent:(int)bitspercomp
{
	if(self=[super initWithHandle:handle])
	{
		cols=columns;
		comps=components;
		bpc=bitspercomp;
		if(bpc!=8) [NSException raise:@"PDFTIFFPredictorException" format:@"Bit depth %d not supported for TIFF predictor",bpc];
		if(comps>4||comps<1) [NSException raise:@"PDFTIFFPredictorException" format:@"Color count %d not supported for TIFF predictor",bpc];
	}
	return self;
}

-(uint8_t)produceByte
{
	if(bpc==8)
	{
		int comp=pos%comps;
		if((pos/comps)%cols==0) prev[comp]=CSFilterNextByte();
		else prev[comp]+=CSFilterNextByte();
		return prev[comp];
	}
	return 0;
}

@end



@implementation PDFPNGPredictorHandle

-(id)initWithHandle:(CSHandle *)handle columns:(int)columns
components:(int)components bitsPerComponent:(int)bitspercomp
{
	if(self=[super initWithHandle:handle])
	{
		cols=columns;
		comps=components;
		bpc=bitspercomp;
		if(bpc<8) comps=1;
		if(bpc>8) [NSException raise:@"PDFPNGPredictorException" format:@"Bit depth %d not supported for PNG predictor",bpc];

		prevbuf=malloc(cols*comps+2*comps);
	}
	return self;
}

-(void)dealloc
{
	free(prevbuf);
	[super dealloc];
}

-(void)resetFilter
{
	memset(prevbuf,0,cols*comps+2*comps);
}

-(uint8_t)produceByte
{
	if(bpc<=8)
	{
		int row=pos/(cols*comps);
		int col=pos%(cols*comps);
		int buflen=cols*comps+2*comps;
		int bufoffs=((col-comps*row)%buflen+buflen)%buflen;

		if(col==0)
		{
			type=CSFilterNextByte();
			for(int i=0;i<comps;i++) prevbuf[(i+cols*comps+comps+bufoffs)%buflen]=0;
		}

		int x=CSFilterNextByte();
		int a=prevbuf[(cols*comps+comps+bufoffs)%buflen];
		int b=prevbuf[(comps+bufoffs)%buflen];
		int c=prevbuf[bufoffs];
		int val;

		switch(type)
		{
			case 0: val=x; break;
			case 1: val=x+a; break;
			case 2: val=x+b; break;
			case 3: val=x+(a+b)/2; break;
			case 4:
			{
				int p=a+b-c;
				int pa=iabs(p-a);
				int pb=iabs(p-b);
				int pc=iabs(p-c);

				if(pa<=b&&pa<=pc) val=pa;
				else if(pb<=pc) val=pb;
				else val=pc;
			}
			break;
		}

		prevbuf[bufoffs]=val;
		return val;
	}
	return 0;
}

@end
