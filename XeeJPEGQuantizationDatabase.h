#import <Cocoa/Cocoa.h>

#include "libjpeg/jpeglib.h"

@interface XeeJPEGQuantizationDatabase:NSObject
{
	NSMutableDictionary *dict;
}

+(XeeJPEGQuantizationDatabase *)defaultDatabase;

-(id)initWithFile:(NSString *)filename;
-(void)dealloc;

-(NSArray *)producersForTables:(struct jpeg_decompress_struct *)cinfo;
-(NSArray *)producersForTableString:(NSString *)tables;

-(NSArray *)propertyArrayForTables:(struct jpeg_decompress_struct *)cinfo;

@end
