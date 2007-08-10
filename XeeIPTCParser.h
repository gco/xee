#import <Cocoa/Cocoa.h>
#import "CSHandle.h"

@interface XeeIPTCParser:NSObject
{
}

-(id)initWithHandle:(CSHandle *)handle;
-(void)dealloc;

-(NSArray *)propertyArray;

@end
