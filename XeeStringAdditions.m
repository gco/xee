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

NSString *XeeDescribeDate(NSDate *date)
{
	return [date descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M" timeZone:nil locale:nil];
}

NSString *XeeDescribeSize(uint64_t size)
{
	if(size<10000) return [NSString stringWithFormat:
		NSLocalizedString(@"%qd B",@"A file size in bytes"),size];
	else if(size<102400) return [NSString stringWithFormat:
		NSLocalizedString(@"%.2f kB",@"A file size in kilobytes with two decimals"),((float)size/1024.0)];
	else if(size<1024000) return [NSString stringWithFormat:
		NSLocalizedString(@"%.1f kB",@"A file size in kilobytes with one decimal"),((float)size/1024.0)];
	else return [NSString stringWithFormat:
		NSLocalizedString(@"%qd kB",@"A file size in kilobytes with no decimals"),size/1024];
}

