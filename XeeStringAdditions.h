#import <Cocoa/Cocoa.h>

@interface NSString (XeeStringAdditions)

-(NSString *)stringByMappingColonToSlash;
-(NSString *)stringByMappingSlashToColon;

@end

NSString *XeeDescribeDate(NSDate *date);
NSString *XeeDescribeSize(uint64_t size);
