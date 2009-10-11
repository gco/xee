#import "XeeTileImage.h"



GLuint XeeMakeGridTexture(float r,float b,float g);
size_t XeeTileImageGetBytes(void *infoptr,void *buffer,size_t count);
void XeeTileImageSkipBytes(void *infoptr,size_t count);
void XeeTileImageRewind(void *infoptr);
void XeeTileImageReleaseInfo(void *infoptr);

struct XeeTileImageProviderInfo
{
	XeeReadPixelFunction readpixel;
	size_t pos;

	uint8_t *data;
	int bytesperrow;
	int pixelsize,width;

	int a00,a01,a02;
	int a10,a11,a12;

	XeeTileImage *image;
};



@implementation XeeTileImage

-(id)init
{
	if(self=[super init])
	{
		data=NULL;
		bytesperpixel=bytesperrow=0;
		freedata=NO;
		premultiplied=NO;
		texintformat=texformat=textype=0;

		completed=uploaded=drawn=XeeEmptySpan;

		textarget=0;
		tiles=nil;
		needsupdate=NO;
		context=nil;
	}

	return self;
}

-(void)dealloc
{
	if(freedata) free(data);

	[context makeCurrentContext];
	[tiles release];
	[context release];

	[super dealloc];
}


-(void)setData:(uint8_t *)pixeldata freeData:(BOOL)willfree width:(int)pixelwidth height:(int)pixelheight
bytesPerPixel:(int)bppixel bytesPerRow:(int)bprow premultiplied:(BOOL)premult
glInternalFormat:(int)glintformat glFormat:(int)glformat glType:(int)gltype
{
	// Free old data
	if(freedata) free(data);

	// Set parameters
	data=pixeldata;
	freedata=willfree;
	premultiplied=premult;
	width=pixelwidth;
	height=pixelheight;
	bytesperpixel=bppixel;
	bytesperrow=bprow;
	texintformat=glintformat;
	texformat=glformat;
	textype=gltype;

	// Reset everything
	completed=uploaded=drawn=XeeEmptySpan;
	[tiles release];
	tiles=nil;
}



-(void)setCompleted { [self setFirstCompletedRow:0 count:height]; }

-(void)setCompletedRowCount:(int)count { [self setFirstCompletedRow:XeeSpanStart(completed) count:count]; }

-(void)setFirstCompletedRow:(int)first count:(int)count
{
	completed=XeeSpanIntersection(XeeMakeSpan(first,count),XeeMakeSpan(0,height));

	if(XeeSpanLength(completed)==height)
	{
		[self triggerChangeAction];
	}
	else
	{
//		static double prevtime=0;
//		double time=XeeGetTime();
		int delta=height/32;
		if(delta<8) delta=8;

		if(XeeSpanLength(completed)-XeeSpanLength(uploaded)>=delta) [self triggerLoadingAction];
//		if(time-prevtime>=0.1) [self triggerLoadingAction];
//prevtime=time;
	}
}

