#import "XeePDFBitmapLoader.h"
#import "CSRegex.h"


@implementation XeePDFBitmapImage

+(id)fileTypes
{
	return [NSArray arrayWithObjects:@"pdf",@"'PDF '",nil];
}

+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes
{
	uint8 *header=(uint8 *)[block bytes];
	if([block length]>5&&header[0]=='%'&&header[1]=='P'&&header[2]=='D'&&
	header[3]=='F'&&header[4]=='-') return YES;
	return 0;
}

-(SEL)initLoader
{
	CSFileHandle *fh=[self handle];

	objdict=[[NSMutableDictionary dictionary] retain];
	unresolved=[[NSMutableArray array] retain];

	[fh seekToEndOfFile];
	[fh skipBytes:-48];
	NSData *enddata=[fh readDataOfLength:48];
	NSString *end=[[[NSString alloc] initWithData:enddata encoding:NSISOLatin1StringEncoding] autorelease];

	NSString *startxref=[[end substringsCapturedByPattern:@"startxref[\n\r ]+([0-9]+)[\n\r ]+%%EOF"] objectAtIndex:1];
	if(!startxref) return NULL;
	[fh seekToFileOffset:[startxref intValue]];

	// Parse object list
	for(;;)
	{
		NSDictionary *trailer=[self parsePDFXref];

		[self resolveIndirectObjects];

		NSNumber *prev=[trailer objectForKey:@"Prev"];
		if(prev) [fh seekToFileOffset:[prev intValue]];
		else break;
	}

	NSMutableArray *imageobjs=[NSMutableArray array];
//NSLog(@"%@",[objdict allKeys]);
	// Find image objects in object list
	NSEnumerator *enumerator=[[objdict allKeys] objectEnumerator];
	NSNumber *objnum;
	while(objnum=[enumerator nextObject])
	{
		id object=[objdict objectForKey:objnum];
		if([object isKindOfClass:[XeePDFStream class]])
		{
			NSDictionary *dict=[object dictionary];
			NSString *type=[dict objectForKey:@"Type"];
			NSString *subtype=[dict objectForKey:@"Subtype"];

			if(type&&subtype&&[type isEqual:@"XObject"]&&[subtype isEqual:@"Image"])
			[imageobjs addObject:object];
		}
	}

//	NSLog(@"%@",imageobjs);

	return NULL;
}

-(void)deallocLoader
{
	[objdict release];
	[unresolved release];
}

-(NSDictionary *)parsePDFXref
{
	CSFileHandle *fh=[self handle];
	int c;

	if([fh readUInt8]!='x'||[fh readUInt8]!='r'||[fh readUInt8]!='e'||[fh readUInt8]!='f')
	[NSException raise:@"XeePDFParserException" format:@"Error parsing xref"];

	do { c=[fh readUInt8]; } while(isspace(c));
	[fh pushBackByte:c];

	for(;;)
	{
		c=[fh readUInt8];
		if(c=='t')
		{
			if([fh readUInt8]!='r'||[fh readUInt8]!='a'||[fh readUInt8]!='i'
			||[fh readUInt8]!='l'||[fh readUInt8]!='e'||[fh readUInt8]!='r')  [NSException raise:@"XeePDFParserException" format:@"Error parsing xref trailer"];

			id trailer=[self parsePDFType];
			if([trailer isKindOfClass:[NSDictionary class]]) return trailer;
			else [NSException raise:@"XeePDFParserException" format:@"Error parsing xref trailer"];
		}
		else if(c<'0'||c>'9') [NSException raise:@"XeePDFParserException" format:@"Error parsing xref table"];
		else [fh pushBackByte:c];

		int first=[self parseSimpleInteger];
		int num=[self parseSimpleInteger];

		do { c=[fh readUInt8]; } while(isspace(c));
		[fh pushBackByte:c];

		for(int i=0;i<num;i++)
		{
			char entry[21];
			[fh readBytes:20 toBuffer:entry];

			if(entry[17]=='n')
			{
				off_t objoffs=atoll(entry);
				off_t curroffs=[fh offsetInFile];
				[fh seekToFileOffset:objoffs];
				id obj=[self parsePDFObject];
				[fh seekToFileOffset:curroffs];
				if(obj) [objdict setObject:obj forKey:[NSNumber numberWithInt:first+i]];
			}
		}
	}
	return nil;
}

