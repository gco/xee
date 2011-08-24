#import "XeeBitmapImage.h"
#import "XeeMisc.h"



struct XeeTileImageProviderInfo
{
	size_t offs;

	void *data;
	int bytesperrow;

	XeeTransformationMatrix mtx;
	XeePixelAccessFunc readpixel;
	void *context;

	int destwidth,destheight;
	int bytesperpixel;
};

static size_t XeeTileImageGetBytes(void *infoptr,void *buffer,size_t count);
static void XeeTileImageSkipBytes(void *infoptr,size_t count);
static void XeeTileImageRewind(void *infoptr);
static void XeeTileImageRelease(void *infoptr);

static GLuint XeeMakeGridTexture(float r,float b,float g);



@implementation XeeTileImage

-(id)init
{
	if(self=[super init]) [self _initTileImage];

	return self;
}

-(id)initWithFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes
{
	if(self=[super initWithFile:name firstBlock:block attributes:attributes]) [self _initTileImage];

	return self;
}

-(void)_initTileImage
{
	data=NULL;

	bytesperrow=0;
	pixelsize=0;
	premultiplied=NO;

	textarget=texintformat=texformat=textype=0;

	completed=uploaded=drawn=XeeEmptySpan;

	tiles=nil;
	needsupdate=NO;
	context=nil;
}

-(void)dealloc
{
	[context makeCurrentContext];
	[tiles release];
	[context release];

	[super dealloc];
}



-(void)setCompleted { [self setFirstCompletedRow:0 count:height]; }

-(void)setCompletedRowCount:(int)count { [self setFirstCompletedRow:XeeSpanStart(completed) count:count]; }

-(void)setFirstCompletedRow:(int)first count:(int)count
{
	completed=XeeMakeSpan(first,count);

//	static double prevtime=0;
//	double time=XeeGetTime();
	int delta=height/32;
	if(delta<8) delta=8;
//delta=32;
	if(XeeSpanLength(completed)-XeeSpanLength(uploaded)>=delta) [self triggerLoadingAction];
//	if(time-prevtime>=0.1) [self triggerLoadingAction];
//prevtime=time;
}

-(void)invalidate
{
	needsupdate=YES;

	NSEnumerator *enumerator=[tiles objectEnumerator];
	XeeBitmapTile *tile;
	while(tile=[enumerator nextObject]) [tile invalidate];

	[self triggerChangeAction];
}

-(XeeSpan)completedSpan { return success?XeeMakeSpan(0,height):completed; }



-(NSRect)updatedAreaInRect:(NSRect)rect
{
	if(needsupdate)
	{
		drawn=XeeMakeSpan(0,height);
		return rect;
	}
	else if(XeeSpanLength(drawn)==height)
	{
		return NSMakeRect(0,0,0,0);
	}
	else
	{
		XeeSpan willbedrawn=[self completedSpan];
		XeeSpan updated=XeeSpanDifference(drawn,willbedrawn);
		drawn=willbedrawn;

		float x_scale=rect.size.width/(float)[self width];
		float y_scale=rect.size.height/(float)[self height];
		XeeTransformationMatrix mtx=[self transformationMatrix];
		mtx=XeeMultiplyMatrices(XeeScalingMatrix(x_scale,y_scale),mtx);
		mtx=XeeMultiplyMatrices(XeeTranslationMatrix(rect.origin.x,rect.origin.y),mtx);
// FIXME: clip cropping!

		return NSIntegralRect(XeeTransformRectWithMatrix(mtx,NSMakeRect(0,XeeSpanStart(updated),width,(float)XeeSpanLength(updated))));

/*		return NSMakeRect(
			floor(rect.origin.x),
			floor((float)XeeSpanStart(updated)*y_scale)+floor(rect.origin.y),
			floor((float)width*x_scale+1),
			floor((float)XeeSpanLength(updated)*y_scale+1)
		);*/
	}
}

