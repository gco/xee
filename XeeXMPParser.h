#import <Cocoa/Cocoa.h>
#import "CSHandle.h"

//#import <xml.h>

@interface XeeXMPParser:NSObject
{
}

-(id)initWithHandle:(CSHandle *)handle;
-(void)dealloc;

-(NSArray *)propertyArray;

@end
