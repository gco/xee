#import "XeeImage.h"
#import "XeeMultiImage.h"
#import "XeeStringAdditions.h"

#import <pthread.h>


@implementation XeeImage

-(id)init
{
	if(self=[super init])
	{
		handle=nil;
		ref=nil;
		attrs=nil;

		nextselector=NULL;
		finished=loaded=YES;
		thumbonly=stop=NO;

		coro=nil;

		format=nil;
		width=height=0;
		depth=nil;
		icon=depthicon=nil;
		transparent=NO;
		back=nil;

		orientation=XeeNoTransformation;
		correctorientation=XeeUnknownTransformation;
		crop_x=crop_y=0;
		crop_width=crop_height=0;

		delegate=nil;

		properties=[[NSMutableArray array] retain];

	}

	return self;
}

-(id)initWithHandle:(CSHandle *)fh
{
	return [self initWithHandle:fh ref:nil attributes:nil];
}

-(id)initWithHandle:(CSHandle *)fh ref:(XeeFSRef *)fsref attributes:(NSDictionary *)attributes
{
	if(self=[self init])
	{
		handle=[fh retain];
		ref=[fsref retain];
		attrs=[attributes retain];

		if(ref)
		{
			icon=[[[NSWorkspace sharedWorkspace] iconForFile:[ref path]] retain];
			[icon setSize:NSMakeSize(16,16)];
		}
		else icon=nil;

		finished=loaded=NO;

		coro=[self newCoroutine];

		CSCoroutine *currcoro=[CSCoroutine currentCoroutine];
		@try { [(XeeImage *)coro load]; }
		@catch(id e)
		{
			[CSCoroutine setCurrentCoroutine:currcoro];
			NSLog(@"Exception during initial loading of \"%@\" (%@): %@",[self descriptiveFilename],[self class],e);
			finished=YES;
		}

		if(finished) { [coro release]; coro=nil; }

		if(!finished||loaded)
		{
			return self;
		}

		[self release];
	}
	return nil;
}

-(id)initWithHandle2:(CSHandle *)fh ref:(XeeFSRef *)fsref attributes:(NSDictionary *)attributes
{
	if(self=[self init])
	{
		handle=[fh retain];
		ref=[fsref retain];
		attrs=[attributes retain];
		icon=[[[NSWorkspace sharedWorkspace] iconForFile:[ref path]] retain]; // needs fixing!
		[icon setSize:NSMakeSize(16,16)];

		nextselector=@selector(initLoader);
		stop=NO;
		loaded=NO;

		@try
		{
			do {
				NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
				nextselector=(SEL)[self performSelector:nextselector];
				[pool release];
			} while(nextselector&&!width&&!height);
		}
		@catch(id e)
		{
			NSLog(@"Exception during initial loading of \"%@\" (%@): %@",[self descriptiveFilename],[self class],e);
			nextselector=NULL;
		}

		if(nextselector||loaded)
		{
			return self;
		}

		[self release];
	}
	return nil;
}



-(void)dealloc
{
	if(nextselector) [self deallocLoader];

	[handle release];
	[ref release];
	[attrs release];

	[coro release];

	[format release];
	[depth release];
	[icon release];
	[depthicon release];
	[back release];

	[properties release];

	[super dealloc];
}


-(void)runLoader
{
	if(finished) return;

	CSCoroutine *currcoro=[CSCoroutine currentCoroutine];
	@try { [coro switchTo]; }
	@catch(id e)
	{
		[CSCoroutine setCurrentCoroutine:currcoro];
		NSLog(@"Exception during loading of \"%@\" (%@): %@",[self descriptiveFilename],[self class],e);
		finished=YES;
	}

	if(finished)
	{
		[coro release];
		coro=nil;
		[self triggerChangeAction];
	}
}

-(void)runLoaderForThumbnail
{
	thumbonly=YES;
	[self runLoader];
}