-(void)drawInRect:(NSRect)rect bounds:(NSRect)bounds lowQuality:(BOOL)lowquality
{
	if(!data) return;

	if(!tiles)
	{
		context=[[NSOpenGLContext currentContext] retain];

		if(![[NSUserDefaults standardUserDefaults] boolForKey:@"force2D"]&&
		gluCheckExtension((unsigned char *)"GL_EXT_texture_rectangle",glGetString(GL_EXTENSIONS)))
		[self allocTexturesRect];
		else
		[self allocTextures2D];

		needsupdate=YES;
	}

	if(needsupdate||!XeeSpansIdentical([self completedSpan],uploaded))
	{
		needsupdate=NO;
		[self uploadTextures];
	}

	float x_scale=rect.size.width/(float)[self width];
	float y_scale=rect.size.height/(float)[self height];
	XeeTransformationMatrix mtx=[self transformationMatrix];
	mtx=XeeMultiplyMatrices(XeeScalingMatrix(x_scale,y_scale),mtx);
	mtx=XeeMultiplyMatrices(XeeTranslationMatrix(rect.origin.x,rect.origin.y),mtx);

	NSRect transbounds=XeeTransformRectWithMatrix(XeeInverseMatrix(mtx),bounds);

	glPushMatrix();
	XeeGLMultMatrix(mtx);

	if(x_scale<1&&textarget==GL_TEXTURE_RECTANGLE_EXT&&XeeSpanLength(uploaded)==height&&!lowquality)
	{
		XeeSampleSet *set=nil;
		switch([[NSUserDefaults standardUserDefaults] integerForKey:@"antialiasQuality"])
		{
			case 1: set=[XeeSampleSet sampleSetWithCount:4 distribution:@"bestCandidate" filter:@"box"]; break;
			case 2: set=[XeeSampleSet sampleSetWithCount:12 distribution:@"bestCandidate" filter:@"box"]; break;
			case 3: set=[XeeSampleSet sampleSetWithCount:32 distribution:@"bestCandidate" filter:@"box"]; break;
			case 4: set=[XeeSampleSet sampleSetWithCount:4 distribution:@"bestCandidate" filter:@"sinc"]; break;
			case 5: set=[XeeSampleSet sampleSetWithCount:12 distribution:@"bestCandidate" filter:@"sinc"]; break;
			case 6: set=[XeeSampleSet sampleSetWithCount:32 distribution:@"bestCandidate" filter:@"sinc"]; break;
		}

		if(set) [self drawSampleSet:set xScale:x_scale yScale:y_scale bounds:transbounds];
		else [self drawNormalWithBounds:transbounds];
	}
	else
	{
		[self drawNormalWithBounds:transbounds];
	}

	glPopMatrix();

	if(transparent)
	{
		NSColor *rgbback=[[self backgroundColor] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
		float r=[rgbback redComponent],g=[rgbback greenComponent],b=[rgbback blueComponent];
		GLuint tex=XeeMakeGridTexture(r,g,b);

		int back_x=rect.origin.x>0?rect.origin.x:0;
		int back_y=rect.origin.y>0?rect.origin.y:0;
//		int back_w=MIN(bounds.size.width,rect.size.width);
//		int back_h=MIN(bounds.size.height,rect.size.height);

		if(premultiplied) glBlendFunc(GL_ONE_MINUS_DST_ALPHA,GL_ONE);
		else glBlendFunc(GL_ONE_MINUS_DST_ALPHA,GL_DST_ALPHA);
		glEnable(GL_BLEND);

		glEnable(GL_TEXTURE_2D);

		NSRect area=rect;

		glPushMatrix();
		//glTranslatef(back_x,back_y,0);
		glTranslatef(area.origin.x,area.origin.y,0);
		glScalef(area.size.width,area.size.height,0);

		glMatrixMode(GL_TEXTURE);
		glPushMatrix();
		GLfloat rot[]={1,1,0,0,1,-1,0,0,0,0,1,0,0,0,0,1};
		glLoadMatrixf(rot);
		glScalef(1.0/31.0,1.0/31.0,1.0/31.0);
		glTranslatef(area.origin.x-back_x,area.origin.y-back_y,0);
		glScalef(area.size.width,area.size.height,0);

		glBegin(GL_QUADS);
		glTexCoord2f(0,0);
		glVertex2f(0,0);
		glTexCoord2f(1,0);
		glVertex2f(1,0);
		glTexCoord2f(1,1);
		glVertex2f(1,1);
		glTexCoord2f(0,1);
		glVertex2f(0,1);
		glEnd();

		glPopMatrix();

		glMatrixMode(GL_MODELVIEW);
		glPopMatrix();

		glDisable(GL_TEXTURE_2D);

		glDeleteTextures(1,&tex);
	}
}

-(void)allocTexturesRect
{
	textarget=GL_TEXTURE_RECTANGLE_EXT;

	GLint maxtilesize;
	glGetIntegerv(GL_MAX_RECTANGLE_TEXTURE_SIZE_EXT,&maxtilesize);
	if(maxtilesize>512) maxtilesize=512;

	int cols=(width+maxtilesize-1)/maxtilesize;
	int rows=(height+maxtilesize-1)/maxtilesize;

	tiles=[[NSMutableArray alloc] initWithCapacity:rows*cols];

	if(tiles)
	{
		for(int row=0;row<rows;row++)
		{
			int tile_h=(row==rows-1)?(height-(rows-1)*maxtilesize):maxtilesize;

			for(int col=0;col<cols;col++)
			{
				int tile_w=(col==cols-1)?(width-(cols-1)*maxtilesize):maxtilesize;

				XeeBitmapTile *tile=[[[XeeBitmapTile alloc] initWithTarget:textarget
				internalFormat:texintformat x:col*maxtilesize y:row*maxtilesize
				width:tile_w height:tile_h format:texformat type:textype data:data] autorelease];
				if(tile) [tiles addObject:tile];
			}
		}
	}
}

-(void)allocTextures2D
{
	textarget=GL_TEXTURE_2D;

	GLint maxtilesize;
	glGetIntegerv(GL_MAX_TEXTURE_SIZE,&maxtilesize);
	if(maxtilesize>512) maxtilesize=512;

	int colsize,rowsize;
	int x,y;

	tiles=[[NSMutableArray alloc] initWithCapacity:32];

	if(tiles)
	{
		rowsize=maxtilesize;
		y=0;
		while(y<height)
		{
			while(y+rowsize>height) rowsize/=2;

			colsize=maxtilesize;
			x=0;
			while(x<width)
			{
				while(x+colsize>width) colsize/=2;

				XeeBitmapTile *tile=[[[XeeBitmapTile alloc] initWithTarget:textarget
				internalFormat:texintformat x:x y:y width:colsize height:rowsize
				format:texformat type:textype data:data] autorelease];
				if(tile) [tiles addObject:tile];

				x+=colsize;
			}

			y+=rowsize;
		}
	}
}

-(void)uploadTextures
{
	int align;
	if((bytesperrow&7)==0) align=8;
	else if((bytesperrow&3)==0) align=4;
	else if((bytesperrow&1)==0) align=2;
	else align=1;

	glPixelStorei(GL_UNPACK_ROW_LENGTH,bytesperrow/pixelsize);
	glPixelStorei(GL_UNPACK_ALIGNMENT,align);

	if(textarget==GL_TEXTURE_2D&&(texformat==GL_LUMINANCE||texformat==GL_YCBCR_422_APPLE)) // workaround for buggy Rage128 drivers
	glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE,GL_FALSE);
	else glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE,GL_TRUE);

	uploaded=[self completedSpan]; // sync issues with bottom-loading images, but should not cause any problems

	NSEnumerator *enumerator=[tiles objectEnumerator];
	XeeBitmapTile *tile;
	while(tile=[enumerator nextObject]) [tile uploadWithCompletedSpan:uploaded];
}

