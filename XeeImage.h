#import <Cocoa/Cocoa.h>

#import "XeeTypes.h"
#import "CSFileHandle.h"
#import "CSCoroutine.h"
#import "XeeFSRef.h"
#import "XeeProperties.h"


#define XeeCanSaveLosslesslyFlag 1
#define XeeNotActuallyLosslessFlag 2
#define XeeCroppingIsInexactFlag 4
#define XeeHasUntransformableBlocksFlag 8
#define XeeUntransformableBlocksCanBeRetainedFlag 16
	
#define XeeTrimCroppingFlag 1
#define XeeRetainUntransformableBlocksFlag 2

//#define Xee

@class XeeMultiImage;

@interface XeeImage:NSObject
{
	XeeFSRef *ref;
	NSDictionary *attrs;
	CSHandle *handle;

	SEL nextselector;
	BOOL loaded;
	BOOL thumbonly,stop;

	CSCoroutine *coro;

	NSString *format;
	int width,height;
	NSString *depth;
	NSImage *icon,*depthicon;
	BOOL transparent;
	NSColor *back;
	XeeTransformation orientation,correctorientation;
	int crop_x,crop_y,crop_width,crop_height;
	NSMutableArray *properties;

	id delegate;
}

-(id)init;
-(id)initWithParentImage:(XeeMultiImage *)parent;
-(void)dealloc;

-(SEL)initLoader;
-(void)deallocLoader;

-(BOOL)startLoaderForHandle:(CSHandle *)fh ref:(XeeFSRef *)fsref attributes:(NSDictionary *)attributes;
-(void)runLoader;
-(void)runLoaderForThumbnail;
-(void)endLoader;

-(BOOL)startLoaderForRef2:(XeeFSRef *)fsref attributes:(NSDictionary *)attributes;
-(void)runLoader2;
-(void)load2;

-(BOOL)loaded;
-(BOOL)failed;
-(BOOL)needsLoading;
-(void)stopLoading;
-(BOOL)hasBeenStopped;
-(CSHandle *)handle;
-(CSFileHandle *)fileHandle;

-(int)frames;
-(void)setFrame:(int)frame;
-(int)frame;

-(void)setDelegate:(id)delegate;
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

-(CGImageRef)createCGImage;

-(int)losslessSaveFlags;
-(BOOL)losslessSaveTo:(NSString *)path flags:(int)flags;

-(XeeFSRef *)ref;
-(NSString *)filename;
-(NSString *)format;
-(NSImage *)icon;
-(int)width;
-(int)height;
-(int)fullWidth;
-(int)fullHeight;
-(NSString *)depth;
-(NSImage *)depthIcon;
-(BOOL)transparent;
-(NSColor *)backgroundColor;

-(int)orientation;
-(int)correctOrientation;
-(NSRect)croppingRect;
-(NSRect)rawCroppingRect;
-(BOOL)isTransformed;
-(BOOL)isCropped;
-(XeeMatrix)transformationMatrix;
-(XeeMatrix)transformationMatrixInRect:(NSRect)rect;

-(NSArray *)properties;
-(NSArray *)fullProperties;

-(int)fileSize;
-(NSString *)descriptiveFileSize;
-(NSString *)descriptiveDate;

//-(void)setFilename:(NSString *)name;
-(void)setFormat:(NSString *)fmt;
-(void)setBackgroundColor:(NSColor *)col;
-(void)setProperties:(NSArray *)newproperties;

-(void)setOrientation:(XeeTransformation)transformation;
-(void)setCorrectOrientation:(XeeTransformation)transformation;
-(void)setCroppingRect:(NSRect)rect;
-(void)resetTransformations;

-(void)setDepth:(NSString *)d;
-(void)setDepthIcon:(NSImage *)icon;
-(void)setDepthIconName:(NSString *)iconname;
-(void)setDepth:(NSString *)d iconName:(NSString *)iconname;

-(void)setDepthBitmap;
-(void)setDepthIndexed:(int)colors;
-(void)setDepthGrey:(int)bits alpha:(BOOL)alpha floating:(BOOL)floating;
-(void)setDepthRGB:(int)bits alpha:(BOOL)alpha floating:(BOOL)floating;
-(void)setDepthCMYK:(int)bits alpha:(BOOL)alpha;
-(void)setDepthLab:(int)bits alpha:(BOOL)alpha;
-(void)setDepthGrey:(int)bits;
-(void)setDepthRGB:(int)bits;
-(void)setDepthRGBA:(int)bits;

-(id)description;

+(XeeImage *)imageForFilename:(NSString *)filename;
+(XeeImage *)imageForRef:(XeeFSRef *)ref;
+(NSArray *)allFileTypes;
+(void)registerImageClass:(Class)class;

+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;
+(NSArray *)fileTypes;

@end

#define XeeImageLoaderYield() { if(stop) [coro returnFrom]; }
#define XeeImageLoaderHeaderDone() { [coro returnFrom]; }
#define XeeImageLoaderDone(success) { loaded=success; [coro returnFrom]; }




@interface NSObject (XeeImageDelegate)

-(void)xeeImageLoadingProgress:(XeeImage *)image;
-(void)xeeImageDidChange:(XeeImage *)image;
-(void)xeeImageSizeDidChange:(XeeImage *)image;
-(void)xeeImagePropertiesDidChange:(XeeImage *)image;

@end
