#import <Foundation/Foundation.h>

#import "CSHandle.h"
#import "CSFilterHandle.h"
#import "NSDictionaryNumberExtension.h"

@class PDFParser,PDFObjectReference;

@interface PDFStream:NSObject
{
	NSDictionary *dict;
	CSHandle *fh;
	off_t offs;
	PDFObjectReference *ref;
	PDFParser *parser;
}

-(id)initWithDictionary:(NSDictionary *)dictionary fileHandle:(CSHandle *)filehandle
reference:(PDFObjectReference *)reference parser:(PDFParser *)owner;
-(void)dealloc;

-(NSDictionary *)dictionary;
-(PDFObjectReference *)reference;

-(BOOL)isImage;
-(BOOL)isJPEG;
-(BOOL)isJPEG2000;
-(BOOL)isMask;
-(BOOL)isBitmap;
-(BOOL)isIndexed;
-(BOOL)isGrey;
-(BOOL)isRGB;
-(BOOL)isCMYK;
-(BOOL)isLab;
-(NSString *)finalFilter;
-(int)bitsPerComponent;

-(NSString *)colourSpaceOrAlternate;
-(NSString *)subColourSpaceOrAlternate;
-(NSString *)_parseColourSpace:(id)colourspace;
-(int)numberOfColours;
-(NSData *)paletteData;
-(NSArray *)decodeArray;

-(CSHandle *)rawHandle;
-(CSHandle *)handle;
-(CSHandle *)JPEGHandle;
-(CSHandle *)handleExcludingLast:(BOOL)excludelast;
-(CSHandle *)handleForFilterName:(NSString *)filtername decodeParms:(NSDictionary *)decodeparms parentHandle:(CSHandle *)parent;
-(CSHandle *)predictorHandleForDecodeParms:(NSDictionary *)decodeparms parentHandle:(CSHandle *)parent;

-(NSString *)description;

@end

@interface PDFASCII85Handle:CSFilterHandle
{
	uint32_t val;
	BOOL finalbytes;
}

-(void)resetFilter;
-(uint8_t)produceByte;

@end

@interface PDFHexHandle:CSFilterHandle
{
}

-(uint8_t)produceByte;

@end

@interface PDFLZWHandle:CSHandle
{
}

@end

@interface PDFCCITTHandle:CSHandle
{
}

@end



@interface PDFTIFFPredictorHandle:CSFilterHandle
{
	int cols,comps,bpc;
	int prev[4];
}

-(id)initWithHandle:(CSHandle *)handle columns:(int)columns
components:(int)components bitsPerComponent:(int)bitspercomp;
-(uint8_t)produceByte;

@end

@interface PDFPNGPredictorHandle:CSFilterHandle
{
	int cols,comps,bpc;
	uint8_t *prevbuf;
	int type;
}

-(id)initWithHandle:(CSHandle *)handle columns:(int)columns
components:(int)components bitsPerComponent:(int)bitspercomp;
-(void)resetFilter;
-(uint8_t)produceByte;

@end
