#import "XeeIPTCParser.h"
#import "XeeProperties.h"
#import "XeeTypes.h"

#define XeeIPTCBinary 1
#define XeeIPTCString 2
#define XeeIPTCInt16 3

static NSString *XeeLookupIPTCTag(int record,int dataset,int *type);



@implementation XeeIPTCParser

-(id)initWithHandle:(CSHandle *)handle
{
	if(self=[super init])
	{
		NSMutableDictionary *prevdict=[NSMutableDictionary dictionary];
		props=[[NSMutableArray array] retain];

		@try
		{
			while(![handle atEndOfFile])
			{
				int marker=[handle readUInt8];
				if(marker!=0x1c) @throw @"Not a valid tag marker";
				int record=[handle readUInt8];
				int dataset=[handle readUInt8];
				int size=[handle readUInt16BE];
				int next=[handle offsetInFile]+size;

				if(size&0x8000) @throw @"Extended tags not supported";

				int type;
				NSString *label=XeeLookupIPTCTag(record,dataset,&type);

				if(label)
				{
					id value=@"";
					switch(type)
					{
						case XeeIPTCString:
							value=[[[NSString alloc] initWithData:[handle readDataOfLength:size]
							encoding:NSUTF8StringEncoding] autorelease];
						break;

						case XeeIPTCBinary:
							value=XeeHexDump([[handle readDataOfLength:size] bytes],size,32);
						break;

						case XeeIPTCInt16:
							value=[NSNumber numberWithInt:[handle readUInt16BE]];
						break;
					}

					NSNumber *preventry=[prevdict objectForKey:label];
					if(preventry)
					{
						int index=[preventry intValue];
						XeePropertyItem *prev=[props objectAtIndex:index];
						XeePropertyItem *heading=[prev heading];
						if(!heading) heading=prev;
						[props insertObject:
						[XeePropertyItem itemWithLabel:@"" value:value heading:heading position:[prev position]+1]
						atIndex:index+1];
						[prevdict setObject:[NSNumber numberWithInt:index+1] forKey:label];
					}
					else
					{
						[props addObject:[XeePropertyItem itemWithLabel:label value:value]];
						[prevdict setObject:[NSNumber numberWithInt:[props count]-1] forKey:label];
					}
				}

/*					case 0x040b: // Copyright URL
						[props addObject:[XeePropertyItem itemWithLabel:
						NSLocalizedString(@"Copyright URL",@"Copyright URL property title")
						value:[NSURL URLWithString:[[[NSString alloc] initWithData:[handle readDataOfLength:chunklen] encoding:NSISOLatin1StringEncoding] autorelease]]]];
					break;
				}*/

				[handle seekToFileOffset:next];
			}
		}
		@catch(id e) { NSLog(@"Error parsing IPTC metadata: %@",e); }
		
	}
	return self;
}

-(void)dealloc
{
	[props release];
	[super dealloc];
}

-(NSArray *)propertyArray
{
	if(![props count]) return nil;
	return [NSArray arrayWithObject:[XeePropertyItem itemWithLabel:
	NSLocalizedString(@"IPTC properties",@"IPTC properties section title")
	value:props identifier:@"iptc"]];
}

@end



