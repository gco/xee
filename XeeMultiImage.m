#import "XeeMultiImage.h"



@implementation XeeMultiImage

-(id)init
{
	if(self=[super init])
	{
		currindex=0;
		subimages=[[NSMutableArray array] retain];
		if(subimages) return self;

		[self release];
	}

	return nil;
}

-(void)dealloc
{
	[subimages release];

	[super dealloc];
}



-(void)addSubImage:(XeeImage *)subimage
{
	//[subimage setFilename:filename];
	[subimages addObject:subimage];
	[subimage setDelegate:self];
}

-(void)addSubImages:(NSArray *)array
{
	NSEnumerator *enumerator=[array objectEnumerator];
	XeeImage *image;
	while(image=[enumerator nextObject]) [self addSubImage:image];
}

-(XeeImage *)currentSubImage
{
	if([subimages count]==0) return nil;
	else return [subimages objectAtIndex:currindex];
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



-(int)frames { return [subimages count]; }

-(void)setFrame:(int)frame
{
	if([subimages count]==0) return;

	if(frame<0) frame=0;
	if(frame>=[subimages count]) frame=[subimages count]-1;
	if(frame==currindex) return;

	int oldwidth=[self width];
	int oldheight=[self height];

	currindex=frame;

	if(oldwidth!=[self width]||oldheight!=[self height]) [self triggerSizeChangeAction];
	else [self triggerChangeAction];

	[self triggerPropertyChangeAction];
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



-(CGImageRef)createCGImage { return [[self currentSubImage] createCGImage]; }

-(int)losslessSaveFlags { return [[self currentSubImage] losslessSaveFlags]; }

-(BOOL)losslessSaveTo:(NSString *)path flags:(int)flags { return [[self currentSubImage] losslessSaveTo:path flags:flags]; }



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
	if(curr) return [curr setCroppingRect:rect];
	else return [super setCroppingRect:rect];
}

-(void)resetTransformations
{
	NSEnumerator *enumerator=[subimages objectEnumerator];
	XeeImage *subimage;
	while(subimage=[enumerator nextObject]) [subimage resetTransformations];
}

@end
