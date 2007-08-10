#import "XeeStringAdditions.h"

@implementation NSString (XeeStringAdditions)

-(NSString *)stringByMappingColonToSlash
{
	NSMutableString *str=[NSMutableString stringWithString:self];
	[str replaceOccurrencesOfString:@":" withString:@"/" options:0 range:NSMakeRange(0,[self length])];
	return [NSString stringWithString:str];
}

-(NSString *)stringByMappingSlashToColon
{
	NSMutableString *str=[NSMutableString stringWithString:self];
	[str replaceOccurrencesOfString:@"/" withString:@":" options:0 range:NSMakeRange(0,[self length])];
	return [NSString stringWithString:str];
}

@end
