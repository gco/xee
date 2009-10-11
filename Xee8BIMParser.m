#import "Xee8BIMParser.h"
#import "XeeProperties.h"

#import "XeeXMPParser.h"
#import "XeeIPTCParser.h"
#import "XeeExifParser.h"



@implementation Xee8BIMParser

-(id)initWithHandle:(CSHandle *)handle
{
	if(self=[super init])
	{
		props=[[NSMutableArray array] retain];
		xmpprops=iptcprops=exifprops=nil;

		numcolours=0;
		trans=-1;
		hasmerged=YES;
		copyrighted=watermarked=untagged=NO;

		@try
		{
			while(![handle atEndOfFile])
			{
				uint32_t type=[handle readID];
				if(type!='8BIM') break;
				int chunkid=[handle readUInt16BE];
				int namelen=[handle readInt8];
				//NSData *name=[handle readDataOfLength:namelen];
				//if((namelen&1)==0) [handle readInt8];
				[handle skipBytes:namelen+1-(namelen&1)];
				int chunklen=[handle readUInt32BE];
				int next=[handle offsetInFile]+((chunklen+1)&~1);

				switch(chunkid)
				{
					case 0x03f0: // Caption (?)
					{
						int len=[handle readUInt8];
						[props addObject:[XeePropertyItem itemWithLabel:
						NSLocalizedString(@"Caption",@"Caption property title")
						value:[[[NSString alloc] initWithData:[handle readDataOfLength:len] encoding:NSWindowsCP1252StringEncoding] autorelease]]];
					}
					break;

					case 0x03f2: // Background color
					break;

					case 0x0404: // IPTC
					{
//NSLog(@"%@",[handle readDataOfLength:chunklen]);
						XeeIPTCParser *parser=[[XeeIPTCParser alloc] initWithHandle:[handle subHandleOfLength:chunklen]];
						iptcprops=[[parser propertyArray] retain];
						[parser release];
					}
					break;

					case 0x0406: // JPEG quality
					{
						int quality=[handle readInt16BE]+4;
						int type=[handle readUInt16BE];
						int scans=[handle readUInt16BE]+2;

						NSString *qualitystr;
						switch(quality)
						{
							case 0: case 1: case 2: case 3: case 4: qualitystr=NSLocalizedString(@" (Low)",@"Low JPEG quality property value"); break;
							case 5: case 6: case 7: qualitystr=NSLocalizedString(@" (Medium)",@"Medium JPEG quality property value"); break;
							case 8: case 9: qualitystr=NSLocalizedString(@" (High)",@"High JPEG quality property value"); break;
							case 10: case 11: case 12: qualitystr=NSLocalizedString(@" (Maximum)",@"Maximum JPEG quality property value"); break;
							default:  qualitystr=NSLocalizedString(@" (Unknown)",@"Unknown JPEG quality property value"); break;
						}
						[props addObject:[XeePropertyItem itemWithLabel:
						NSLocalizedString(@"JPEG quality",@"JPEG Quality property title")
						value:[NSString stringWithFormat:@"%d%@",quality,qualitystr]]];

						NSString *typestr;
						switch(type)
						{
							case 0: typestr=NSLocalizedString(@"Standard",@"Standard JPEG type property value"); break;
							case 1: typestr=NSLocalizedString(@"Optimized",@"Optimized JPEG type property value"); break;
							case 2: case 257: typestr=NSLocalizedString(@"Progressive",@"Progressive JPEG type property value"); break;
							default: typestr=NSLocalizedString(@"Unknown",@"Unknown JPEG type property value"); break;
						}
						[props addObject:[XeePropertyItem itemWithLabel:
						NSLocalizedString(@"JPEG type",@"JPEG type property title")
						value:typestr]];

						if(type==2||type==257)
						[props addObject:[XeePropertyItem itemWithLabel:
						NSLocalizedString(@"JPEG progressive scans",@"JPEG progressive scans property title")
						value:[NSNumber numberWithInt:scans]]];
					}
					break;

					case 0x0409: // Old thumbnail
					case 0x040c: // New thumbnail
					break;

					case 0x040a: // Copyrighted
						copyrighted=[handle readUInt8];
						[props addObject:[XeePropertyItem itemWithLabel:
						NSLocalizedString(@"Copyrighted",@"Copyrighted property title")
						value:copyrighted?NSLocalizedString(@"Yes",@"Yes property title"):NSLocalizedString(@"No",@"No property title")]];
					break;

					case 0x040b: // Copyright URL
						[props addObject:[XeePropertyItem itemWithLabel:
						NSLocalizedString(@"Copyright URL",@"Copyright URL property title")
						value:[NSURL URLWithString:[[[NSString alloc] initWithData:[handle readDataOfLength:chunklen] encoding:NSISOLatin1StringEncoding] autorelease]]]];
					break;

					case 0x040f: // ICC profile
					break;

					case 0x0410: // Watermarked
						watermarked=[handle readUInt8];
						[props addObject:[XeePropertyItem itemWithLabel:
						NSLocalizedString(@"Watermarked",@"Watermarked property title")
						value:watermarked?NSLocalizedString(@"Yes",@"Yes property title"):NSLocalizedString(@"No",@"No property title")]];
					break;

					case 0x0411: // ICC untagged
						untagged=[handle readUInt8];
						[props addObject:[XeePropertyItem itemWithLabel:
						NSLocalizedString(@"ICC profile disabled",@"ICC profile disabled image property title")
						value:untagged?NSLocalizedString(@"Yes",@"Yes property title"):NSLocalizedString(@"No",@"No property title")]];
					break;

					case 0x0416: // Indexed color table count
						numcolours=[handle readUInt16BE];
					break;

					case 0x0417: // Transparent index
						trans=[handle readUInt16BE];
					break;

					case 0x041b: // Workflow URL
					{
						int len=[handle readUInt32BE];
						[props addObject:[XeePropertyItem itemWithLabel:
						NSLocalizedString(@"Workflow URL",@"Workflow URL property title")
						value:[NSURL URLWithString:[[[NSString alloc] initWithData:[handle readDataOfLength:len*2]
						encoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingUTF16BE)] autorelease]]]];
					}
					break;

					case 0x0415: // URL List
					break;

					case 0x0421: // Version info
					{
						/*version=*/[handle readUInt32BE];
						hasmerged=[handle readUInt8];

						int writerlen=[handle readUInt32BE];
						NSString *writer=[[[NSString alloc] initWithData:[handle readDataOfLength:writerlen*2]
						encoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingUTF16BE)] autorelease];

						int readerlen=[handle readUInt32BE];
						NSString *reader=[[[NSString alloc] initWithData:[handle readDataOfLength:readerlen*2]
						encoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingUTF16BE)] autorelease];

						/*fileversion=*/[handle readUInt32BE];

						/*[props addObject:[XeePropertyItem itemWithLabel:
						NSLocalizedString(@"Version",@"Version property title")
						value:[NSNumber numberWithInt:version]]];

						[props addObject:[XeePropertyItem itemWithLabel:
						NSLocalizedString(@"File version",@"File version property title")
						value:[NSNumber numberWithInt:fileversion]]];*/

						[props addObject:[XeePropertyItem itemWithLabel:
						NSLocalizedString(@"Contains merged image",@"Contains merged image property title")
						value:hasmerged?NSLocalizedString(@"Yes",@"Yes property title"):NSLocalizedString(@"No",@"No property title")]];

						[props addObject:[XeePropertyItem itemWithLabel:
						NSLocalizedString(@"Writer",@"Writer property title")
						value:writer]];

						[props addObject:[XeePropertyItem itemWithLabel:
						NSLocalizedString(@"Reader",@"Reader property title")
						value:reader]];
					}
					break;

					case 0x0422: // Exif
					{
						XeeEXIFParser *parser=[[XeeEXIFParser alloc] initWithData:[handle readDataOfLength:chunklen]];
						exifprops=[[parser propertyArray] retain];
						[parser release];
					}
					break;

					case 0x0424: // XMP
					{
						XeeXMPParser *parser=[[XeeXMPParser alloc] initWithHandle:[handle subHandleOfLength:chunklen]];
						xmpprops=[[parser propertyArray] retain];
						[parser release];
					}
					break;

					default:
					/*	[props addObject:[XeePropertyItem itemWithLabel:
						[NSString stringWithFormat:@"%x",chunkid]
						value:[handle readDataOfLength:chunklen]]];
//						value:[[[NSString alloc] initWithData:[handle readDataOfLength:chunklen] encoding:NSISOLatin1StringEncoding] autorelease]]];
					*/break;
				}

				[handle seekToFileOffset:next];
			}
		}
		@catch(id e) { NSLog(@"Error parsing Photoshop metadata: %@ %@",e,props); }
	}
	return self;
}

-(void)dealloc
{
	[props release];
	[xmpprops release];
	[iptcprops release];
	[exifprops release];

	[super dealloc];
}

-(BOOL)hasMergedImage { return hasmerged; }

-(int)numberOfIndexedColours { return numcolours; }

-(int)indexOfTransparentColour { return trans; }

-(NSArray *)propertyArrayWithPhotoshopFirst:(BOOL)psfirst
{
	NSMutableArray *array=[NSMutableArray array];
	XeePropertyItem *psitem=[XeePropertyItem itemWithLabel:
	NSLocalizedString(@"Photoshop properties",@"Photoshop properties section title")
	value:props identifier:@"photoshop"];

	if(psfirst) [array addObject:psitem];

	if(exifprops) [array addObjectsFromArray:exifprops];
	if(xmpprops) [array addObjectsFromArray:xmpprops];
	if(iptcprops) [array addObjectsFromArray:iptcprops];

	if(!psfirst) [array addObject:psitem];

	return array;
}

@end
