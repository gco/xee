#import "XeeImageSaver.h"

@interface XeeExperimentalImage1Saver:XeeImageSaver
{
}

+(BOOL)canSaveImage:(XeeImage *)img;
-(id)initWithImage:(XeeImage *)img;
-(NSString *)format;
-(NSString *)extension;
-(BOOL)save:(NSString *)filename;

@end