-(void)drawNormalWithBounds:(NSRect)transbounds
{
	glDisable(GL_BLEND);
	glEnable(textarget);
	glTexEnvi(GL_TEXTURE_ENV,GL_TEXTURE_ENV_MODE,GL_REPLACE);

	NSEnumerator *enumerator=[tiles objectEnumerator];
	XeeBitmapTile *tile;
	while(tile=[enumerator nextObject]) [tile drawWithBounds:transbounds minFilter:GL_LINEAR];

	glDisable(textarget);

}

-(void)drawSampleSet:(XeeSampleSet *)set xScale:(float)x_scale yScale:(float)y_scale bounds:(NSRect)transbounds
{
	int num=[set count];
	XeeSamplePoint *samples=[set samples];

	GLint textureunits;
	glGetIntegerv(GL_MAX_TEXTURE_UNITS_ARB,&textureunits);

	glEnable(GL_BLEND);
	glBlendFunc(GL_CONSTANT_ALPHA,GL_ONE_MINUS_CONSTANT_ALPHA);

	if(textureunits==1)
	{
		float totalweight=0;
		for(int i=0;i<num;i++)
		{
			totalweight+=samples[i].weight;
			glBlendColor(0,0,0,samples[i].weight/totalweight);

			[self drawSingleSample:samples[i] xScale:x_scale yScale:y_scale bounds:transbounds];
		}
	}
	else
	{
		float totalweight=0;
		for(int i=0;i<num;i+=textureunits)
		{
			int curr_num=num-i>textureunits?textureunits:num-i;
			float currweight=0;
			for(int j=0;j<curr_num;j++) currweight+=samples[i+j].weight;

			totalweight+=currweight;
			glBlendColor(0,0,0,currweight/totalweight);

			[self drawSamplesOnTextureUnits:samples+i num:curr_num xScale:x_scale yScale:y_scale bounds:transbounds];
		}
	}
}

