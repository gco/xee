#import "XeeMultiImage.h"

#import <Carbon/Carbon.h>

/*struct IIOLoaderInfo
{
	FILE *fh;
	BOOL *stop;
};*/

@interface XeeImageIOImage:XeeMultiImage
{
	CGImageSourceRef source;

	int nextindex;
//	struct IIOLoaderInfo loaderinfo;
}

-(SEL)identifyFile;
-(void)deallocLoader;
-(SEL)startLoading;
-(SEL)loadNextImage;
-(SEL)loadThumbnail;

-(void)setDepthForImage:(XeeImage *)image properties:(NSDictionary *)properties;
-(NSString *)formatForType:(NSString *)type;

+(NSArray *)fileTypes;

@end
