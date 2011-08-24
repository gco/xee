#import <Cocoa/Cocoa.h>
#import "XeeTypes.h"

#import "exiftags/exif.h"



#define EXIFOrientationKey @"Orientation"
#define EXIFJPEGInterchangeFormatKey @"JPEGInterchangeFormat"
#define EXIFJPEGInterchangeFormatLengthKey @"JPEGInterchangeFormatLength"

#define EXIFOrientationTag 0x0112
#define EXIFXResolutionTag 0x011a
#define EXIFYResolutionTag 0x011b
#define EXIFFocalPlaneXResolutionTag 0xa20e
#define EXIFFocalPlaneYResolutionTag 0xa20f
#define EXIFJPEGInterchangeFormatTag 0x0201
#define EXIFJPEGInterchangeFormatLengthTag 0x0202

typedef uint16_t EXIFTag;
typedef enum { EXIFStandardTagSet } EXIFTagSet;
typedef struct { int numerator,denominator; } EXIFRational;

static EXIFRational inline EXIFMakeRational(int num,int denom) { EXIFRational res={num,denom}; return res; }
#define EXIFInvalidRational EXIFMakeRational(0,0)


@interface XeeEXIFReader:NSObject
{
	struct exiftags *exiftags;
	uint8 *data;
}

-(id)initWithBuffer:(void *)buffer length:(int)length;
-(id)initWithBuffer:(void *)buffer length:(int)length mutable:(BOOL)mutable;
-(id)initWithData:(NSData *)exifdata;
//-(id)initWithMutableData:(NSMutableData *)exifdata
-(void)dealloc;

-(NSString *)stringForKey:(NSString *)key;
-(NSString *)stringForTag:(EXIFTag)tag set:(EXIFTagSet)set;
-(NSString *)stringForExifProp:(struct exifprop *)prop;

-(int)integerForKey:(NSString *)key;
-(int)integerForTag:(EXIFTag)tag set:(EXIFTagSet)set;
-(int)integerForExifProp:(struct exifprop *)prop;

-(EXIFRational)rationalForKey:(NSString *)key;
-(EXIFRational)rationalForTag:(EXIFTag)tag set:(EXIFTagSet)set;
-(EXIFRational)rationalForExifProp:(struct exifprop *)prop;

-(BOOL)setShort:(int)value forKey:(NSString *)key;
-(BOOL)setShort:(int)value forTag:(EXIFTag)tag set:(EXIFTagSet)set;
-(BOOL)setShort:(int)value forExifProp:(struct exifprop *)prop;

-(BOOL)setLong:(int)value forKey:(NSString *)key;
-(BOOL)setLong:(int)value forTag:(EXIFTag)tag set:(EXIFTagSet)set;
-(BOOL)setLong:(int)value forExifProp:(struct exifprop *)prop;

-(BOOL)setRational:(EXIFRational)value forKey:(NSString *)key;
-(BOOL)setRational:(EXIFRational)value forTag:(EXIFTag)tag set:(EXIFTagSet)set;
-(BOOL)setRational:(EXIFRational)value forExifProp:(struct exifprop *)prop;

-(struct exifprop *)exifPropForKey:(NSString *)key;
-(struct exifprop *)exifPropForTag:(EXIFTag)tag set:(EXIFTagSet)set;

-(NSArray *)propertyArray;

@end
