#import "XeeDuckyParser.h"
#import "XeeProperties.h"


@implementation XeeDuckyParser

-(id)initWithBuffer:(uint8_t *)duckydata length:(int)len
{
	if(self=[super init])
	{
		props=[[NSMutableArray array] retain];
//NSLog(@"%@",[NSData dataWithBytes:duckydata length:len]);

		int pos=0;
		while(pos<len)
		{
			if(pos+2>=len) break; // truncated
			int chunktype=XeeBEInt16(duckydata+pos); pos+=2;
			if(!chunktype) break; // end marker

			if(pos+2>=len) break; // truncated
			int chunklen=XeeBEInt16(duckydata+pos); pos+=2;

			int next=pos+chunklen;
			if(next>=len) break; // truncated

			switch(chunktype)
			{
				case 1: // quality
					if(len>=4)
					[props addObject:[XeePropertyItem itemWithLabel:
					NSLocalizedString(@"Save For Web JPEG quality",@"Save For Web JPEG quality property title")
					value:[NSString stringWithFormat:@"%d%%",XeeBEInt32(duckydata+pos)]]];
				break;
				case 2: // description
					if(len>=4)
					[props addObjectsFromArray:[XeePropertyItem itemsWithLabel:
					NSLocalizedString(@"Description",@"Description property title")
					textValue:[[[NSString alloc] initWithBytes:duckydata+pos+4 length:chunklen-4
					encoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingUTF16BE)] autorelease]]];
				break;
				case 3: // copyright
					if(len>=4)
					[props addObjectsFromArray:[XeePropertyItem itemsWithLabel:
					NSLocalizedString(@"Copyright",@"Copyright property title")
					textValue:[[[NSString alloc] initWithBytes:duckydata+pos+4 length:chunklen-4
					encoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingUTF16BE)] autorelease]]];
				break;
			}
			pos=next;
		}
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
	return [NSArray arrayWithObject:[XeePropertyItem itemWithLabel:
	NSLocalizedString(@"Photoshop properties",@"Photoshop properties section title")
	value:props identifier:@"photoshop"]];
}

@end
