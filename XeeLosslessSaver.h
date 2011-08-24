#import "XeeImageSaver.h"



@interface XeeLosslessSaver:XeeImageSaver
{
	XeeSLSwitch *trim;
}

-(id)initWithImage:(XeeImage *)img;
-(NSString *)format;
-(NSString *)extension;
-(BOOL)save:(NSString *)filename;

+(BOOL)canSaveImage:(XeeImage *)img;

@end
