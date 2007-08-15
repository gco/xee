#import <Cocoa/Cocoa.h>

#import "XeeTypes.h"
#import "CSHandle.h"
#import "XeeIPTCParser.h"

@interface Xee8BIMParser:NSObject
{
	NSMutableArray *props;

	int version,fileversion;
	BOOL hasmerged,copyrighted,watermarked,untagged;
	XeeIPTCParser *iptc;
}

-(id)initWithHandle:(CSHandle *)handle;
-(void)dealloc;

-(XeeIPTCParser *)IPTCParser;

-(NSArray *)propertyArray;

@end