-(void)load
{
	nextselector=@selector(initLoader);
	do
	{
		BOOL hashead=(width&&height);

		nextselector=(SEL)[self performSelector:nextselector];

		if(!hashead&&(width&&height)) { XeeImageLoaderHeaderDone(); }
		else { XeeImageLoaderYield(); }
	} while(nextselector);

	[self deallocLoader];
	XeeImageLoaderDone(loaded);
}




-(SEL)initLoader { return NULL; }

-(void)deallocLoader { }

-(void)runLoader2
{
	if(!nextselector) return;

	stop=NO;
	@try
	{
		do {
			NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
			nextselector=(SEL)[self performSelector:nextselector];
			[pool release];
		} while(nextselector&&!stop);
	}
	@catch(id e)
	{
		NSLog(@"Exception during loading of \"%@\": %@",[self descriptiveFilename],e);
		nextselector=NULL;
	}

	if(!nextselector)
	{
		[self deallocLoader];
		[self triggerChangeAction];
	}
}



-(BOOL)loaded { return loaded; }

//-(BOOL)failed { return nextselector==NULL&&!loaded; }

//-(BOOL)needsLoading { return nextselector!=NULL; }

-(BOOL)failed { return finished&&!loaded; }

-(BOOL)needsLoading { return !finished; }

-(void)stopLoading { stop=YES; }

-(BOOL)hasBeenStopped { return stop; }

-(CSHandle *)handle { return handle; }

-(CSFileHandle *)fileHandle
{
	if([handle isKindOfClass:[CSFileHandle class]]) return (CSFileHandle *)handle;
	else [NSException raise:@"XeeHandleNotAFileHandleException" format:@"The image class %@ can only load image from files.",[self class]];
	return nil;
}



-(int)frames { return 1; }

-(void)setFrame:(int)frame { }

-(int)frame { return 0; }



-(void)setDelegate:(id)newdelegate
{
	delegate=newdelegate;
}

#include <unistd.h>
-(void)triggerLoadingAction
{
	if(pthread_main_np()) [delegate xeeImageLoadingProgress:self];
	else [delegate performSelectorOnMainThread:@selector(xeeImageLoadingProgress:) withObject:self waitUntilDone:NO];
//	usleep(20000);
}

-(void)triggerChangeAction
{
	if(pthread_main_np()) [delegate xeeImageDidChange:self];
	else [delegate performSelectorOnMainThread:@selector(xeeImageDidChange:) withObject:self waitUntilDone:NO];
}

-(void)triggerSizeChangeAction
{
	if(pthread_main_np()) [delegate xeeImageSizeDidChange:self];
	else [delegate performSelectorOnMainThread:@selector(xeeImageSizeDidChange:) withObject:self waitUntilDone:NO];
}

-(void)triggerPropertyChangeAction
{
	if(pthread_main_np()) [delegate xeeImagePropertiesDidChange:self];
	else [delegate performSelectorOnMainThread:@selector(xeeImagePropertiesDidChange:) withObject:self waitUntilDone:NO];
}



-(BOOL)animated { return NO; }

-(void)setAnimating:(BOOL)animating { }

-(void)setAnimatingDefault { }

-(BOOL)animating { return NO; }



-(NSRect)updatedAreaInRect:(NSRect)rect { return NSMakeRect(0,0,0,0); }



-(void)drawInRect:(NSRect)rect bounds:(NSRect)bounds { [self drawInRect:rect bounds:bounds lowQuality:NO]; }

-(void)drawInRect:(NSRect)rect bounds:(NSRect)bounds lowQuality:(BOOL)lowquality {}



-(CGImageRef)createCGImage { return NULL; }

-(int)losslessSaveFlags { return 0; }

-(NSString *)losslessFormat { return nil; }

-(NSString *)losslessExtension { return nil; }

-(BOOL)losslessSaveTo:(NSString *)path flags:(int)flags { return NO; }



-(XeeFSRef *)ref { return ref; }

-(NSString *)filename { return [ref path]; }

-(NSString *)format { return format; }

-(NSImage *)icon { return icon; }

-(int)width
{
	if(XeeTransformationIsFlipped(orientation)) return crop_height?crop_height:height;
	else return crop_width?crop_width:width;
}