-(id)parsePDFObject
{
	CSFileHandle *fh=[self handle];
	int c;

	/*int objnum=*/[self parseSimpleInteger];
	/*int objgen=*/[self parseSimpleInteger];

	do { c=[fh readUInt8]; } while(isspace(c));

	if(c!='o'||[fh readUInt8]!='b'||[fh readUInt8]!='j')
	[NSException raise:@"XeePDFParserException" format:@"Error parsing object"];

	id value=[self parsePDFType];

	do { c=[fh readUInt8]; } while(isspace(c));

	switch(c)
	{
		case 's':
			if([fh readUInt8]!='t'||[fh readUInt8]!='r'||[fh readUInt8]!='e'
			||[fh readUInt8]!='a'||[fh readUInt8]!='m') [NSException raise:@"XeePDFParserException" format:@"Error parsing stream object"];

			c=[fh readUInt8];
			if(c=='\r') c=[fh readUInt8];
			if(c!='\n') [NSException raise:@"XeePDFParserException" format:@"Error parsing stream object"];

			return [[[XeePDFStream alloc] initWithDictionary:value fileHandle:fh offset:[fh offsetInFile]] autorelease];
		break;

		case 'e':
			if([fh readUInt8]!='n'||[fh readUInt8]!='d'||[fh readUInt8]!='o'
			||[fh readUInt8]!='b'||[fh readUInt8]!='j') [NSException raise:@"XeePDFParserException" format:@"Error parsing object"];
			return value;
		break;

		default: [NSException raise:@"XeePDFParserException" format:@"Error parsing obj"];
	}
	return nil; // shut up, gcc
}

-(int)parseSimpleInteger
{
	CSFileHandle *fh=[self handle];
	int c,val=0;

	do { c=[fh readUInt8]; } while(isspace(c));

	for(;;)
	{
		if(!isdigit(c))
		{
			[fh pushBackByte:c];
			return val;
		}
		val=val*10+(c-'0');
		c=[fh readUInt8];
	}
 }



-(id)parsePDFType
{
	CSFileHandle *fh=[self handle];
	int c;
	do { c=[fh readUInt8]; } while(isspace(c));

	switch(c)
	{
		case 'n': return [self parsePDFNull];

		case 't': case 'f': return [self parsePDFBoolStartingWith:c];

		case '0': case '1': case '2': case '3': case '4': case '5':
		case '6': case '7': case '8': case '9': case '-': case '.':
			return [self parsePDFNumberStartingWith:c];

		case '/': return [self parsePDFWord];

		case '(': return [self parsePDFString];

		case '[': return [self parsePDFArray];

		case '<':
			c=[fh readUInt8];
			switch(c)
			{
				case '0': case '1': case '2': case '3': case '4':
				case '5': case '6': case '7': case '8': case '9':
				case 'a': case 'b': case 'c': case 'd': case 'e': case 'f':
				case 'A': case 'B': case 'C': case 'D': case 'E': case 'F':
					return [self parsePDFHexStringStartingWith:c];

				case '<': return [self parsePDFDictionary];
				default: return nil;
			}

		default: [fh pushBackByte:c]; return nil;
	}
}

-(NSNull *)parsePDFNull
{
	CSFileHandle *fh=[self handle];

	char rest[3];
	[fh readBytes:3 toBuffer:rest];
	if(rest[0]=='u'&&rest[1]=='l'&&rest[2]=='l') return [NSNull null];
	else [NSException raise:@"XeePDFParserException" format:@"Error parsing null value"];
	return nil; // shut up, gcc
}

-(NSNumber *)parsePDFBoolStartingWith:(int)c
{
	CSFileHandle *fh=[self handle];

	if(c=='t')
	{
		char rest[3];
		[fh readBytes:3 toBuffer:rest];
		if(rest[0]=='r'&&rest[1]=='u'&&rest[2]=='e') return [NSNumber numberWithBool:YES];
		else [NSException raise:@"XeePDFParserException" format:@"Error parsing boolean true value"];
	}
	else
	{
		char rest[4];
		[fh readBytes:4 toBuffer:rest];
		if(rest[0]=='a'&&rest[1]=='l'&&rest[2]=='s'&&rest[3]=='e') return [NSNumber numberWithBool:NO];
		else [NSException raise:@"XeePDFParserException" format:@"Error parsing boolean false value"];
	}
	return nil; // shut up, gcc
}