static NSString *XeeLookupIPTCTag(int record,int dataset,int *type)
{
	switch(record)
	{
		case 1:
			switch(dataset)
			{
				//case 0: *type=XeeIPTCInt16; return @"Model version";
				case 5: *type=XeeIPTCString; return @"Destination";
				case 20: *type=XeeIPTCInt16; return @"File format";
				case 22: *type=XeeIPTCInt16; return @"File format version";
				case 30: *type=XeeIPTCString; return @"Service identifier";
				case 40: *type=XeeIPTCString; return @"Envelope number";
				case 50: *type=XeeIPTCString; return @"Product I.D.";
				case 60: *type=XeeIPTCString; return @"Envelope priority";
				case 70: *type=XeeIPTCString; return @"Date sent";
				case 80: *type=XeeIPTCString; return @"Time sent";
				//case 90: *type=XeeIPTCBinary; return @"Coded character set";
				case 100: *type=XeeIPTCString; return @"Unique name of object";
				case 120: *type=XeeIPTCInt16; return @"ARM identifier";
				case 122: *type=XeeIPTCInt16; return @"ARM version";
			}
		break;
		case 2:
			switch(dataset)
			{
				//case 0: *type=XeeIPTCInt16; return @"Record 2 version";
				case 3: *type=XeeIPTCString; return @"Object type reference"; // ?
				case 4: *type=XeeIPTCString; return @"Object attribute reference";
				case 5: *type=XeeIPTCString; return @"Object name";
				case 7: *type=XeeIPTCString; return @"Edit status";
				case 8: *type=XeeIPTCString; return @"Editorial update";
				case 10: *type=XeeIPTCString; return @"Urgency";
				case 12: *type=XeeIPTCString; return @"Subject reference";
				case 15: *type=XeeIPTCString; return @"Category";
				case 20: *type=XeeIPTCString; return @"Supplemental category";
				case 22: *type=XeeIPTCString; return @"Fixture identifier";
				case 25: *type=XeeIPTCString; return @"Keywords";
				case 26: *type=XeeIPTCString; return @"Content location code";
				case 27: *type=XeeIPTCString; return @"Content location name";
				case 30: *type=XeeIPTCString; return @"Release date";
				case 35: *type=XeeIPTCString; return @"Release time";
				case 37: *type=XeeIPTCString; return @"Expiration date";
				case 38: *type=XeeIPTCString; return @"Expiration time";
				case 40: *type=XeeIPTCString; return @"Special instructions";
				case 42: *type=XeeIPTCString; return @"Action advised";
				case 45: *type=XeeIPTCString; return @"Reference service";
				case 47: *type=XeeIPTCString; return @"Reference date";
				case 50: *type=XeeIPTCString; return @"Reference number";
				case 55: *type=XeeIPTCString; return @"Date created";
				case 60: *type=XeeIPTCString; return @"Time created";
				case 62: *type=XeeIPTCString; return @"Digital creation date";
				case 63: *type=XeeIPTCString; return @"Digital creation time";
				case 65: *type=XeeIPTCString; return @"Originating program";
				case 70: *type=XeeIPTCString; return @"Program version";
				case 75: *type=XeeIPTCString; return @"Object cycle";
				case 80: *type=XeeIPTCString; return @"Byline";
				case 85: *type=XeeIPTCString; return @"Byline title";
				case 90: *type=XeeIPTCString; return @"City";
				case 92: *type=XeeIPTCString; return @"Sub-location";
				case 95: *type=XeeIPTCString; return @"Province/State";
				case 100: *type=XeeIPTCString; return @"Country / Primary location code";
				case 101: *type=XeeIPTCString; return @"Country / Primary location name";
				case 103: *type=XeeIPTCString; return @"Original transmission reference";
				case 105: *type=XeeIPTCString; return @"Headline";
				case 110: *type=XeeIPTCString; return @"Credit";
				case 115: *type=XeeIPTCString; return @"Source";
				case 116: *type=XeeIPTCString; return @"Copyright notice";
				case 118: *type=XeeIPTCString; return @"Contact";
				case 120: *type=XeeIPTCString; return @"Caption / Abstract";
				case 122: *type=XeeIPTCString; return @"Writer / Editor";
				case 125: *type=XeeIPTCBinary; return @"Rasterized caption";
				case 130: *type=XeeIPTCString; return @"Image type";
				case 131: *type=XeeIPTCString; return @"Image orientation";
				case 135: *type=XeeIPTCString; return @"Language identifier";
				case 150: *type=XeeIPTCString; return @"Audio type";
				case 151: *type=XeeIPTCString; return @"Audio sampling ate";
				case 152: *type=XeeIPTCString; return @"Audio sampling resolution";
				case 153: *type=XeeIPTCString; return @"Audio duration";
				case 154: *type=XeeIPTCString; return @"Audio outcue";
				//case 200: *type=XeeIPTCString; return @"Objectdata preview file format";
				//case 201: *type=XeeIPTCString; return @"Objectdata preview file format version";
				//case 202: *type=XeeIPTCBinary; return @"Objectdata preview data";
			}
		break;
	}
	return nil;
}