-(int)height
{
	if(XeeTransformationIsFlipped(orientation)) return crop_width?crop_width:width;
	else return crop_height?crop_height:height;
}

-(int)fullWidth
{
	if(XeeTransformationIsFlipped(orientation)) return height;
	else return width;
}

-(int)fullHeight
{
	if(XeeTransformationIsFlipped(orientation)) return width;
	else return height;
}

-(NSString *)depth { return depth; }

-(NSImage *)depthIcon { return depthicon; }

-(BOOL)transparent { return transparent; }

-(NSColor *)backgroundColor
{
	if(!back) back=[[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:@"defaultImageBackground"]] retain];

	return back;
}

-(XeeTransformation)orientation { return orientation; }

-(XeeTransformation)correctOrientation { return correctorientation; }

-(NSRect)croppingRect
{
	return XeeTransformRect(XeeMatrixForTransformation(orientation,width,height),[self rawCroppingRect]);
}

-(NSRect)rawCroppingRect
{
	if(crop_width||crop_height) return NSMakeRect(crop_x,crop_y,crop_width,crop_height);
	else return NSMakeRect(0,0,width,height);
}

-(BOOL)isTransformed
{
	if([self isCropped]) return YES;
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"useOrientation"])
	{
		XeeTransformation corr=[self correctOrientation];
		if(corr) return corr==[self orientation];
	}
	return XeeTransformationIsNonTrivial([self orientation]);
}

-(BOOL)isCropped
{
	return [self width]!=[self fullWidth]||[self height]!=[self fullHeight];
}

-(XeeMatrix)transformationMatrix
{
	return XeeMultiplyMatrices(
		XeeMatrixForTransformation(orientation,crop_width?crop_width:width,crop_height?crop_height:height),
		XeeTranslationMatrix(-crop_x,-crop_y));
}

-(XeeMatrix)transformationMatrixInRect:(NSRect)rect
{
	return XeeMultiplyMatrices(
		XeeTransformRectToRectMatrix(NSMakeRect(0,0,[self width],[self height]),rect),
		[self transformationMatrix]);
}

-(NSArray *)properties { return properties; }



-(NSDictionary *)attributes { return attrs; }

-(uint64_t)fileSize { return [attrs fileSize]; }

-(NSDate *)date { return [attrs fileModificationDate]; }

-(NSString *)descriptiveFilename
{
	NSString *name=[self filename];
	if(name) return name;
	if(delegate&&[delegate isKindOfClass:[XeeImage class]]) return [delegate filename];
	return nil;
}



-(void)setFormat:(NSString *)fmt { [format autorelease]; format=[fmt retain]; }

-(void)setBackgroundColor:(NSColor *)col { [back autorelease]; back=[col retain]; }

-(void)setProperties:(NSArray *)newproperties { [properties removeAllObjects]; [properties addObjectsFromArray:newproperties]; }

-(void)setOrientation:(XeeTransformation)transformation
{
	if(transformation==orientation) return;

	BOOL sizechanged=XeeTransformationIsFlipped(orientation)!=XeeTransformationIsFlipped(transformation);

	orientation=transformation;

	if(sizechanged) [self triggerSizeChangeAction];
	else [self triggerChangeAction];
	[self triggerPropertyChangeAction];
}

-(void)setCorrectOrientation:(XeeTransformation)transformation
{
	correctorientation=transformation;

	if(correctorientation)
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"useOrientation"])
	orientation=correctorientation;
}

-(void)setCroppingRect:(NSRect)rect
{
//	XeeMatrix inv=XeeInverseMatrix([self transformationMatrix]);
	XeeMatrix inv=XeeInverseMatrix(XeeMatrixForTransformation(orientation,width,height));

	NSRect newcrop=XeeTransformRect(inv,rect);
	if(newcrop.size.width==width&&newcrop.size.height==height)
	{
		crop_x=crop_y=0;
		crop_width=crop_height=0;
	}
	else
	{
		crop_x=newcrop.origin.x;
		crop_y=newcrop.origin.y;
		crop_width=newcrop.size.width;
		crop_height=newcrop.size.height;
	}
	[self triggerSizeChangeAction];
	[self triggerPropertyChangeAction];
}

