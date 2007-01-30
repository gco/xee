#import "XeeMultiImage.h"

@interface XeePDFBitmapImage:XeeMultiImage
{
	NSMutableDictionary *objdict;
	NSMutableArray *unresolved;
}

+(id)fileTypes;
+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;

-(SEL)initLoader;
-(void)deallocLoader;

-(NSDictionary *)parsePDFXref;
-(int)parseSimpleInteger;

-(id)parsePDFObject;

-(id)parsePDFType;
-(NSNull *)parsePDFNull;
-(NSNumber *)parsePDFBoolStartingWith:(int)c;
-(NSNumber *)parsePDFNumberStartingWith:(int)c;
-(NSString *)parsePDFWord;
-(NSString *)parsePDFString;
-(NSData *)parsePDFHexStringStartingWith:(int)c;
-(NSArray *)parsePDFArray;
-(NSDictionary *)parsePDFDictionary;

-(void)resolveIndirectObjects;

@end



@interface XeePDFStream:NSObject
{
	NSDictionary *dict;
	XeeFileHandle *fh;
	off_t offs;
}

-(id)initWithDictionary:(NSDictionary *)dictionary fileHandle:(XeeFileHandle *)filehandle offset:(off_t)fileoffs;
-(void)dealloc;
-(NSDictionary *)dictionary;
-(NSString *)description;

-(void)dumpToFile;

@end



@interface XeePDFIndirectObject:NSObject
{
	NSNumber * num;
}

-(id)initWithNumber:(NSNumber *)objnum;
-(void)dealloc;
-(NSNumber *)number;
-(NSString *)description;

@end
