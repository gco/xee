#import <Cocoa/Cocoa.h>
#import "XeeFileHandle.h"
#import "XeeTypes.h"


#define XeeCanLosslesslySaveFlag 0x01
#define XeeNeedsTrimmingFlag 0x02
#define XeeCroppingInexactFlag 0x04

#define XeeTrimFlag 0x01


@interface XeeImage:NSObject
{
	NSString *filename;
	NSData *header;
	NSDictionary *attrs;
	XeeFileHandle *filehandle;

	BOOL stop,thumbnailonly,success;
	SEL nextselector;
	NSLock *lock;

	NSString *format;
	int width,height;
	NSString *depth;
	NSImage *depthicon;
	BOOL transparent;
	NSColor *back;
	XeeTransformation orientation,correctorientation;
	int crop_x,crop_y,crop_width,crop_height;

	NSMutableArray *properties;

	id delegate;
}

-(id)init;
-(id)initWithFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;
-(void)_initImage;
-(void)dealloc;

-(SEL)identifyFile;
-(void)deallocLoader;

-(void)runLoader;
-(void)runLoaderForThumbnail;
-(void)stopLoading;
-(BOOL)hasBeenStopped;
-(XeeFileHandle *)fileHandle;

-(BOOL)completed;
-(BOOL)failed;

-(int)frames;
-(void)setFrame:(int)frame;
-(int)frame;

-(void)setDelegate:(id)del;
-(void)triggerLoadingAction;
-(void)triggerChangeAction;
-(void)triggerSizeChangeAction;
-(void)triggerPropertyChangeAction;

-(BOOL)animated;
-(void)setAnimating:(BOOL)animating;
-(void)setAnimatingDefault;
-(BOOL)animating;

-(NSRect)updatedAreaInRect:(NSRect)rect;

-(void)drawInRect:(NSRect)rect bounds:(NSRect)bounds;
-(void)drawInRect:(NSRect)rect bounds:(NSRect)bounds lowQuality:(BOOL)lowquality;

-(CGImageRef)makeCGImage;

-(int)losslessFlags;
-(BOOL)losslessSaveTo:(NSString *)destination flags:(int)flags;

-(NSString *)filename;
-(NSString *)format;
-(int)width;
-(int)height;
-(int)fullWidth;
-(int)fullHeight;
-(NSString *)depth;
-(NSImage *)depthIcon;
-(BOOL)transparent;
-(NSColor *)backgroundColor;
-(NSArray *)properties;

-(XeeTransformation)orientation;
-(XeeTransformation)correctOrientation;
-(NSRect)croppingRect;
-(NSRect)rawCroppingRect;
-(XeeTransformationMatrix)transformationMatrix;
-(BOOL)isTransformed;
-(BOOL)isRotated;
-(BOOL)isCropped;

-(unsigned long long)fileSize;
-(NSString *)descriptiveFilename;
-(NSString *)descriptiveFileSize;
-(NSString *)descriptiveDate;

-(void)setFilename:(NSString *)name;
-(void)setFormat:(NSString *)fmt;
-(void)setBackgroundColor:(NSColor *)col;

-(void)setOrientation:(XeeTransformation)trans;
-(void)setCorrectOrientation:(XeeTransformation)trans;
-(void)setCroppingRect:(NSRect)rect;
-(void)resetTransformations;

-(void)setDepth:(NSString *)d;
-(void)setDepthIcon:(NSImage *)icon;
-(void)setDepthIconName:(NSString *)iconname;
-(void)setDepth:(NSString *)d iconName:(NSString *)iconname;
-(void)setDepthBitmap;
-(void)setDepthIndexed:(int)colors;
-(void)setDepthGrey:(int)bits;
-(void)setDepthGrey:(int)bits alpha:(BOOL)alpha floating:(BOOL)floating;
-(void)setDepthRGB:(int)bits;
-(void)setDepthRGBA:(int)bits;
-(void)setDepthRGB:(int)bits alpha:(BOOL)alpha floating:(BOOL)floating;
-(void)setDepthCMYK:(int)bits alpha:(BOOL)alpha;
-(void)setDepthLab:(int)bits alpha:(BOOL)alpha;

-(id)description;

+(void)initialize;
+(XeeImage *)imageForFilename:(NSString *)filename;
+(void)registerImageClass:(Class)class;
+(NSArray *)fileTypes;
+(NSString *)describeFileSize:(int)size;

@end


@interface NSObject (XeeImageDelegate)

-(void)xeeImageLoadingProgress:(XeeImage *)image;
-(void)xeeImageDidChange:(XeeImage *)image;
-(void)xeeImageSizeDidChange:(XeeImage *)image;
-(void)xeeImagePropertiesDidChange:(XeeImage *)image;

@end