-(NSNumber *)parsePDFNumberStartingWith:(int)c
{
	CSFileHandle *fh=[self handle];
	char str[32]={c};
	int i;

	for(i=1;i<sizeof(str);i++)
	{
		int c=[fh readUInt8];
		if(!isdigit(c)&&c!='.')
		{
			[fh pushBackByte:c];
			break;
		}
		str[i]=c;
	}

	if(i==sizeof(str)) [NSException raise:@"XeePDFParserException" format:@"Error parsing numeric value"];
	str[i]=0;

	if(strchr(str,'.')) return [NSNumber numberWithDouble:atof(str)];
	else return [NSNumber numberWithLongLong:atoll(str)];
 }

-(NSString *)parsePDFWord
{
	NSMutableString *str=[NSMutableString string];
	CSFileHandle *fh=[self handle];

	for(;;)
	{
		int c=[fh readUInt8];
		if(c<0x21||c>0x7e||c=='%'||c=='('||c==')'||c=='<'||c=='>'||c=='['||c==']'
		||c=='{'||c=='}'||c=='/'||c=='#')
		{
			[fh pushBackByte:c];
			return str;
		}
		[str appendFormat:@"%c",c];
	}
}

-(NSString *)parsePDFString
{
	NSMutableString *str=[NSMutableString string];
	CSFileHandle *fh=[self handle];

	for(;;)
	{
		// note: doesn't handle various escapes
		int c=[fh readUInt8];
		switch(c)
		{
			default: [str appendFormat:@"%c",c]; break;
			case ')': return str;
			case '\\':
				c=[fh readUInt8];
				switch(c)
				{
					default: [str appendFormat:@"%c",c]; break;
					case '\n': case '\r': break; // ignore newlines, possibly broken.
					case 'n': [str appendFormat:@"\n",c]; break;
					case 'r': [str appendFormat:@"\r",c]; break;
					case 't': [str appendFormat:@"\t",c]; break;
					case 'b': [str appendFormat:@"\b",c]; break;
					case 'f': [str appendFormat:@"\f",c]; break;
					case '0': case '1': case '2': case '3': // octal encoding, doesn't check for validity
					case '4': case '5': case '6': case '7':
					{
						char c2=[fh readUInt8];
						char c3=[fh readUInt8];
						[str appendFormat:@"%c",(c-'0')*64+(c2-'0')*8+(c3-'0')];
					}
					break;
				}
			break;
		}
	}
}

-(NSData *)parsePDFHexStringStartingWith:(int)c
{
	NSMutableData *data=[NSMutableData data];
	CSFileHandle *fh=[self handle];

	[fh pushBackByte:c];

	for(;;)
	{
		int c1=[fh readUInt8];
		if(c1=='>') return data;
		if(!isxdigit(c1)) [NSException raise:@"XeePDFParserException" format:@"Error parsing hex data value"];

		int c2=[fh readUInt8];
		if(!isxdigit(c1)&&c1!='>') [NSException raise:@"XeePDFParserException" format:@"Error parsing hex data value"];

		uint8 byte;

		if(c1>='0'&&c1<='9') byte=(c1-'0')*16; 
		else if(c1>='a'&&c1<='f') byte=(c1-'a'+10)*16; 
		else if(c1>='A'&&c1<='F') byte=(c1-'A'+10)*16; 

		if(c2>='0'&&c2<='9') byte+=(c1-'0'); 
		else if(c2>='a'&&c2<='f') byte+=(c2-'a'+10); 
		else if(c2>='A'&&c2<='F') byte+=(c2-'A'+10); 

		[data appendBytes:&byte length:1];

		if(c2=='>') return data;
	}
}

-(NSArray *)parsePDFArray
{
	NSMutableArray *array=[NSMutableArray array];
	CSFileHandle *fh=[self handle];

	for(;;)
	{
		id value=[self parsePDFType];
		if(!value)
		{
			int c=[fh readUInt8];
			if(c==']')
			{
				[unresolved addObject:array];
				return array;
			}
			else if(c=='R')
			{
				id num=[array objectAtIndex:[array count]-2];
				if([num isKindOfClass:[NSNumber class]])
				{
					XeePDFIndirectObject *obj=[[[XeePDFIndirectObject alloc] initWithNumber:num] autorelease];
					[array removeLastObject];
					[array removeLastObject];
					[array addObject:obj];
				}
				else [NSException raise:@"XeePDFParserException" format:@"Error parsing indirect object in array"];
			}
			else [NSException raise:@"XeePDFParserException" format:@"Error parsing array"];
		}
		else [array addObject:value];
	}
}

