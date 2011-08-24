#import "XeeImage.h"



@implementation XeeImage

-(id)init
{
	if(self=[super init]) [self _initImage];

	return self;
}


-(id)initWithFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes
{
	if(self=[super init])
	{
		[self _initImage];
		filename=[name retain];
		header=[block retain];
		attrs=[attributes retain];

		@try { nextselector=[self identifyFile]; }
		@catch(id exception)
		{
			NSLog(@"Failure while identifying file \"%@\". Exception: %@",filename,exception);
			nextselector=NULL;
		}

		if(nextselector) return self;
		else [self deallocLoader];

		[self release];
	}

	return nil;
}

-(void)_initImage
{
	filename=nil;
	attrs=nil;
	header=nil;
	filehandle=nil;

	stop=NO;
	thumbnailonly=NO;
	success=NO;
	nextselector=NULL;
	lock=[[NSLock alloc] init];

	format=nil;
	width=height=0;
	depth=nil;
	depthicon=nil;
	transparent=NO;
	back=nil;
	orientation=XeeNoTransformation;
	correctorientation=XeeUnknownTransformation;
	crop_x=crop_y=crop_width=crop_height=0;

	properties=[[NSMutableArray array] retain];

	delegate=nil;
}

-(void)dealloc
{
	if(nextselector) [self deallocLoader];

	[filename release];
	[header release];
	[attrs release];

	[back release];
	[format release];
	[depth release];
	[depthicon release];
	[properties release];

	[lock release];

	[super dealloc];
}

/*-(id)retain
{
	NSLog(@"XeeImage %@ retain, new count: %d",filename,[self retainCount]+1);
	return [super retain];
}
-(void)release
{
	NSLog(@"XeeImage %@ release, new count: %d",filename,[self retainCount]-1);
	[super release];
}*/



-(SEL)identifyFile { return NULL; }

-(void)deallocLoader
{
	[filehandle release];
	filehandle=nil;
}



-(void)runLoader
{
	if(!nextselector) return;

	stop=NO;

	while(!stop)
	{
		@try { nextselector=(SEL)[self performSelector:nextselector]; }
		@catch(id exception)
		{
			NSLog(@"Failed to load file \"%@\". Exception: %@",filename,exception);
			nextselector=NULL;
		}

		if(!nextselector)
		{
			[self triggerChangeAction];
			[self deallocLoader];
			return;
		}
	}
}

-(void)runLoaderForThumbnail { thumbnailonly=YES; [self runLoader]; }

-(void)stopLoading { stop=YES; }

-(BOOL)hasBeenStopped { return stop; }

-(XeeFileHandle *)fileHandle
{
	if(!filename) return nil;
	if(filehandle) return filehandle;

	filehandle=[[XeeFileHandle fileHandleWithPath:filename] retain];
	if(!filehandle) [NSException raise:@"XeeFileOpenException" format:@"Couldn't open file \"%@\" for reading",filename];
	return filehandle;
}



-(BOOL)completed
{
	return nextselector==NULL;
}

-(BOOL)failed
{
	return nextselector==NULL&&!success;
}



-(int)frames { return 0; }

-(void)setFrame:(int)frame { }

-(int)frame { return 0; }



-(void)setDelegate:(id)del
{
	[lock lock];
	delegate=del;
	[lock unlock];
}

-(void)triggerLoadingAction
{
	[lock lock];
	[delegate performSelectorOnMainThread:@selector(xeeImageLoadingProgress:) withObject:self waitUntilDone:NO];
	[lock unlock];
}

-(void)triggerChangeAction
{
	[lock lock];
	[delegate performSelectorOnMainThread:@selector(xeeImageDidChange:) withObject:self waitUntilDone:NO];
	[lock unlock];
}

-(void)triggerSizeChangeAction
{
	[lock lock];
	[delegate performSelectorOnMainThread:@selector(xeeImageSizeDidChange:) withObject:self waitUntilDone:NO];
	[lock unlock];
}

-(void)triggerPropertyChangeAction
{
	[lock lock];
	[delegate performSelectorOnMainThread:@selector(xeeImagePropertiesDidChange:) withObject:self waitUntilDone:NO];
	[lock unlock];
}


-(BOOL)animated { return NO; }

-(void)setAnimating:(BOOL)animating { }

-(void)setAnimatingDefault { }

-(BOOL)animating { return NO; }



-(NSRect)updatedAreaInRect:(NSRect)rect { return NSMakeRect(0,0,0,0); }



-(void)drawInRect:(NSRect)rect bounds:(NSRect)bounds { [self drawInRect:rect bounds:bounds lowQuality:NO]; }

-(void)drawInRect:(NSRect)rect bounds:(NSRect)bounds lowQuality:(BOOL)lowquality {}



-(CGImageRef)makeCGImage { return NULL; }



-(int)losslessFlags { return 0; }

