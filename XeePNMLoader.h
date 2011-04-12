#import "XeeMultiImage.h"

@interface XeePNMImage:XeeMultiImage
{
}

+(NSArray *)fileTypes;
+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;

-(void)load;

-(int)nextIntegerAfterWhiteSpace;
-(int)nextCharacterSkippingComments;

@end