-(NSDictionary *)parsePDFDictionary
{
	NSMutableDictionary *dict=[NSMutableDictionary dictionary];
	CSFileHandle *fh=[self handle];
	id prev_key=nil,prev_value=nil;

	for(;;)
	{
		id key=[self parsePDFType];

		if(!key)
		{
			if([fh readUInt8]=='>'&&[fh readUInt8]=='>')
			{
				[unresolved addObject:dict];
				return dict;
			}
			else [NSException raise:@"XeePDFParserException" format:@"Error parsing dictionary"];
		}
		else if([key isKindOfClass:[NSString class]])
		{
			id value=[self parsePDFType];
			if(!value) [NSException raise:@"XeePDFParserException" format:@"Error parsing dictionary value"];
			[dict setObject:value forKey:key];
			prev_key=key;
			prev_value=value;
		}
		else if([key isKindOfClass:[NSNumber class]])
		{
			int c;
			do { c=[fh readUInt8]; } while(isspace(c));
			if(c=='R')
			{
				[dict setObject:[[[XeePDFIndirectObject alloc] initWithNumber:prev_value] autorelease] forKey:prev_key];
				prev_key=nil;
				prev_value=nil;
			}
			else [NSException raise:@"XeePDFParserException" format:@"Error parsing indirect object in dictionary"];
		}
		else [NSException raise:@"XeePDFParserException" format:@"Error parsing dictionary key"];
	}
}

-(void)resolveIndirectObjects
{
	NSEnumerator *enumerator=[unresolved objectEnumerator];
	id obj;
	while(obj=[enumerator nextObject])
	{
		if([obj isKindOfClass:[NSDictionary class]])
		{
			NSMutableDictionary *dict=obj;
			NSEnumerator *keyenum=[dict keyEnumerator];
			NSString *key;
			while(key=[keyenum nextObject])
			{
				id value=[dict objectForKey:key];
				if([value isKindOfClass:[XeePDFIndirectObject class]])
				{
					id realobj=[objdict objectForKey:[value number]];
					if(realobj) [dict setObject:realobj forKey:key];
				}
			}
		}
		else if([obj isKindOfClass:[NSArray class]])
		{
			NSMutableArray *array=obj;
			int count=[array count];
			for(int i=0;i<count;i++)
			{
				id value=[array objectAtIndex:i];
				if([value isKindOfClass:[XeePDFIndirectObject class]])
				{
					id realobj=[objdict objectForKey:[value number]];
					if(realobj) [array replaceObjectAtIndex:i withObject:realobj];
				}
			}
		}
	}
}

@end



@implementation XeePDFStream

-(id)initWithDictionary:(NSDictionary *)dictionary fileHandle:(CSFileHandle *)filehandle offset:(off_t)fileoffs;
{
	if(self=[super init])
	{
		dict=[dictionary retain];
		fh=[filehandle retain];
		offs=fileoffs;
	}
	return self;
}

-(void)dealloc
{
	[dict release];
	[fh release];
	[super dealloc];
}

-(NSDictionary *)dictionary { return dict; }

-(NSString *)description { return [NSString stringWithFormat:@"<Stream with dictionary: %@>",dict]; }

-(void)dumpToFile
{
	[fh seekToFileOffset:offs];
	NSData *data=[fh readDataOfLength:[[dict objectForKey:@"Length"] intValue]];
	[data writeToFile:
	[NSHomeDirectory() stringByAppendingPathComponent:
	[NSString stringWithFormat:@"Desktop/%x.jpg",self]]
	atomically:NO];

NSLog(@"%d %@",[data length],[NSString stringWithFormat:@"Desktop/%x.jpg",self]);
}

@end



@implementation XeePDFIndirectObject

-(id)initWithNumber:(NSNumber *)objnum
{
	if(self=[super init])
	{
		num=[objnum retain];
	}
	return self;
}

-(void)dealloc
{
	[num release];
	[super dealloc];
}

-(NSNumber *)number { return num; }

-(NSString *)description { return [NSString stringWithFormat:@"<Indirect reference to object %@>",num]; }

@end



