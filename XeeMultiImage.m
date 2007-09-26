#import "XeeMultiImage.h"



@implementation XeeMultiImage

-(id)init
{
	if(self=[super init])
	{
		subimages=[[NSMutableArray array] retain];
		currindex=0;
		currloading=nil;

		if(subimages) return self;

		[self release];
	}

	return nil;
}

-(void)dealloc
{
	[subimages release];
	[currloading release];

	[super dealloc];
}



-(void)addSubImage:(XeeImage *)subimage
{
	//[subimage setFilename:filename];
	[subimages addObject:subimage];
	[subimage setDelegate:self];
	if(correctorientation) [subimage setCorrectOrientation:correctorientation];
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



/*-(BOOL)loaded;
-(BOOL)failed;*/

-(BOOL)needsLoading
{
	// check subimages here
	return [super needsLoading];
}

-(void)stopLoading
{
	// order?
	if(currloading) [currloading stopLoading];
	[super stopLoading];
}

-(void)runLoaderOnSubImage:(XeeImage *)image
{
	currloading=[image retain];

	while([currloading needsLoading])
	{
		[currloading runLoader];
		XeeImageLoaderYield();
	}

	[currloading autorelease];
	currloading=nil;
}

-(int)frames
{
	NSEnumerator *enumerator=[subimages objectEnumerator];
	XeeImage *image;
	int frames=0;
	while(image=[enumerator nextObject]) frames+=[image frames];
	return frames;
}

-(void)setFrame:(int)frame
{
	if([subimages count]==0) return;

	if(frame<0) frame=0;
	if(frame==[self frame]) return;

	int count=[subimages count];
	int newindex,prevframes=0;
	for(newindex=0;newindex<count-1;newindex++)
	{
		int frames=[[subimages objectAtIndex:newindex] frames];
		if(prevframes+frames>frame) break;
		else prevframes+=frames;
	}

	XeeImage *subimage=[subimages objectAtIndex:newindex];
	int frames=[subimage frames];
	int subframe=frame-prevframes;
	if(subframe>=frames) subframe=frames-1;

	int oldwidth=[self width];
	int oldheight=[self height];

	currindex=newindex;
	[subimage setDelegate:nil];
	[subimage setFrame:subframe];
	[subimage setDelegate:self];

	if(oldwidth!=[self width]||oldheight!=[self height]) [self triggerSizeChangeAction];
	else [self triggerChangeAction];

	[self triggerPropertyChangeAction];
}

-(int)frame
{
	int prevframes=0;
	for(int i=0;i<currindex;i++) prevframes+=[[subimages objectAtIndex:i] frames];
	return prevframes+[(XeeImage *)[subimages objectAtIndex:currindex] frame];
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

-(NSString *)losslessFormat { return [[self currentSubImage] losslessFormat]; }

-(NSString *)losslessExtension { return [[self currentSubImage] losslessExtension]; }

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
	NSString *currdepth=[curr depth];
	if(currdepth) return currdepth;
	else return [super depth];
}

-(NSImage *)depthIcon
{
	XeeImage *curr=[self currentSubImage];
	NSImage *currdepthicon=[curr depthIcon];
	if(currdepthicon) return currdepthicon;
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
	NSColor *background=[curr backgroundColor];
	if(background) return background;
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

-(XeeTransformation)correctOrientation
{
	XeeImage *curr=[self currentSubImage];
	if(curr) return [curr correctOrientation];
	else return [super correctOrientation];
}

-(NSArray *)properties
{
	XeeImage *curr=[self currentSubImage];
	NSArray *subproperties=[curr properties];

	if(subproperties)
	{
		NSMutableArray *array=[NSMutableArray arrayWithArray:subproperties];
		[array addObjectsFromArray:[super properties]];
		return array;
	}
	else return [super properties];
}

-(void)setOrientation:(XeeTransformation)trans
{
	XeeImage *curr=[self currentSubImage];
	if(curr) return [curr setOrientation:trans];
	else return [super setOrientation:trans];
}

-(void)setCorrectOrientation:(XeeTransformation)trans
{
	NSEnumerator *enumerator=[subimages objectEnumerator];
	XeeImage *subimage;
	while(subimage=[enumerator nextObject]) [subimage setCorrectOrientation:trans];
	[super setCorrectOrientation:trans];
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
