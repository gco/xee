#import <Cocoa/Cocoa.h>
#import "CSHandle.h"

@interface XeeIPTCParser:NSObject
{
	NSMutableArray *props;
}

-(id)initWithHandle:(CSHandle *)handle;
-(void)dealloc;

-(NSArray *)propertyArray;

@end
