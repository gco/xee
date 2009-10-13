#import "XeeXPMLoader.h"

#import <XADMaster/XADRegex.h>

static int ConvertHex(int x)
{
	if(x>='0'&&x<='9') return x-'0';
	else if(x>='A'&&x<='F') return x-'A'+10;
	else if(x>='a'&&x<='f') return x-'a'+10;
	else return 0;
}

@implementation XeeXPMImage

+(NSArray *)fileTypes
{
	return [NSArray arrayWithObject:@"xpm"];
}

+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;
{
	const unsigned char *head=[block bytes];
	int len=[block length];

	if(len>=9&&!memcmp(head,"/* XPM */",9)) return YES;
	if(len>=6&&!memcmp(head,"! XPM2",6)) return YES;
	if(len>=8&&!memcmp(head,"#define ",8))
	{
		return [[[[NSString alloc] initWithData:block encoding:NSASCIIStringEncoding] autorelease]
		matchedByPattern:@"^#define [^_ \t\r\n]+_format 1"];
//		return [[[[NSString alloc] initWithData:block encoding:NSASCIIStringEncoding] autorelease]
//		matchedByPattern:@"static char *[ \t]+[^ \t\r\n]_colors\\[\\]"];
	}

	return NO;
}

+(NSDictionary *)colourDictionary
{
	static NSDictionary *dict=nil;
	if(!dict)
	{
		NSMutableDictionary *newdict=[NSMutableDictionary dictionary];

		NSString *string=[NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"rgb.txt" ofType:nil]
		encoding:NSASCIIStringEncoding error:NULL];

		XADRegex *regex=[XADRegex regexWithPattern:@"\n[ \t]*([0-9]+)[ \t]+([0-9]+)[ \t]+([0-9]+)[ \t]+([^\n]+)"];
		[regex beginMatchingString:string];
		while([regex matchNext])
		{
			uint32_t col=XeeMakeNRGB8([[regex stringForMatch:1] intValue],[[regex stringForMatch:2] intValue],[[regex stringForMatch:3] intValue]);
			[newdict setObject:[NSNumber numberWithUnsignedInt:col] forKey:[[regex stringForMatch:4] lowercaseString]];
		}

		[newdict setObject:[NSNumber numberWithUnsignedInt:0] forKey:@"None"];

		dict=[[NSDictionary dictionaryWithDictionary:newdict] retain];
	}
	return dict;
}

