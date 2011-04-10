#import "XeeXMPParser.h"
#import "XeeProperties.h"

#import <XADMaster/XADRegex.h>
#import <wctype.h>

@implementation XeeXMPParser

-(id)initWithHandle:(CSHandle *)handle
{
	if(self=[super init])
	{
		props=[[NSMutableArray array] retain];
		prefixdict=[[NSDictionary dictionaryWithObjectsAndKeys:
			@"",@"dc",
			@"",@"xap",
			@"EXIF",@"exif",
			@"TIFF",@"tiff",
			@"IPTC",@"Iptc4xmpCore",
			@"Copyright",@"xapRights",
		nil] retain];
		localnamedict=[[NSDictionary dictionaryWithObjectsAndKeys:
			@"ICC profile",@"ICCProfile",
			@"Creation date",@"CreateDate",
			@"Modification date",@"ModifyDate",
			@"author's position",@"AuthorsPosition",
			@"HDR luminance",@"HDRLuminance",
		nil] retain];

		Class xmldocument=NSClassFromString(@"NSXMLDocument");

		@try
		{
			if(xmldocument)
			{
				NSXMLDocument *doc=[[[xmldocument alloc] initWithData:[handle remainingFileContents] options:0 error:NULL] autorelease];

				if(doc)
				{
					[[doc rootElement] addNamespace:[NSXMLNode namespaceWithName:@"rdf" stringValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#"]];
					NSError *err;
					NSArray *tags=[[doc rootElement] nodesForXPath:@"//rdf:RDF/rdf:Description/*" error:&err];
					if(err) @throw err;

					NSEnumerator *enumerator=[tags objectEnumerator];
					NSXMLNode *node;
					while(node=[enumerator nextObject])
					{
						NSString *name=[self parsePropertyName:node];
						if(name)
						{
							NSArray *values=[self parsePropertyValue:node];
							NSArray *items=[XeePropertyItem itemsWithLabel:name valueArray:values];
							[props addObjectsFromArray:items];
						}
					}
				}

				return self;
			}
		}
		@catch(id e) { NSLog(@"Error parsing XMP metadata: %@",e); }

		[self release];
	}
	return nil;
}

-(void)dealloc
{
	[props release];
	[prefixdict release];
	[localnamedict release];
	[super dealloc];
}

-(NSString *)parsePropertyName:(NSXMLNode *)node
{
	NSString *localname=[node localName];

	if([localname isEqual:@"NativeDigest"]) return nil; // discard meaningless NativeDigest garbage

	NSString *prefix=[node prefix];
	if(prefix)
	{
		if([prefix isEqual:@"xapMM"]) return nil; // discard horribly boring xapMM junk

		NSString *prefixname=[self reflowName:prefix capitalize:YES exceptions:prefixdict];

		if(prefixname) return [NSString stringWithFormat:@"%@ %@",prefixname,
		[self reflowName:localname capitalize:NO exceptions:localnamedict]];
	}
	return [self reflowName:localname capitalize:YES exceptions:localnamedict];
}

-(NSString *)reflowName:(NSString *)name capitalize:(BOOL)capitalize exceptions:(NSDictionary *)exceptions
{
	if(!name) return nil;

	NSString *exception=[exceptions objectForKey:name];
	if(exception)
	{
		if([exception length]) return exception;
		else return nil;
	}

	int len=[name length];
	NSMutableString *newname=[NSMutableString stringWithCapacity:len];

	for(int i=0;i<len;i++)
	{
		unichar c=[name characterAtIndex:i];
		if(iswupper(c)) if(i!=0) [newname appendString:@" "];

		if(i==0&&capitalize) [newname appendFormat:@"%C",towupper(c)];
		else [newname appendFormat:@"%C",towlower(c)];
	}

	return newname;
}

-(NSArray *)parsePropertyValue:(NSXMLNode *)node
{
	NSArray *children=[node children];
	int count=[children count];

	if(count==0) return [NSArray arrayWithObject:@""];
	else if(count==1)
	{
		NSXMLNode *child=[children objectAtIndex:0];
		NSString *name=[child name];

		if([name isEqual:@"rdf:Alt"]||[[child name] isEqual:@"rdf:Seq"]||[[child name] isEqual:@"rdf:Bag"])
		{
			NSString *path;
			if([[child name] isEqual:@"rdf:Alt"]) path=@"rdf:li[1]";
			else path=@"rdf:li";

			NSError *err;
			NSArray *lis=[child nodesForXPath:path error:&err];
			if(err) @throw err;

			if([lis count]==0) return [NSArray arrayWithObject:[child XMLString]];

			NSMutableArray *array=[NSMutableArray array];
			NSEnumerator *enumerator=[lis objectEnumerator];
			NSXMLNode *li;
			while(li=[enumerator nextObject])
			{
				NSArray *children=[li children];
				if([children count]==1) [array addObject:[self parseSingleValue:[children objectAtIndex:0]]];
				else if([children count]>1) [array addObject:[self parseSingleValue:li]];
			}

			return array;
		}
		else return [NSArray arrayWithObject:[self parseSingleValue:child]];
	}
	else
	{
		return [NSArray arrayWithObject:[children componentsJoinedByString:@""]];
	}
}

-(NSString *)parseSingleValue:(NSXMLNode *)node
{
	if([node kind]==NSXMLTextKind)
	{
		NSString *text=[node stringValue];
		NSArray *matches=[text substringsCapturedByPattern:@"^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2})(:([0-9]{2})(.([0-9]+))?)?(([+-])([0-9]{2}):([0-9]{2})|Z)$"];
		if(matches)
		{
			int year=[[matches objectAtIndex:1] intValue];
			int month=[[matches objectAtIndex:2] length]?[[matches objectAtIndex:2] intValue]:1;
			int day=[[matches objectAtIndex:3] length]?[[matches objectAtIndex:3] intValue]:1;
			int hour=[[matches objectAtIndex:4] length]?[[matches objectAtIndex:4] intValue]:0;
			int minute=[[matches objectAtIndex:5] length]?[[matches objectAtIndex:5] intValue]:0;
			int second=[[matches objectAtIndex:7] length]?[[matches objectAtIndex:7] intValue]:0;

			int timeoffs=0;
			if([[matches objectAtIndex:11] length])
			{
				timeoffs=[[matches objectAtIndex:12] intValue]*60+[[matches objectAtIndex:13] intValue];
				if([[matches objectAtIndex:11] isEqual:@"-"]) timeoffs=-timeoffs;
			}
			NSTimeZone *tz=[NSTimeZone timeZoneForSecondsFromGMT:timeoffs*60];

			return [NSCalendarDate dateWithYear:year month:month day:day hour:hour minute:minute second:second timeZone:tz];
		}

		return text;
	}
	else return [node XMLString];
}

-(NSArray *)propertyArray
{
	if(![props count]) return nil;
	return [NSArray arrayWithObject:[XeePropertyItem itemWithLabel:
	NSLocalizedString(@"XMP properties",@"XMP properties section title")
	value:props identifier:@"xmp"]];
}

@end
