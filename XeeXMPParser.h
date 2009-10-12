#import <Cocoa/Cocoa.h>
#import <XADMaster/CSHandle.h>

//#import <xml.h>

@interface XeeXMPParser:NSObject
{
	NSMutableArray *props;
	NSDictionary *prefixdict,*localnamedict;
}

-(id)initWithHandle:(CSHandle *)handle;
-(void)dealloc;

-(NSString *)parsePropertyName:(NSXMLNode *)node;
-(NSArray *)parsePropertyValue:(NSXMLNode *)node;
-(NSString *)parseSingleValue:(NSXMLNode *)node;

-(NSString *)reflowName:(NSString *)name capitalize:(BOOL)capitalize exceptions:(NSDictionary *)exceptions;

-(NSArray *)propertyArray;

@end
