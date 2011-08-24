#import "XeeImageSaver.h"



@interface XeeCGImageSaver:XeeImageSaver
{
}

-(id)initWithImage:(XeeImage *)img;
-(BOOL)save:(NSString *)filename;

-(NSString *)type;
-(NSMutableDictionary *)properties;

+(BOOL)canSaveImage:(XeeImage *)img;
+(BOOL)canSaveImageWithBitDepth:(int)depth floating:(BOOL)floating;

@end

@interface XeeAlphaSaver:XeeCGImageSaver
{
	XeeSLSwitch *alpha;
}

-(id)initWithImage:(XeeImage *)img;
-(void)dealloc;

-(NSMutableDictionary *)properties;

@end



@interface XeePNGSaver:XeeAlphaSaver
{
	//XeeSLPopUp *depth;
	XeeSLSwitch *interlaced;
}

-(id)initWithImage:(XeeImage *)img;
-(void)dealloc;
-(NSString *)format;
-(NSString *)extension;
-(NSString *)type;
-(NSMutableDictionary *)properties;
+(BOOL)canSaveImageWithBitDepth:(int)depth floating:(BOOL)floating;

@end

@interface XeeJPEGSaver:XeeCGImageSaver
{
	XeeSLSlider *quality;
}

-(id)initWithImage:(XeeImage *)img;
-(void)dealloc;
-(NSString *)format;
-(NSString *)extension;
-(NSString *)type;
-(NSMutableDictionary *)properties;

@end

@interface XeeJP2Saver:XeeAlphaSaver
{
	XeeSLSlider *quality;
}

-(id)initWithImage:(XeeImage *)img;
-(void)dealloc;
-(NSString *)format;
-(NSString *)extension;
-(NSString *)type;
-(NSMutableDictionary *)properties;

@end

@interface XeeTIFFSaver:XeeAlphaSaver
{
	//XeeSLPopUp *depth;
	XeeSLPopUp *compression;
}

-(id)initWithImage:(XeeImage *)img;
-(void)dealloc;
-(NSString *)format;
-(NSString *)extension;
-(NSString *)type;
-(NSMutableDictionary *)properties;
+(BOOL)canSaveImageWithBitDepth:(int)depth floating:(BOOL)floating;

@end



@interface XeePhotoshopSaver:XeeAlphaSaver {}
-(NSString *)format;
-(NSString *)extension;
-(NSString *)type;
+(BOOL)canSaveImageWithBitDepth:(int)depth floating:(BOOL)floating;
@end

@interface XeeOpenEXRSaver:XeeCGImageSaver {}
-(NSString *)format;
-(NSString *)extension;
-(NSString *)type;
+(BOOL)canSaveImageWithBitDepth:(int)depth floating:(BOOL)floating;
@end



@interface XeeGIFSaver:XeeAlphaSaver {}
-(NSString *)format;
-(NSString *)extension;
-(NSString *)type;
@end

@interface XeePICTSaver:XeeAlphaSaver {}
-(NSString *)format;
-(NSString *)extension;
-(NSString *)type;
@end

@interface XeeBMPSaver:XeeCGImageSaver {}
-(NSString *)format;
-(NSString *)extension;
-(NSString *)type;
@end

@interface XeeTGASaver:XeeAlphaSaver {}
-(NSString *)format;
-(NSString *)extension;
-(NSString *)type;
@end

@interface XeeSGISaver:XeeAlphaSaver {}
-(NSString *)format;
-(NSString *)extension;
-(NSString *)type;
@end
