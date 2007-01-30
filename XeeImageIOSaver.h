#import "XeeImageSaver.h"

@interface XeeCGImageSaver:XeeImageSaver
{
}

+(BOOL)canSaveImage:(XeeImage *)img;
+(BOOL)canSaveImageWithBitDepth:(int)depth floating:(BOOL)floating;
-(BOOL)save:(NSString *)filename;
-(NSString *)type;
-(NSMutableDictionary *)properties;

@end

@interface XeeAlphaSaver:XeeCGImageSaver
{
	XeeSLSwitch *alpha;
}

-(id)initWithImage:(XeeImage *)img;
-(NSMutableDictionary *)properties;

@end



@interface XeePNGSaver:XeeAlphaSaver
{
    XeeSLSwitch *interlaced;
}

+(BOOL)canSaveImageWithBitDepth:(int)depth floating:(BOOL)floating;
-(id)initWithImage:(XeeImage *)img;
-(NSString *)format;
-(NSString *)extension;
-(NSString *)type;
-(NSMutableDictionary *)properties;

@end

@interface XeeJPEGSaver:XeeCGImageSaver
{
    XeeSLSlider *quality;
}

-(id)initWithImage:(XeeImage *)img;
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
-(NSString *)format;
-(NSString *)extension;
-(NSString *)type;
-(NSMutableDictionary *)properties;

@end

@interface XeeTIFFSaver:XeeAlphaSaver
{
	XeeSLPopUp *compression;
}

+(BOOL)canSaveImageWithBitDepth:(int)depth floating:(BOOL)floating;
-(id)initWithImage:(XeeImage *)img;
-(NSString *)format;
-(NSString *)extension;
-(NSString *)type;
-(NSMutableDictionary *)properties;
@end



@interface XeePhotoshopSaver:XeeAlphaSaver {}
+(BOOL)canSaveImageWithBitDepth:(int)depth floating:(BOOL)floating;
-(NSString *)format;
-(NSString *)extension;
-(NSString *)type;
@end

@interface XeeOpenEXRSaver:XeeCGImageSaver {}
+(BOOL)canSaveImageWithBitDepth:(int)depth floating:(BOOL)floating;
-(NSString *)format;
-(NSString *)extension;
-(NSString *)type;
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
-(NSMutableDictionary *)properties;
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
