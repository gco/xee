#import <Cocoa/Cocoa.h>
#import "XeeTypes.h"

@interface XeeDuckyParser:NSObject
{
	NSMutableArray *props;
}

-(id)initWithBuffer:(uint8_t *)duckydata length:(int)len;
-(void)dealloc;

-(NSArray *)propertyArray;

@end
