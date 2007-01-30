#import "XeeImageSaver.h"

@interface XeeLosslessSaver:XeeImageSaver
{
	XeeSLPopUp *untransformable,*cropping;
}

+(BOOL)canSaveImage:(XeeImage *)img;
-(id)initWithImage:(XeeImage *)img;
-(NSString *)format;
-(NSString *)extension;
-(BOOL)save:(NSString *)filename;

@end
