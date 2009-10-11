#import <Cocoa/Cocoa.h>

#import "XeeTypes.h"
#import "exiftags/exif.h"



// Tags and tag sets

typedef int16_t XeeEXIFTag;

#define XeeOrientationTag 0x0112
#define XeeThumbnailOffsetTag 0x0201
#define XeeThumbnailLengthTag 0x0202
#define XeeFocalPlaneXResolution 0xa20e
#define XeeFocalPlaneYResolution 0xa20f

typedef enum
{
	XeeStandardTagSet
} XeeEXIFTagSet;



// Rationals

typedef struct { int num,denom; } XeeRational;

static inline XeeRational XeeMakeRational(int num,int denom) { XeeRational res={num,denom}; return res; }
static inline int XeeRationalNumerator(XeeRational r) { return r.num; }
static inline int XeeRationalDenominator(XeeRational r) { return r.denom; }

#define XeeZeroRational XeeMakeRational(0,1);



// Reader class

@interface XeeEXIFParser:NSObject
{
	struct exiftags *exiftags;
	uint8_t *data;
	NSData *dataobj;
}

-(id)initWithBuffer:(const uint8_t *)exifdata length:(int)len;
-(id)initWithBuffer:(uint8_t *)exifdata length:(int)len mutable:(BOOL)mutable;
-(id)initWithData:(NSData *)data;
-(void)dealloc;

-(NSString *)stringForTag:(XeeEXIFTag)tag set:(XeeEXIFTagSet)set;
-(int)integerForTag:(XeeEXIFTag)tag set:(XeeEXIFTagSet)set;
-(XeeRational)rationalForTag:(XeeEXIFTag)tag set:(XeeEXIFTagSet)set;
-(BOOL)setShort:(int)val forTag:(XeeEXIFTag)tag set:(XeeEXIFTagSet)set;
-(BOOL)setLong:(int)val forTag:(XeeEXIFTag)tag set:(XeeEXIFTagSet)set;
-(BOOL)setRational:(XeeRational)val forTag:(XeeEXIFTag)tag set:(XeeEXIFTagSet)set;
-(struct exifprop *)exifPropForTag:(XeeEXIFTag)tag set:(XeeEXIFTagSet)set;

-(NSArray *)propertyArray;

@end