-(void)drawSingleSample:(XeeSamplePoint)sample xScale:(float)x_scale yScale:(float)y_scale bounds:(NSRect)transbounds
{
	glMatrixMode(GL_TEXTURE);
	glLoadIdentity();
	glTranslatef(sample.u/x_scale,sample.v/y_scale,0);
	glEnable(textarget);
	glTexEnvi(GL_TEXTURE_ENV,GL_TEXTURE_ENV_MODE,GL_REPLACE);
	glMatrixMode(GL_MODELVIEW);

	NSEnumerator *enumerator=[tiles objectEnumerator];
	XeeBitmapTile *tile;
	while(tile=[enumerator nextObject]) [tile drawWithBounds:transbounds minFilter:GL_NEAREST];

	glMatrixMode(GL_TEXTURE);
	glLoadIdentity();
	glDisable(textarget);
	glMatrixMode(GL_MODELVIEW);

}

-(void)drawSamplesOnTextureUnits:(XeeSamplePoint *)samples num:(int)num xScale:(float)x_scale yScale:(float)y_scale bounds:(NSRect)transbounds
{
	glMatrixMode(GL_TEXTURE);

	float totalweight=0;

	for(int i=0;i<num;i++)
	{
		glActiveTexture(GL_TEXTURE0+i);
		glLoadIdentity();
		glTranslatef(samples[i].u/x_scale,samples[i].v/y_scale,0);
		glEnable(textarget);

		totalweight+=samples[i].weight;
		GLfloat constcol[4]={1,1,1,samples[i].weight/totalweight};
		glTexEnvfv(GL_TEXTURE_ENV,GL_TEXTURE_ENV_COLOR,constcol);

		glTexEnvi(GL_TEXTURE_ENV,GL_TEXTURE_ENV_MODE,i==0?GL_REPLACE:GL_COMBINE); // REPLACE is implicit anyway, but maybe this give a speedup?

		glTexEnvi(GL_TEXTURE_ENV,GL_COMBINE_RGB,GL_INTERPOLATE);
		glTexEnvi(GL_TEXTURE_ENV,GL_SOURCE0_RGB,GL_TEXTURE);
		glTexEnvi(GL_TEXTURE_ENV,GL_OPERAND0_RGB,GL_SRC_COLOR);
		glTexEnvi(GL_TEXTURE_ENV,GL_SOURCE1_RGB,GL_PREVIOUS);
		glTexEnvi(GL_TEXTURE_ENV,GL_OPERAND1_RGB,GL_SRC_COLOR);
		glTexEnvi(GL_TEXTURE_ENV,GL_SOURCE2_RGB,GL_CONSTANT);
		glTexEnvi(GL_TEXTURE_ENV,GL_OPERAND2_RGB,GL_SRC_ALPHA);

		glTexEnvi(GL_TEXTURE_ENV,GL_COMBINE_ALPHA,GL_INTERPOLATE);
		glTexEnvi(GL_TEXTURE_ENV,GL_SOURCE0_ALPHA,GL_TEXTURE);
		glTexEnvi(GL_TEXTURE_ENV,GL_OPERAND0_ALPHA,GL_SRC_ALPHA);
		glTexEnvi(GL_TEXTURE_ENV,GL_SOURCE1_ALPHA,GL_PREVIOUS);
		glTexEnvi(GL_TEXTURE_ENV,GL_OPERAND1_ALPHA,GL_SRC_ALPHA);
		glTexEnvi(GL_TEXTURE_ENV,GL_SOURCE2_ALPHA,GL_CONSTANT);
		glTexEnvi(GL_TEXTURE_ENV,GL_OPERAND2_ALPHA,GL_SRC_ALPHA);
	}

	glMatrixMode(GL_MODELVIEW);

	NSEnumerator *enumerator=[tiles objectEnumerator];
	XeeBitmapTile *tile;
	while(tile=[enumerator nextObject]) [tile drawMultipleWithBounds:transbounds minFilter:GL_NEAREST num:num];

	glMatrixMode(GL_TEXTURE);

	for(int i=0;i<num;i++)
	{
		glActiveTexture(GL_TEXTURE0+i);
		glDisable(textarget);
		glLoadIdentity();
	}

	glMatrixMode(GL_MODELVIEW);

	glActiveTexture(GL_TEXTURE0);
}

