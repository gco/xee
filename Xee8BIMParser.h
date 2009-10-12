#import <Cocoa/Cocoa.h>

#import "XeeTypes.h"
#import <XADMaster/CSHandle.h>

@interface Xee8BIMParser:NSObject
{
	NSMutableArray *props;
	NSArray *xmpprops,*iptcprops,*exifprops;

	int numcolours,trans;
	BOOL hasmerged,copyrighted,watermarked,untagged;
}

-(id)initWithHandle:(CSHandle *)handle;
-(void)dealloc;

-(BOOL)hasMergedImage;
-(int)numberOfIndexedColours;
-(int)indexOfTransparentColour;

-(NSArray *)propertyArrayWithPhotoshopFirst:(BOOL)psfirst;
@end
