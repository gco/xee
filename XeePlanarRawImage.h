#import "XeeBitmapImage.h"

@interface XeePlanarRawImage:XeeBitmapImage
{
	NSArray *handles;

	uint8 *buffer;
	int type,bitdepth;
	BOOL big,precomp;

	int row;
}

-(id)initWithHandles:(NSArray *)handlearray type:(int)bitmaptype width:(int)framewidth height:(int)frameheight depth:(int)framedepth bigEndian:(BOOL)bigendian preComposed:(BOOL)precomposed;
-(void)dealloc;

-(SEL)initLoader;
-(SEL)load;

@end
