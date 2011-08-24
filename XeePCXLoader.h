#import "XeeBitmapImage.h"

struct pcx_header;

@interface XeePCXImage:XeeBitmapImage
{
	int current_line;
	byte palette[3*256];
}

-(SEL)identifyFile;
-(SEL)startLoading;
-(SEL)load;

+(NSArray *)fileTypes;

@end