-(BOOL)losslessSaveTo:(NSString *)destination flags:(int)flags { return NO; }



-(NSString *)filename { return filename; }

-(NSString *)format { return format; }

-(int)width
{
	if(XeeTransformationIsFlipped(orientation)) return crop_width?crop_width:width;
	else return crop_height?crop_height:height;
}

-(int)height
{
	if(XeeTransformationIsFlipped(orientation)) return crop_height?crop_height:height;
	else return crop_width?crop_width:width;
}

-(int)fullWidth
{
	if(XeeTransformationIsFlipped(orientation)) return width;
	else return height;
}

-(int)fullHeight
{
	if(XeeTransformationIsFlipped(orientation)) return height;
	else return width;
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
	return XeeTransformRect(orientation,width,height,[self rawCroppingRect]);
}
-(NSRect)rawCroppingRect
{
	if(crop_width) return NSMakeRect(crop_x,crop_y,crop_width,crop_height);
	else return NSMakeRect(0,0,width,height);
}

-(XeeTransformationMatrix)transformationMatrix
{
	if(crop_width) return XeeMultiplyMatrices(
		XeeMatrixForTransformation(orientation,crop_width,crop_height),
		XeeTranslationMatrix(-crop_x,-crop_y)
	);
	else return XeeMatrixForTransformation(orientation,width,height);
}

-(BOOL)isTransformed { return [self isRotated]||[self isCropped]; }

-(BOOL)isRotated
{
	return XeeTransformationIsNonTrivial([self orientation]);
}

-(BOOL)isCropped
{
	NSRect crop=[self croppingRect];
	return crop.size.width!=[self fullWidth]||crop.size.height!=[self fullHeight];
}



