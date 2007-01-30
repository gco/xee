#import <Cocoa/Cocoa.h>

#import "XeeImage.h"
#import "XeeSimpleLayout.h"

@interface XeeImageSaver:NSObject
{
	XeeImage *image;
	XeeSLControl *control;
}

+(BOOL)canSaveImage:(XeeImage *)img;
+(NSArray *)saversForImage:(XeeImage *)img;
+(void)registerSaverClass:(Class)saverclass;

-(id)initWithImage:(XeeImage *)img;
-(void)dealloc;
-(NSString *)format;
-(NSString *)extension;
-(BOOL)save:(NSString *)filename;
-(XeeSLControl *)control;
-(void)setControl:(XeeSLControl *)newcontrol;

@end
