#import <Cocoa/Cocoa.h>

#import "XeeTypes.h"
#import "CSCoroutine.h"
#import "XeeFSRef.h"
#import "XeeProperties.h"

#import <XADMaster/CSFileHandle.h>

#define XeeCanSaveLosslesslyFlag 1
#define XeeCanOverwriteLosslesslyFlag 2
#define XeeNotActuallyLosslessFlag 4
#define XeeCroppingIsInexactFlag 8
#define XeeHasUntransformableBlocksFlag 16
#define XeeUntransformableBlocksCanBeRetainedFlag 32
	
#define XeeTrimCroppingFlag 1
#define XeeRetainUntransformableBlocksFlag 2

//#define Xee

@interface XeeImage:NSObject
{
	CSHandle *handle;
	XeeFSRef *ref;
	NSDictionary *attrs;

	SEL nextselector;
	BOOL finished,loaded,thumbonly;
	volatile BOOL stop;

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
-(id)initWithHandle:(CSHandle *)fh;
-(id)initWithHandle:(CSHandle *)fh ref:(XeeFSRef *)fsref attributes:(NSDictionary *)attributes;
-(id)initWithHandle2:(CSHandle *)fh ref:(XeeFSRef *)fsref attributes:(NSDictionary *)attributes;
-(void)dealloc;

-(SEL)initLoader;
-(void)deallocLoader;

-(void)runLoader;
-(void)runLoaderForThumbnail;

-(void)runLoader2;
-(void)load;

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
-(NSString *)losslessFormat;
-(NSString *)losslessExtension;
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

-(XeeTransformation)orientation;
-(XeeTransformation)correctOrientation;
-(NSRect)croppingRect;
-(NSRect)rawCroppingRect;
-(BOOL)isTransformed;
-(BOOL)isCropped;
-(XeeMatrix)transformationMatrix;
-(XeeMatrix)transformationMatrixInRect:(NSRect)rect;

-(NSArray *)properties;

-(NSDictionary *)attributes;
-(uint64_t)fileSize;
-(NSDate *)date;
-(NSString *)descriptiveFilename;

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
+(XeeImage *)imageForHandle:(CSHandle *)fh;
+(XeeImage *)imageForHandle:(CSHandle *)fh ref:(XeeFSRef *)ref attributes:(NSDictionary *)attrs;
+(NSArray *)allFileTypes;
+(NSDictionary *)fileTypeDictionary;
+(void)registerImageClass:(Class)class;

+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;
+(NSArray *)fileTypes;

@end

static inline void __XeeImageLoaderYield(volatile BOOL *stop,CSCoroutine *coro) { if(*stop) { *stop=NO; [coro returnFrom]; } }
static inline void __XeeImageLoaderDone(BOOL success,BOOL *loaded,BOOL *finished,CSCoroutine *coro) { *loaded=success; *finished=YES; for(;;) [coro returnFrom]; }
#define XeeImageLoaderHeaderDone() [coro returnFrom]
#define XeeImageLoaderYield() __XeeImageLoaderYield(&stop,coro)
#define XeeImageLoaderDone(success) __XeeImageLoaderDone(success,&loaded,&finished,coro)



@interface NSObject (XeeImageDelegate)

-(void)xeeImageLoadingProgress:(XeeImage *)image;
-(void)xeeImageDidChange:(XeeImage *)image;
-(void)xeeImageSizeDidChange:(XeeImage *)image;
-(void)xeeImagePropertiesDidChange:(XeeImage *)image;

@end