-(void)invalidate
{
	needsupdate=YES;

	NSEnumerator *enumerator=[tiles objectEnumerator];
	XeeBitmapTile *tile;
	while(tile=[enumerator nextObject]) [tile invalidate];

	[self triggerChangeAction];
}



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
		XeeSpan willbedrawn=completed;
		XeeSpan updated=XeeSpanDifference(drawn,willbedrawn);
		drawn=willbedrawn;

		XeeMatrix m=[self transformationMatrixInRect:rect];
		NSRect rect=XeeTransformRect(m,NSMakeRect(0,XeeSpanStart(updated),width,XeeSpanLength(updated)));

		return NSIntegralRect(rect);
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

	if(needsupdate||!XeeSpansIdentical(completed,uploaded))
	{
		needsupdate=NO;
		[self uploadTextures];
	}

	XeeMatrix m=[self transformationMatrixInRect:rect];
	XeeMatrix inv=XeeInverseMatrix(m);

	NSRect transbounds=XeeTransformRect(inv,bounds);

	glPushMatrix();
	XeeGLMultMatrix(m);

	float x_scale=rect.size.width/(float)[self width];
	float y_scale=rect.size.height/(float)[self height];

	if((x_scale<1||y_scale<1)&&textarget==GL_TEXTURE_RECTANGLE_EXT&&XeeSpanLength(uploaded)==height&&!lowquality)
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
		int back_w=rect.size.width;
		int back_h=rect.size.height;
		//int back_w=MIN(bounds.size.width,rect.size.width);
		//int back_h=MIN(bounds.size.height,rect.size.height);

		if(premultiplied) glBlendFunc(GL_ONE_MINUS_DST_ALPHA,GL_ONE);
		else glBlendFunc(GL_ONE_MINUS_DST_ALPHA,GL_DST_ALPHA);
		glEnable(GL_BLEND);

		glEnable(GL_TEXTURE_2D);

		glPushMatrix();
		glTranslatef(back_x,back_y,0);

		glMatrixMode(GL_TEXTURE);
		glPushMatrix();
		GLfloat rot[]={1,1,0,0,1,-1,0,0,0,0,1,0,0,0,0,1};
		glLoadMatrixf(rot);
		glScalef(1.0/31.0,1.0/31.0,1.0/31.0);

		glBegin(GL_QUADS);
		glTexCoord2f(0,0);
		glVertex2f(0,0);
		glTexCoord2f(back_w,0);
		glVertex2f(back_w,0);
		glTexCoord2f(back_w,back_h);
		glVertex2f(back_w,+back_h);
		glTexCoord2f(0,back_h);
		glVertex2f(0,back_h);
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

	glPixelStorei(GL_UNPACK_ROW_LENGTH,bytesperrow/bytesperpixel);
	glPixelStorei(GL_UNPACK_ALIGNMENT,align);

	if(textarget==GL_TEXTURE_2D&&(texformat==GL_LUMINANCE||texformat==GL_YCBCR_422_APPLE)) // workaround for buggy Rage128 drivers
	glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE,GL_FALSE);
	else glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE,GL_TRUE);

	uploaded=completed; // sync issues with bottom-loading images, but should not cause any problems

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
	while(tile=[enumerator nextObject]) [tile drawWithBounds:transbounds minFilter:GL_LINEAR magFilter:[self magFilter]];

	glDisable(textarget);

}

