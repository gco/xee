#import "XeeImage.h"

@class XeeView;

@interface XeeNSImage:XeeMultiImage
{

}

-(id)initWithFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;
-(id)initWithPasteboard:(NSPasteboard *)pboard;
-(void)dealloc;

+(BOOL)canInitFromPasteboard:(NSPasteboard *)pboard;

+(NSArray *)convertRepresentations:(NSArray *)representations;
+(NSArray *)fileTypes;

@end