-(NSArray *)properties
{
	NSMutableArray *array=[NSMutableArray array];

	NSArray *imgprops=[NSArray arrayWithObjects:
		@"Image width",[NSNumber numberWithInt:[self width]],
		@"Image height",[NSNumber numberWithInt:[self height]],
		@"File format",[self format],
		@"Colour format",[self depth],
	nil];

	[array addObject:@"Image properties"];
	[array addObject:imgprops];

	NSRect crop=[self croppingRect];
	int fullwidth=[self fullWidth];
	int fullheight=[self fullHeight];

	if(crop.size.width!=fullwidth&&crop.size.height!=fullheight)
	{
		NSArray *imgprops=[NSArray arrayWithObjects:
			@"Full image width",[NSNumber numberWithInt:fullwidth],
			@"Full image height",[NSNumber numberWithInt:fullheight],
			@"Cropping top offset",[NSNumber numberWithInt:crop.origin.y],
			@"Cropping bottom offset",[NSNumber numberWithInt:fullheight-crop.size.height-crop.origin.y],
			@"Cropping left offset",[NSNumber numberWithInt:crop.origin.x],
			@"Cropping right offset",[NSNumber numberWithInt:fullwidth-crop.size.width-crop.origin.x],
			// and rotation?
		nil];

		[array addObject:@"Cropping properties"];
		[array addObject:imgprops];
	}

	if(filename&&attrs)
	{
		NSMutableArray *fileprops=[NSMutableArray array];

		[fileprops addObject:@"File name"];
		[fileprops addObject:[self descriptiveFilename]];

		[fileprops addObject:@"Full path"];
		[fileprops addObject:filename];

		[fileprops addObject:@"File size"];
		[fileprops addObject:[NSString stringWithFormat:@"%@ (%qu bytes)",[self descriptiveFileSize],[self fileSize]]];

		[fileprops addObject:@"Modification date"];
		[fileprops addObject:[[attrs fileModificationDate] descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M" timeZone:nil locale:nil]];

		[fileprops addObject:@"Creation date"];
		[fileprops addObject:[[attrs fileCreationDate] descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M" timeZone:nil locale:nil]];

		NSString *namepart=[[[self filename] lastPathComponent] stringByDeletingPathExtension];
		int len=[namepart length];

		if(len==10||len==13||len==17)
		{
			BOOL matches=YES;
			for(int i=0;i<len;i++)
			{
				unichar c=[namepart characterAtIndex:i];
				if(i<13&&!(c>='0'||c<='9')) matches=NO;
				if(i>=13&&!((c>='0'&&c<='9')||(c>='a'||c<='f')||(c>='A'||c<='F'))) matches=NO;
			}

			if(matches)
			{
				if(len>10) namepart=[namepart substringToIndex:10];
				int seconds=[namepart intValue];

				if(seconds>1000000000)
				{
					NSDate *filedate=[NSDate dateWithTimeIntervalSince1970:seconds];

					if(len==10) [fileprops addObject:@"Filename timestamp"];
					else [fileprops addObject:@"Futaba timestamp"];
					[fileprops addObject:[filedate descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M" timeZone:nil locale:nil]];
				}
			}
		}

		[array addObject:@"File properties"];
		[array addObject:fileprops];
	}

	[array addObjectsFromArray:properties];

	return array;
}



-(unsigned long long)fileSize
{
	return [attrs fileSize];
}



-(NSString *)descriptiveFilename
{
	if(!filename) return nil;
	return [[self filename] lastPathComponent];
}

-(NSString *)descriptiveFileSize
{
	if(!attrs) return nil;
	return [XeeImage describeFileSize:[attrs fileSize]];
}

-(NSString *)descriptiveDate
{
	if(!attrs) return nil;
	return [[attrs fileModificationDate] descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M" timeZone:nil locale:nil];
}



-(void)setFilename:(NSString *)name { [filename autorelease]; filename=[name retain]; }

-(void)setFormat:(NSString *)fmt { [format autorelease]; format=[fmt retain]; }

-(void)setBackgroundColor:(NSColor *)col { [back autorelease]; back=[col retain]; }

-(void)setOrientation:(XeeTransformation)trans
{
	BOOL sizechanged=XeeTransformationIsFlipped(orientation)!=XeeTransformationIsFlipped(trans);

	orientation=trans;

	if(sizechanged) [self triggerSizeChangeAction];
	else [self triggerChangeAction];

	[self triggerPropertyChangeAction];
}

-(void)setCorrectOrientation:(XeeTransformation)trans
{
	correctorientation=trans;
	if(correctorientation&&[[NSUserDefaults standardUserDefaults] boolForKey:@"useOrientation"])
	orientation=trans;
}

-(void)setCroppingRect:(NSRect)rect
{
	XeeTransformationMatrix mtx=XeeInverseMatrix(XeeMatrixForTransformation(orientation,width,height));
	NSRect newcrop=XeeTransformRectWithMatrix(mtx,rect);
	NSRect clipped=NSIntersectionRect(newcrop,NSMakeRect(0,0,width,height));

	if(clipped.size.width==width&&clipped.size.height==height)
	{
		crop_x=crop_y=0;
		crop_width=width;
		crop_height=height;
	}
	else if(clipped.size.width&&clipped.size.height)
	{
		crop_x=clipped.origin.x;
		crop_y=clipped.origin.y;
		crop_width=clipped.size.width;
		crop_height=clipped.size.height;
	}
	[self triggerSizeChangeAction];
	[self triggerPropertyChangeAction];
}

-(void)resetTransformations
{
	if(correctorientation&&[[NSUserDefaults standardUserDefaults] boolForKey:@"useOrientation"])
	orientation=correctorientation;
	else orientation=XeeNoTransformation;

	crop_x=crop_y=0;
	crop_width=width;
	crop_height=height;

	[self triggerSizeChangeAction];
	[self triggerPropertyChangeAction];
}




-(void)setDepth:(NSString *)d { [depth autorelease]; depth=[d retain]; }

-(void)setDepthIcon:(NSImage *)icon { [depthicon autorelease]; depthicon=[icon retain]; }

-(void)setDepthIconName:(NSString *)iconname { [self setDepthIcon:[NSImage imageNamed:iconname]]; }

-(void)setDepth:(NSString *)d iconName:(NSString *)iconname { [self setDepth:d]; [self setDepthIconName:iconname]; }

-(void)setDepthBitmap
{
	[self setDepth:NSLocalizedString(@"Bitmap",@"Description for bitmap images")];
	[self setDepthIconName:@"depth_bitmap"];
}

-(void)setDepthIndexed:(int)colors
{
	[self setDepth:[NSString stringWithFormat:NSLocalizedString(@"%d colours",@"Description for indexed-colour images"),colors]];
	[self setDepthIconName:@"depth_indexed"]; // needs alpha!
}

-(void)setDepthGrey:(int)bits { [self setDepthGrey:bits alpha:NO floating:NO]; }

-(void)setDepthGrey:(int)bits alpha:(BOOL)alpha floating:(BOOL)floating
{
	if(alpha)
	{
		if(floating)
		[self setDepth:[NSString stringWithFormat:NSLocalizedString(@"%d bit FP grey+alpha",@"Description for floating-point grey+alpha images"),bits]];
		else
		[self setDepth:[NSString stringWithFormat:NSLocalizedString(@"%d bit grey+alpha",@"Description for grey+alpha images"),bits]];

		[self setDepthIconName:@"depth_greyalpha"];
	}
	else
	{
		if(floating)
		[self setDepth:[NSString stringWithFormat:NSLocalizedString(@"%d bit FP grey",@"Description for floating-point greyscale images"),bits]];
		else
		[self setDepth:[NSString stringWithFormat:NSLocalizedString(@"%d bit grey",@"Description for greyscale images"),bits]];

		[self setDepthIconName:@"depth_grey"];
	}
}

-(void)setDepthRGB:(int)bits { [self setDepthRGB:bits alpha:NO floating:NO]; }

-(void)setDepthRGBA:(int)bits { [self setDepthRGB:bits alpha:YES floating:NO]; }

-(void)setDepthRGB:(int)bits alpha:(BOOL)alpha floating:(BOOL)floating
{
	if(alpha)
	{
		if(floating)
		[self setDepth:[NSString stringWithFormat:NSLocalizedString(@"%d bit FP RGBA",@"Description for floating-point RGBA images"),bits]];
		else
		[self setDepth:[NSString stringWithFormat:NSLocalizedString(@"%d bit RGBA",@"Description for RGBA images"),bits]];

		[self setDepthIconName:@"depth_rgba"];
	}
	else
	{
		if(floating)
		[self setDepth:[NSString stringWithFormat:NSLocalizedString(@"%d bit FP RGB",@"Description for floating-point RGB images"),bits]];
		else
		[self setDepth:[NSString stringWithFormat:NSLocalizedString(@"%d bit RGB",@"Description for RGB images"),bits]];

		[self setDepthIconName:@"depth_rgb"];
	}
}


-(void)setDepthCMYK:(int)bits alpha:(BOOL)alpha
{
	if(alpha)
	[self setDepth:[NSString stringWithFormat:NSLocalizedString(@"%d bit CMYK+alpha",@"Description for CMYK+alpha images"),bits]];
	else
	[self setDepth:[NSString stringWithFormat:NSLocalizedString(@"%d bit CMYK",@"Description for CMYK images"),bits]];

	[self setDepthIconName:@"depth_cmyk"];
}

-(void)setDepthLab:(int)bits alpha:(BOOL)alpha
{
	if(alpha)
	[self setDepth:[NSString stringWithFormat:NSLocalizedString(@"%d bit Lab+alpha",@"Description for Lab+alpha images"),bits]];
	else
	[self setDepth:[NSString stringWithFormat:NSLocalizedString(@"%d bit Lab",@"Description for Lab images"),bits]];

	[self setDepthIconName:@"depth_rgb"];
}



-(id)description
{
	return [NSString stringWithFormat:@"<%@> %@ (%dx%d %@ %@, %@, %d frames, created on %@)",
	[[self class] description],[self descriptiveFilename],[self width],[self height],
	[self depth],[self format],[self descriptiveFileSize],[self frames],[self descriptiveDate]];
}




NSMutableArray *imageclasses=nil;

+(void)initialize
{
	if(!imageclasses) imageclasses=[[NSMutableArray alloc] initWithCapacity:8];
}

+(XeeImage *)imageForFilename:(NSString *)filename
{
	NSDictionary *attrs=[[NSFileManager defaultManager] fileAttributesAtPath:filename traverseLink:YES];
	if(!attrs) return nil;

	NSFileHandle *file=[NSFileHandle fileHandleForReadingAtPath:filename];
	if(!file) return nil;

	NSData *block=[file readDataOfLength:512];
	if(!block) return nil;

	[file closeFile];

	NSEnumerator *enumerator=[imageclasses objectEnumerator];
	Class class;

	while(class=[enumerator nextObject])
	{
		XeeImage *image=[[class alloc] initWithFile:filename firstBlock:block attributes:attrs];
		if(image)
		{
			if([image failed]) [image release];
			else return [image autorelease];
		}
	}

	return nil;
}

+(void)registerImageClass:(Class)class
{
	[imageclasses addObject:class];
}

+(NSArray *)fileTypes
{
	NSMutableArray *types=[NSMutableArray arrayWithCapacity:32];
	NSEnumerator *enumerator=[imageclasses objectEnumerator];
	Class class;

	while(class=[enumerator nextObject])
	{
		NSEnumerator *typeenum=[[class fileTypes] objectEnumerator];
		NSString *type;
		while(type=[typeenum nextObject]) if(![types containsObject:type]) [types addObject:type];
	}

	return types;
}

+(NSString *)describeFileSize:(int)size
{
	if(size<10000) return [NSString stringWithFormat:@"%d B",size];
	else if(size<102400) return [NSString stringWithFormat:@"%.2f kB",((float)size/1024.0)];
	else if(size<1024000) return [NSString stringWithFormat:@"%.1f kB",((float)size/1024.0)];
//	else if(size<10240000) return [NSString stringWithFormat:@"%d kB",size/1024];
	else return [NSString stringWithFormat:@"%d kB",size/1024];
}

@end



@implementation NSObject (XeeImageDelegate)

-(void)xeeImageLoadingProgress:(XeeImage *)image {}
-(void)xeeImageDidChange:(XeeImage *)image {}
-(void)xeeImageSizeDidChange:(XeeImage *)image {}
-(void)xeeImagePropertiesDidChange:(XeeImage *)image {}

@end


