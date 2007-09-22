#import "XeeMultiImage.h"
#import "SWFParser.h"
#import "CSMemoryHandle.h"

@interface XeeSWFImage:XeeMultiImage
{
	SWFParser *parser;
	CSMemoryHandle *jpegtables;
}

+(NSArray *)fileTypes;
+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;

-(void)load;
-(void)addAndLoadSubImage:(XeeImage *)image;

@end
