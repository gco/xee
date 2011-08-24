#import "XeeMultiImage.h"



@implementation XeeMultiImage

-(id)init
{
	if(self=[super init])
	{
		if([self _initMultiImage]) return self;
		[self release];
	}

	return nil;
}

-(id)initWithFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes
{
	if(self=[super initWithFile:name firstBlock:block attributes:attributes])
	{
		if([self _initMultiImage]) return self;
		[self release];
	}

	return nil;
}

-(BOOL)_initMultiImage
{
	currindex=0;
	subimages=[[NSMutableArray array] retain];
	if(subimages) return YES;
	else return NO;
}

-(void)dealloc
{
	[subimages release];

	[super dealloc];
}

-(void)addSubImage:(XeeImage *)subimage
{
	[subimage setDelegate:self];
	[subimage setFilename:filename];
	[subimages addObject:subimage];
}

-(void)addSubImages:(NSArray *)array
{
	NSEnumerator *enumerator=[array objectEnumerator];
	XeeImage *image;
	while(image=[enumerator nextObject]) [self addSubImage:image];
}

-(void)xeeImageLoadingProgress:(XeeImage *)subimage
{
	if(!subimages||[subimages count]==0) return; // pretty unlikely
	if(subimage==[subimages objectAtIndex:currindex]) [self triggerLoadingAction];
}

-(void)xeeImageDidChange:(XeeImage *)subimage
{
	if(!subimages||[subimages count]==0) return; // pretty unlikely
	if(subimage==[subimages objectAtIndex:currindex]) [self triggerChangeAction];
}

-(void)xeeImageSizeDidChange:(XeeImage *)subimage
{
	if(!subimages||[subimages count]==0) return; // pretty unlikely
	if(subimage==[subimages objectAtIndex:currindex]) [self triggerSizeChangeAction];
}

-(void)xeeImagePropertiesDidChange:(XeeImage *)subimage
{
	if(!subimages||[subimages count]==0) return; // pretty unlikely
	if(subimage==[subimages objectAtIndex:currindex]) [self triggerPropertyChangeAction];
}

-(XeeImage *)currentSubImage
{
	if([subimages count]==0) return nil;
	else return [subimages objectAtIndex:currindex];
}


-(int)frames { return [subimages count]; }

-(void)setFrame:(int)frame
{
	if([subimages count]==0) return;

	if(frame<0) frame=0;
	if(frame>=[subimages count]) frame=[subimages count]-1;

	BOOL sizechanged=
		[[subimages objectAtIndex:currindex] width]!=[[subimages objectAtIndex:frame] width]||
		[[subimages objectAtIndex:currindex] height]!=[[subimages objectAtIndex:frame] height];

	currindex=frame;

	if(sizechanged) [self triggerSizeChangeAction];
	else [self triggerChangeAction];
}

-(int)frame
{
	return currindex;
}



-(NSRect)updatedAreaInRect:(NSRect)rect
{
	XeeImage *curr=[self currentSubImage];
	if(curr) return [curr updatedAreaInRect:rect];
	else return [super updatedAreaInRect:rect];
}

-(void)drawInRect:(NSRect)rect bounds:(NSRect)bounds lowQuality:(BOOL)lowquality
{
	[[self currentSubImage] drawInRect:rect bounds:bounds lowQuality:lowquality];
}



-(CGImageRef)makeCGImage
{
	XeeImage *curr=[self currentSubImage];
	if(curr) return [curr makeCGImage];
	else return [super makeCGImage];
}



-(int)losslessFlags
{
	XeeImage *curr=[self currentSubImage];
	if(curr) return [curr losslessFlags];
	else return [super losslessFlags];
}

-(BOOL)losslessSaveTo:(NSString *)destination flags:(int)flags
{
	XeeImage *curr=[self currentSubImage];
	if(curr) return [curr losslessSaveTo:destination flags:flags];
	else return [super losslessSaveTo:destination flags:flags];
}



-(int)width
{
	XeeImage *curr=[self currentSubImage];
	if(curr) return [curr width];
	else return [super width];
}

-(int)height
{
	XeeImage *curr=[self currentSubImage];
	if(curr) return [curr height];
	else return [super height];
}

-(int)fullWidth
{
	XeeImage *curr=[self currentSubImage];
	if(curr) return [curr fullWidth];
	else return [super fullWidth];
}

-(int)fullHeight
{
	XeeImage *curr=[self currentSubImage];
	if(curr) return [curr fullHeight];
	else return [super fullHeight];
}

-(NSString *)depth
{
	XeeImage *curr=[self currentSubImage];
	if(curr) return [curr depth];
	else return [super depth];
}

-(NSImage *)depthIcon
{
	XeeImage *curr=[self currentSubImage];
	if(curr) return [curr depthIcon];
	else return [super depthIcon];
}

-(BOOL)transparent
{
	XeeImage *curr=[self currentSubImage];
	if(curr) return [curr transparent];
	else return [super transparent];
}

-(NSColor *)backgroundColor
{
	XeeImage *curr=[self currentSubImage];
	if(curr) return [curr backgroundColor];
	else return [super backgroundColor];
}

-(NSRect)croppingRect
{
	XeeImage *curr=[self currentSubImage];
	if(curr) return [curr croppingRect];
	else return [super croppingRect];
}

-(XeeTransformation)orientation
{
	XeeImage *curr=[self currentSubImage];
	if(curr) return [curr orientation];
	else return [super orientation];
}



-(void)setOrientation:(XeeTransformation)trans
{
	XeeImage *curr=[self currentSubImage];
	if(curr) return [curr setOrientation:trans];
	else return [super setOrientation:trans];
}

-(void)setCroppingRect:(NSRect)rect
{
	XeeImage *curr=[self currentSubImage];
	if(curr) [curr setCroppingRect:rect];
}

-(void)resetTransformations
{
	NSEnumerator *enumerator=[subimages objectEnumerator];
	XeeImage *subimage;
	while(subimage=[enumerator nextObject]) [subimage resetTransformations];
}

@end