-(CGImageRef)makeCGImage
{
	int imgwidth=[self width];
	int imgheight=[self height];
	int bitspercomp=[self CGImageBitsPerComponent];
	int bitsperpixel=[self CGImageBitsPerPixel];

	struct XeeTileImageProviderInfo *info=malloc(sizeof(struct XeeTileImageProviderInfo));
	if(!info) return NULL;

	info->offs=0;
	info->data=data;
	info->bytesperrow=bytesperrow;
	info->mtx=XeeInverseMatrix([self transformationMatrix]);
	info->readpixel=[self CGImageReadPixelFunc];
	info->context=[self CGImageReadPixelContext];
	info->destwidth=imgwidth;
	info->destheight=imgheight;
	info->bytesperpixel=bitsperpixel/8;

	CGDataProviderCallbacks callbacks={XeeTileImageGetBytes,XeeTileImageSkipBytes,XeeTileImageRewind,XeeTileImageRelease};
	CGDataProviderRef provider=CGDataProviderCreate(info,&callbacks);

	if(provider)
	{
		CGColorSpaceRef colorspace=[self CGImageCopyColorSpace];
		CGBitmapInfo bitmapinfo=[self CGImageBitmapInfo];

		CGImageRef cgimg=CGImageCreate(imgwidth,imgheight,
		bitspercomp,bitsperpixel,imgwidth*(bitsperpixel/8),
		colorspace,bitmapinfo,provider,NULL,NO,kCGRenderingIntentDefault);

		CGDataProviderRelease(provider);
		CGColorSpaceRelease(colorspace);

		return cgimg;
	}

	return NULL;
}

-(int)CGImageBitsPerComponent { return 0; }

-(int)CGImageBitsPerPixel { return 0; }

-(CGBitmapInfo)CGImageBitmapInfo { return 0; }

-(CGColorSpaceRef)CGImageCopyColorSpace { return NULL; }

-(XeePixelAccessFunc)CGImageReadPixelFunc { return NULL; };

-(void *)CGImageReadPixelContext { return NULL; };



-(int)bytesPerRow { return bytesperrow; }

-(void *)data { return data; }

@end