-(void)resetTransformations
{
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"useOrientation"]) orientation=correctorientation;	
	else orientation=XeeNoTransformation;

	crop_x=crop_y=0;
	crop_width=crop_height=0;

	[self triggerSizeChangeAction];
	[self triggerPropertyChangeAction];
}




-(void)setDepth:(NSString *)d { [depth autorelease]; depth=[d retain]; }

-(void)setDepthIcon:(NSImage *)newicon { [depthicon autorelease]; depthicon=[newicon retain]; }

-(void)setDepthIconName:(NSString *)iconname { [self setDepthIcon:[NSImage imageNamed:iconname]]; }

-(void)setDepth:(NSString *)d iconName:(NSString *)iconname { [self setDepth:d]; [self setDepthIconName:iconname]; }

-(void)setDepthBitmap
{
	[self setDepth:NSLocalizedString(@"Bitmap",@"Description for 1-bit bitmapped images")
	iconName:@"depth_bitmap"];
}

-(void)setDepthIndexed:(int)colors
{
	[self setDepth:
	[NSString stringWithFormat:NSLocalizedString(@"%d colours",@"Description for indexed-colour images"),colors]
	iconName:@"depth_indexed"]; // needs alpha!
}

-(void)setDepthGrey:(int)bits alpha:(BOOL)alpha floating:(BOOL)floating
{
	if(bits==1&&!alpha) [self setDepthBitmap];
	else if(floating&&alpha) [self setDepth:
		[NSString stringWithFormat:NSLocalizedString(@"%d bits FP grey+alpha",@"Description for floating-point grey+alpha images"),bits]
		iconName:@"depth_greyalpha"];
	else if(floating) [self setDepth:
		[NSString stringWithFormat:NSLocalizedString(@"%d bits FP grey",@"Description for floating-point greyscale images"),bits]
		iconName:@"depth_grey"];
	else if(alpha) [self setDepth:
		[NSString stringWithFormat:NSLocalizedString(@"%d bits grey+alpha",@"Description for grey+alpha images"),bits]
		iconName:@"depth_greyalpha"];
	else [self setDepth:
		[NSString stringWithFormat:NSLocalizedString(@"%d bits grey",@"Description for greyscale images"),bits]
		iconName:@"depth_grey"];
}

-(void)setDepthRGB:(int)bits alpha:(BOOL)alpha floating:(BOOL)floating
{
	if(floating&&alpha) [self setDepth:
		[NSString stringWithFormat:NSLocalizedString(@"%d bits FP RGBA",@"Description for floating-point RGBA images"),bits]
		iconName:@"depth_rgba"];
	else if(floating) [self setDepth:
		[NSString stringWithFormat:NSLocalizedString(@"%d bits FP RGB",@"Description for floating-point RGB images"),bits]
		iconName:@"depth_rgb"];
	else if(alpha) [self setDepth:
		[NSString stringWithFormat:NSLocalizedString(@"%d bits RGBA",@"Description for RGBA images"),bits]
		iconName:@"depth_rgba"];
	else [self setDepth:
		[NSString stringWithFormat:NSLocalizedString(@"%d bits RGB",@"Description for RGBA images"),bits]
		iconName:@"depth_rgb"];
}

-(void)setDepthCMYK:(int)bits alpha:(BOOL)alpha
{
	if(alpha) [self setDepth:
		[NSString stringWithFormat:NSLocalizedString(@"%d bits CMYK+alpha",@"Description for CMYK+alpha images"),bits]
		iconName:@"depth_cmyk"];
	else [self setDepth:
		[NSString stringWithFormat:NSLocalizedString(@"%d bits CMYK",@"Description for CMYK images"),bits]
		iconName:@"depth_cmyk"];
}

-(void)setDepthLab:(int)bits alpha:(BOOL)alpha
{
	if(alpha) [self setDepth:
		[NSString stringWithFormat:NSLocalizedString(@"%d bits Lab+alpha",@"Description for Lab+alpha images"),bits]
		iconName:@"depth_rgb"];
	else [self setDepth:
		[NSString stringWithFormat:NSLocalizedString(@"%d bits Lab",@"Description for Lab images"),bits]
		iconName:@"depth_rgb"];
}

