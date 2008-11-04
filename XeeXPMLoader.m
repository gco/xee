#import "XeeXPMLoader.h"
#import "CSRegex.h"


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

	if(version!=1)
	{
		NSArray *props=[[self nextLine] substringsCapturedByPattern:@"^([0-9]+)[ \t]+([0-9]+)[ \t]+([0-9]+)[ \t]+([0-9]+)"];
		if(!props) return;
NSLog(@"%@",props);

		width=[[props objectAtIndex:1] intValue];
		height=[[props objectAtIndex:2] intValue];
		int numcolours=[[props objectAtIndex:3] intValue];
		int numchars=[[props objectAtIndex:4] intValue];

		NSMutableDictionary *cols=[NSMutableDictionary dictionary];
		CSRegex *regex=[CSRegex regexWithPattern:[NSString stringWithFormat:@"^(.{%d}[ \t]+",numchars]];

		for(int i=0;i<numcolours;i++)
		{
			NSString *line=[self nextLine];
			NSArray *matches=[regex capturedSubstringsOfString:line];
			//[cols setObject:[NSNumber numberWithUnsignedInt:col] for
		}
	}
	else
	{
	}

	XeeImageLoaderHeaderDone();

	[self allocWithType:XeeBitmapTypeARGB8 width:width height:height];

//	for(;;)
//	{
//		NSString *line=[fh readLineWithEncoding:NSASCIIStringEncoding];
//	}

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

@end