static size_t XeeTileImageGetBytes(void *infoptr,void *buffer,size_t count)
{
	size_t done=0;
	struct XeeTileImageProviderInfo *info=(struct XeeTileImageProviderInfo *)infoptr;
	int a00=info->mtx.a00,a01=info->mtx.a01,a02=info->mtx.a02; // convert matrix to integers for
	int a10=info->mtx.a10,a11=info->mtx.a11,a12=info->mtx.a12; // faster transforms.
//NSLog(@"getbytes %d %d",(int)info->offs,(int)count);

	while(done<count)
	{
		int sub=info->offs%info->bytesperpixel;
		int n=info->offs/info->bytesperpixel;
		int x=n%info->destwidth;
		int y=n/info->destwidth;
		int sx=x*a00+y*a01+a02;
		int sy=x*a10+y*a11+a12;
		int num;
//NSLog(@"loopgetbytes %d %d %d %d",x,y,sx,sy);

		uint8 *datarow=((uint8 *)info->data)+info->bytesperrow*sy;

		if(sub||info->bytesperpixel-sub>count-done)
		{
			uint8 pixel[info->bytesperpixel];
			info->readpixel(datarow,sx,pixel,info->context);

			num=info->bytesperpixel-sub;
			if(num>count-done) num=count-done;
			memcpy(buffer+done,pixel+sub,num);
		}
		else
		{
			info->readpixel(datarow,sx,buffer+done,info->context);
			num=info->bytesperpixel;
		}

		info->offs+=num;
		done+=num;
	}
//NSLog(@"endgetbytes");

	return count;
}

static void XeeTileImageSkipBytes(void *infoptr,size_t count)
{
	struct XeeTileImageProviderInfo *info=(struct XeeTileImageProviderInfo *)infoptr;
	info->offs+=count;
}

static void XeeTileImageRewind(void *infoptr)
{
	struct XeeTileImageProviderInfo *info=(struct XeeTileImageProviderInfo *)infoptr;
	info->offs=0;
}

static void XeeTileImageRelease(void *infoptr)
{
	free(infoptr);
}



// XeeBitmapTile

@implementation XeeBitmapTile

