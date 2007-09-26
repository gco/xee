#import "XeeImage.h"



@interface XeeMultiImage:XeeImage
{
	NSMutableArray *subimages;
	int currindex;
	XeeImage *currloading;
}

-(id)init;
-(void)dealloc;

-(void)addSubImage:(XeeImage *)subimage;
-(void)addSubImages:(NSArray *)array;

-(void)xeeImageLoadingProgress:(XeeImage *)image;
-(void)xeeImageDidChange:(XeeImage *)image;
-(void)xeeImageSizeDidChange:(XeeImage *)image;
-(void)xeeImagePropertiesDidChange:(XeeImage *)image;

-(XeeImage *)currentSubImage;

/*-(BOOL)loaded;
-(BOOL)failed;
-(BOOL)needsLoading;*/
-(void)stopLoading;

-(void)runLoaderOnSubImage:(XeeImage *)image;

-(int)frames;
-(void)setFrame:(int)frame;
-(int)frame;

-(NSRect)updatedAreaInRect:(NSRect)rect;
-(void)drawInRect:(NSRect)rect bounds:(NSRect)bounds lowQuality:(BOOL)lowquality;

-(CGImageRef)createCGImage;
-(int)losslessSaveFlags;
-(NSString *)losslessFormat;
-(NSString *)losslessExtension;
-(BOOL)losslessSaveTo:(NSString *)path flags:(int)flags;

-(int)width;
-(int)height;
-(int)fullWidth;
-(int)fullHeight;
-(NSString *)depth;
-(NSImage *)depthIcon;
-(BOOL)transparent;
-(NSColor *)backgroundColor;
-(NSRect)croppingRect;
-(XeeTransformation)orientation;
-(XeeTransformation)correctOrientation;

-(NSArray *)properties;

-(void)setOrientation:(XeeTransformation)trans;
-(void)setCorrectOrientation:(XeeTransformation)trans;
-(void)setCroppingRect:(NSRect)rect;
-(void)resetTransformations;

@end