-(void)load
{
	CSHandle *fh=[self handle];

	NSString *firstline=[fh readLineWithEncoding:NSASCIIStringEncoding];

	if([firstline hasPrefix:@"/* XPM */"]) version=3;
	else if([firstline hasPrefix:@"! XPM2"]) version=2;
	else version=1;

	int numcolours=0,numchars=0;
	NSMutableDictionary *cols=nil;

	if(version!=1)
	{
		NSArray *props=[[self nextLine] substringsCapturedByPattern:@"^([0-9]+)[ \t]+([0-9]+)[ \t]+([0-9]+)[ \t]+([0-9]+)"];
		if(!props) return;

		width=[[props objectAtIndex:1] intValue];
		height=[[props objectAtIndex:2] intValue];
		numcolours=[[props objectAtIndex:3] intValue];
		numchars=[[props objectAtIndex:4] intValue];

		[self setFormat:@"XPM"];
		[self setDepthIndexed:numcolours];

		XeeImageLoaderHeaderDone();

		[self allocWithType:XeeBitmapTypeARGB8 width:width height:height];

		cols=[NSMutableDictionary dictionary];

		for(int i=0;i<numcolours;i++)
		{
			NSString *line=[self nextLine];
			NSString *code=[line substringWithRange:NSMakeRange(0,numchars)];
			NSArray *matches=[line substringsCapturedByPattern:@"[ \t]+c[ \t]+(#([0-9a-fA-F]+)|[^ \t]+)"];

			if(matches)
			{
				NSNumber *col=nil;

				NSString *hex=[matches objectAtIndex:2];
				if(hex!=[XADRegex null]) col=[self parseHexColour:hex];
				else
				{
					NSString *name=[[matches objectAtIndex:1] lowercaseString];
					if([name isEqual:@"none"]) transparent=YES;
					col=[[XeeXPMImage colourDictionary] objectForKey:name];
				}

				if(col) [cols setObject:col forKey:code];
			}
		}
	}
	else
	{
		int numcolours=0;

		for(;;)
		{
			NSString *line=[fh readLineWithEncoding:NSASCIIStringEncoding];
			NSArray *matches;

			if(matches=[line substringsCapturedByPattern:@"^#define[ \t]+[^ \t]+_(format|width|height|ncolors|chars_per_pixel)[ \t]+([0-9]+)"])
			{
				NSString *name=[matches objectAtIndex:1];
				int value=[[matches objectAtIndex:2] intValue];

				if([name isEqual:@"width"]) width=value;
				else if([name isEqual:@"height"]) height=value;
				if([name isEqual:@"ncolors"]) numcolours=value;
				else if([name isEqual:@"chars_per_pixel"]) numchars=value;
			}
			else if(matches=[line substringsCapturedByPattern:@"^static[ \t]+char[ \t]+\\*[ \t]*[^ \t]+_colors[ \t]*\\[[ \t]*\\][ \t]*=[ \t]*{"])
			break;
		}

		if(!width||!height||!numcolours||!numchars) return;

		[self setFormat:@"XPM"];
		[self setDepthIndexed:numcolours];

		XeeImageLoaderHeaderDone();

		[self allocWithType:XeeBitmapTypeARGB8 width:width height:height];

		cols=[NSMutableDictionary dictionary];

		for(int i=0;i<numcolours;i++)
		{
			NSString *code=[self nextLine];
			NSString *colstr=[self nextLine];
			NSNumber *col=nil;

			NSArray *matches=[colstr substringsCapturedByPattern:@"#([0-9a-fA-F]+)"];
			if(matches) col=[self parseHexColour:[matches objectAtIndex:1]];
			else
			{
				NSString *name=[colstr lowercaseString];
				if([name isEqual:@"none"]) transparent=YES;
				col=[[XeeXPMImage colourDictionary] objectForKey:name];
			}

			if(col) [cols setObject:col forKey:code];
		}
	}

	for(int y=0;y<height;y++)
	{
		NSAutoreleasePool *pool=[NSAutoreleasePool new];

		uint32_t *dest=(uint32_t *)(data+y*bytesperrow);
		NSString *row=[self nextLine];

		int len=[row length]/numchars;
		if(len>width) len=width;

		for(int x=0;x<len;x++)
		dest[x]=[[cols objectForKey:[row substringWithRange:NSMakeRange(x*numchars,numchars)]] unsignedIntValue];

		[self setCompletedRowCount:y+1];
		[pool release];
	}

	XeeImageLoaderDone(YES);
}

-(NSString *)nextLine
{
	if(version==2) return [[self handle] readLineWithEncoding:NSASCIIStringEncoding];
	else return [self nextString];
}

-(NSString *)nextString
{
	CSHandle *fh=[self handle];

	char c,prev=0;
	for(;;)
	{
		c=[fh readUInt8];

		if(prev=='/'&&c=='*')
		{
			char c,prev=0;
			for(;;)
			{
				c=[fh readUInt8];
				if(prev=='*'&&c=='/') break;
				c=prev;
			}
		}
		else if(c=='"') break;

		c=prev;
	}

	NSMutableString *str=[NSMutableString string];

	for(;;)
	{
		char c=[fh readUInt8];

		if(c=='"') break;
		else if(c=='\\') { [fh readUInt8]; } // we just skip escapes
		else [str appendFormat:@"%c",c];
	}

	return str;
}

-(NSNumber *)parseHexColour:(NSString *)hex
{
	int chars=[hex length]/3;
	const char *cstr=[hex UTF8String];

	if(chars==1)
	{
		return [NSNumber numberWithUnsignedInt:XeeMakeNRGB8(
			ConvertHex(cstr[0])*0x11,
			ConvertHex(cstr[1])*0x11,
			ConvertHex(cstr[2])*0x11
		)];
	}
	else if(chars>1)
	{
		return [NSNumber numberWithUnsignedInt:XeeMakeNRGB8(
			(ConvertHex(cstr[0])<<4)|ConvertHex(cstr[1]),
			(ConvertHex(cstr[chars])<<4)|ConvertHex(cstr[chars+1]),
			(ConvertHex(cstr[2*chars])<<4)|ConvertHex(cstr[2*chars+1])
		)];
	}
	else return nil;
}

@end