-(id)initWithTarget:(GLuint)target internalFormat:(GLuint)intformat
	x:(int)x0 y:(int)y0 width:(int)w height:(int)h
	format:(GLuint)format type:(GLuint)type data:(void *)d
{
	if(self=[super init])
	{
		x=x0;
		y=y0;
		width=w;
		height=h;

		textarget=target;
		texintformat=intformat;
		texformat=format;
		textype=type;

		data=d;

		float texwidth,texheight;
		if(textarget==GL_TEXTURE_RECTANGLE_EXT) { texwidth=w; texheight=h; }
		else { texwidth=1; texheight=1; }

		if(texformat==GL_YCBCR_422_APPLE) // fudge odd-width YUV textures
		{
			realwidth=(width+1)&~1;
			if(textarget==GL_TEXTURE_2D&&width==1) texwidth=0.5;
		}
		else realwidth=width;

		created=NO;
		uploaded=XeeEmptySpan;

		GLint textureunits;
		glGetIntegerv(GL_MAX_TEXTURE_UNITS_ARB,&textureunits);

		lists=glGenLists(2);

		glNewList(lists,GL_COMPILE);
		glBegin(GL_QUADS);
		glTexCoord2f(0,texheight);
		glVertex2i(x,y+height);
		glTexCoord2f(texwidth,texheight);
		glVertex2i(x+width,y+height);
		glTexCoord2f(texwidth,0);
		glVertex2i(x+width,y);
		glTexCoord2f(0,0);
		glVertex2i(x,y);
		glEnd();
		glEndList();

		glNewList(lists+1,GL_COMPILE);
		glBegin(GL_QUADS);
		for(int i=0;i<textureunits;i++) glMultiTexCoord2f(GL_TEXTURE0+i,0,texheight);
		glVertex2i(x,y+height);
		for(int i=0;i<textureunits;i++) glMultiTexCoord2f(GL_TEXTURE0+i,texwidth,texheight);
		glVertex2i(x+width,y+height);
		for(int i=0;i<textureunits;i++) glMultiTexCoord2f(GL_TEXTURE0+i,texwidth,0);
		glVertex2i(x+width,y);
		for(int i=0;i<textureunits;i++) glMultiTexCoord2f(GL_TEXTURE0+i,0,0);
		glVertex2i(x,y);
		glEnd();
		glEndList();

		glGenTextures(1,&tex);
		if(tex)
		{
			glBindTexture(textarget,tex);

			glTexParameteri(textarget,GL_TEXTURE_MIN_FILTER,GL_NEAREST);
			glTexParameteri(textarget,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
			glTexParameteri(textarget,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
			glTexParameteri(textarget,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);

			return self;
		}

		[self release];
	}

	return nil;
}

-(void)dealloc
{
	glDeleteTextures(1,&tex);
	glDeleteLists(lists,2);

	[super dealloc];
}

-(void)uploadWithCompletedSpan:(XeeSpan)global_completed
{
	if(XeeSpanLength(uploaded)==height) return; // fully loaded

	XeeSpan completed=XeeSpanIntersection(XeeSpanShifted(global_completed,-y),XeeMakeSpan(0,height));
	if(XeeSpanEmpty(completed)) return; // nothing to load

	XeeSpan upload=XeeSpanDifference(uploaded,completed);

	glBindTexture(textarget,tex);
	glPixelStorei(GL_UNPACK_SKIP_PIXELS,x);
	glPixelStorei(GL_UNPACK_SKIP_ROWS,y+XeeSpanStart(upload));

	if(XeeSpanLength(completed)==height) glTexParameteri(textarget,GL_TEXTURE_STORAGE_HINT_APPLE,GL_STORAGE_CACHED_APPLE);
	else glTexParameteri(textarget,GL_TEXTURE_STORAGE_HINT_APPLE,GL_STORAGE_SHARED_APPLE);

	if(!created)
	{
		glTexImage2D(textarget,0,texintformat,realwidth,height,0,texformat,textype,data);
		created=YES;
	}
	else if(!XeeSpanEmpty(upload))
	{
		glTexSubImage2D(textarget,0,0,XeeSpanStart(upload),realwidth,XeeSpanLength(upload),texformat,textype,data);
	}

	uploaded=completed;
}

-(void)invalidate { uploaded=XeeEmptySpan; }

-(void)drawWithBounds:(NSRect)bounds minFilter:(GLuint)minfilter
{
	if(!tex||!created) return;
	if(!NSIntersectsRect(NSMakeRect(x,y,width,height),bounds)) return;

	glBindTexture(textarget,tex);
	glTexParameteri(textarget,GL_TEXTURE_MIN_FILTER,minfilter);

	glCallList(lists);
}

-(void)drawMultipleWithBounds:(NSRect)bounds minFilter:(GLuint)minfilter num:(int)num
{
	if(!tex||!created) return;
	if(!NSIntersectsRect(NSMakeRect(x,y,width,height),bounds)) return;

	for(int i=0;i<num;i++)
	{
		glActiveTexture(GL_TEXTURE0+i);
		glBindTexture(textarget,tex);
		glTexParameteri(textarget,GL_TEXTURE_MIN_FILTER,minfilter);
	}

	glCallList(lists+1);
}

@end



static GLuint XeeMakeGridTexture(float r,float g,float b)
{
	float r_low=r*0.9,g_low=g*0.9,b_low=b*0.9;
	float r_high=r_low+0.1,g_high=g_low+0.1,b_high=b_low+0.1;
	int r1=(int)(255.0*r_low),g1=(int)(255.0*g_low),b1=(int)(255.0*b_low);
	int r2=(int)(255.0*r_high),g2=(int)(255.0*g_high),b2=(int)(255.0*b_high);
	unsigned long col1=0xff000000|(r1<<16)|(g1<<8)|b1;
	unsigned long col2=0xff000000|(r2<<16)|(g2<<8)|b2;
	unsigned long data[]={col1,col2,col2,col1};

	GLuint tex;
	glGenTextures(1,&tex),
	glBindTexture(GL_TEXTURE_2D,tex);

	glPixelStorei(GL_UNPACK_ROW_LENGTH,2);
	glPixelStorei(GL_UNPACK_ALIGNMENT,1);
	glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE,GL_FALSE);
	glPixelStorei(GL_UNPACK_SKIP_PIXELS,0);
	glPixelStorei(GL_UNPACK_SKIP_ROWS,0);
	glTexImage2D(GL_TEXTURE_2D,0,GL_RGB8,2,2,0,GL_BGRA,GL_UNSIGNED_INT_8_8_8_8_REV,data);

	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_REPEAT);
	glTexEnvf(GL_TEXTURE_ENV,GL_TEXTURE_ENV_MODE,GL_REPLACE);

	return tex;
}
