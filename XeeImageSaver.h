#import <Cocoa/Cocoa.h>

#import "XeeImage.h"
#import "XeeSimpleLayout.h"



@interface XeeImageSaver:NSObject
{
	XeeImage *image;
	XeeSLControl *control;
}

-(id)initWithImage:(XeeImage *)img;
-(void)dealloc;

-(NSString *)format;
-(NSString *)extension;

-(BOOL)save:(NSString *)filename;

-(XeeSLControl *)control;
-(void)setControl:(XeeSLControl *)cont;

+(BOOL)canSaveImage:(XeeImage *)img;

+(void)initialize;
+(NSArray *)saversForImage:(XeeImage *)image;
+(void)registerSaverClass:(Class)class;

@end