-(void)setDepthGrey:(int)bits { [self setDepthGrey:bits alpha:NO floating:NO]; }

-(void)setDepthRGB:(int)bits { [self setDepthRGB:bits alpha:NO floating:NO]; }

-(void)setDepthRGBA:(int)bits { [self setDepthRGB:bits alpha:YES floating:NO]; }




-(id)description
{
	return [NSString stringWithFormat:@"<%@> %@ (%dx%d %@ %@, %@, created on %@)",
	[[self class] description],[[self descriptiveFilename] lastPathComponent],[self width],[self height],
	[self depth],[self format],XeeDescribeSize([self fileSize]),XeeDescribeDate([self date])];
}




NSMutableArray *imageclasses=nil;


+(XeeImage *)imageForFilename:(NSString *)filename
{
	XeeFSRef *ref=[XeeFSRef refForPath:filename];
	if(ref) return [self imageForRef:ref];
	return nil;
}

+(XeeImage *)imageForRef:(XeeFSRef *)ref
{
	NSString *filename=[ref path];

	NSDictionary *attrs=[[NSFileManager defaultManager] fileAttributesAtPath:filename traverseLink:YES];
	if(!attrs) return nil;

	CSFileHandle *fh=[CSFileHandle fileHandleForReadingAtPath:filename];
	if(!fh) return nil;

	return [self imageForHandle:fh ref:ref attributes:attrs];
}

+(XeeImage *)imageForHandle:(CSHandle *)fh 
{
	return [self imageForHandle:fh ref:nil attributes:nil];
}

+(XeeImage *)imageForHandle:(CSHandle *)fh ref:(XeeFSRef *)ref attributes:(NSDictionary *)attrs
{
	if(!imageclasses) return nil;

	NSString *filename=[ref path];

	NSData *block=[fh readDataOfLengthAtMost:4096];
	if(!block) return nil;

	[fh seekToFileOffset:0];

	NSEnumerator *enumerator=[imageclasses objectEnumerator];
	Class class;
	while(class=[enumerator nextObject])
	{
		if([class canOpenFile:filename firstBlock:block attributes:attrs])
		{
			XeeImage *image=[[class alloc] initWithHandle:fh ref:ref attributes:attrs];
			if(image)
			{
				return [image autorelease];
			}
			[fh seekToFileOffset:0];
		}
	}

	return nil;
}


+(NSArray *)allFileTypes
{
	static NSMutableArray *types=nil;
	if(!types)
	{
		types=[[NSMutableArray array] retain];

		NSEnumerator *enumerator=[imageclasses objectEnumerator];
		Class class;
		while(class=[enumerator nextObject])
		{
			NSEnumerator *typeenum=[[class fileTypes] objectEnumerator];
			NSString *type;
			while(type=[typeenum nextObject]) if(![types containsObject:type]) [types addObject:type];
		}
	}
	return types;
}

+(NSDictionary *)fileTypeDictionary
{
	static NSMutableDictionary *typehash=nil;
	if(!typehash)
	{
		typehash=[[NSMutableDictionary dictionary] retain];
		NSEnumerator *enumerator=[[self allFileTypes] objectEnumerator];
		NSString *type;
		while(type=[enumerator nextObject]) [typehash setObject:@"" forKey:type];
	}
	return typehash;
}

+(void)registerImageClass:(Class)class
{
	if(!imageclasses) imageclasses=[[NSMutableArray array] retain];

	[imageclasses addObject:class];
}



+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes
{
	return NO;
}

+(NSArray *)fileTypes { return nil; }

@end



@implementation NSObject (XeeImageDelegate)

-(void)xeeImageLoadingProgress:(XeeImage *)image {}
-(void)xeeImageDidChange:(XeeImage *)image {}
-(void)xeeImageSizeDidChange:(XeeImage *)image {}
-(void)xeeImagePropertiesDidChange:(XeeImage *)image {}

@end