-(void)drawSampleSet:(XeeSampleSet *)set xScale:(float)x_scale yScale:(float)y_scale bounds:(NSRect)transbounds
{
	int num=[set count];
	XeeSamplePoint *samples=[set samples];

	GLint textureunits;
	glGetIntegerv(GL_MAX_TEXTURE_UNITS_ARB,&textureunits);

	// This is the worst line of code in the entire world.
	if(textureunits==8&&!strcmp((char *)glGetString(GL_RENDERER),"Intel GMA 950 OpenGL Engine"))
	textureunits=7;

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
	while(tile=[enumerator nextObject]) [tile drawWithBounds:transbounds minFilter:GL_NEAREST magFilter:[self magFilter]];

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
	while(tile=[enumerator nextObject]) [tile drawMultipleWithBounds:transbounds minFilter:GL_NEAREST magFilter:[self magFilter] num:num];

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

-(GLuint)magFilter
{
	if(![[NSUserDefaults standardUserDefaults] boolForKey:@"upsampleImage"]) return GL_NEAREST;
	else return GL_LINEAR;
}

-(int)bytesPerRow { return bytesperrow; }

-(uint8_t *)data { return data; }



-(CGImageRef)createCGImage
{
	CGImageRef cgimage=NULL;

	XeeReadPixelFunction readpixel=[self readPixelFunctionForCGImage];
	if(!readpixel) return NULL;

	struct XeeTileImageProviderInfo *info=malloc(sizeof(struct XeeTileImageProviderInfo));
	if(info)
	{
		int pixelsize=[self bytesPerPixelForCGImage];
		XeeMatrix m=XeeInverseMatrix([self transformationMatrix]);

		info->readpixel=readpixel;
		info->pos=0;
		info->data=data;
		info->bytesperrow=bytesperrow;
		info->pixelsize=pixelsize;
		info->width=[self width];
		info->a00=(int)m.a00;
		info->a01=(int)m.a01;
		info->a02=(int)(m.a02+(m.a00+m.a01)/4.0);
		info->a10=(int)m.a10;
		info->a11=(int)m.a11;
		info->a12=(int)(m.a12+(m.a10+m.a11)/4.0);
		info->image=self;

		CGDataProviderCallbacks callbacks=
		{ XeeTileImageGetBytes,XeeTileImageSkipBytes,XeeTileImageRewind,XeeTileImageReleaseInfo };

		CGDataProviderRef provider=CGDataProviderCreate(info,&callbacks);

		if(provider)
		{
			[self retain];

			CGColorSpaceRef colorspace=[self createColorSpaceForCGImage];
			if(colorspace)
			{
				cgimage=CGImageCreate([self width],[self height],[self bitsPerComponentForCGImage],
				pixelsize*8,pixelsize*[self width],colorspace,[self bitmapInfoForCGImage],
				provider,NULL,NO,kCGRenderingIntentDefault);

				CGColorSpaceRelease(colorspace);
			}
			CGDataProviderRelease(provider);
		}
		else free(info);
	}

	return cgimage;
}

-(int)bitsPerComponentForCGImage { return 0; }
-(int)bytesPerPixelForCGImage { return 0; }
-(CGColorSpaceRef)createColorSpaceForCGImage { return NULL; }
-(int)bitmapInfoForCGImage { return 0; }
-(XeeReadPixelFunction)readPixelFunctionForCGImage { return NULL; }


@end


size_t XeeTileImageGetBytes(void *infoptr,void *buffer,size_t count)
{
	struct XeeTileImageProviderInfo *info=(struct XeeTileImageProviderInfo *)infoptr;
	uint8_t pixel[info->pixelsize];
	uint8_t *dest=buffer;
	size_t end=info->pos+count;

	int pixelnum=info->pos/info->pixelsize;
	int offs=info->pos%info->pixelsize;

	while(info->pos<end)
	{
		int dx=pixelnum%info->width;
		int dy=pixelnum/info->width;
		int sx=info->a00*dx+info->a01*dy+info->a02;
		int sy=info->a10*dx+info->a11*dy+info->a12;
		uint8_t *row=info->data+sy*info->bytesperrow;
		int left=end-info->pos;

		if(offs==0&&left>=info->pixelsize) // read full pixel directly
		{
			info->readpixel(row,sx,info->pixelsize,dest);
			info->pos+=info->pixelsize;
			dest+=info->pixelsize;
		}
		else // read partial pixel
		{
			info->readpixel(row,sx,info->pixelsize,pixel);

			int bytes=info->pixelsize-offs;
			if(bytes>left) bytes=left;

			memcpy(dest,pixel+offs,bytes);
			info->pos+=bytes;
			dest+=bytes;

			offs=0;
		}

		pixelnum++;
	}

	return count;
}

void XeeTileImageSkipBytes(void *infoptr,size_t count)
{
	struct XeeTileImageProviderInfo *info=(struct XeeTileImageProviderInfo *)infoptr;
	info->pos+=count;
}

void XeeTileImageRewind(void *infoptr)
{
	struct XeeTileImageProviderInfo *info=(struct XeeTileImageProviderInfo *)infoptr;
	info->pos=0;
}

void XeeTileImageReleaseInfo(void *infoptr)
{
	struct XeeTileImageProviderInfo *info=(struct XeeTileImageProviderInfo *)infoptr;
	[info->image release];
	free(info);
}



GLuint XeeMakeGridTexture(float r,float g,float b)
{
	float r_low=r*0.9,g_low=g*0.9,b_low=b*0.9;
	float r_high=r_low+0.1,g_high=g_low+0.1,b_high=b_low+0.1;
	int r1=(int)(255.0*r_low),g1=(int)(255.0*g_low),b1=(int)(255.0*b_low);
	int r2=(int)(255.0*r_high),g2=(int)(255.0*g_high),b2=(int)(255.0*b_high);
	uint32_t col1=0xff000000|(r1<<16)|(g1<<8)|b1;
	uint32_t col2=0xff000000|(r2<<16)|(g2<<8)|b2;
	uint32_t data[]={col1,col2,col2,col1};

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
