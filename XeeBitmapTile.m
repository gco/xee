#import "XeeBitmapTile.h"



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
	glPixelStorei(GL_UNPACK_SKIP_ROWS,y);

//	if(XeeSpanLength(completed)==height) glTexParameteri(textarget,GL_TEXTURE_STORAGE_HINT_APPLE,GL_STORAGE_CACHED_APPLE);
//	else glTexParameteri(textarget,GL_TEXTURE_STORAGE_HINT_APPLE,GL_STORAGE_SHARED_APPLE);

//	glTexParameteri(textarget,GL_TEXTURE_STORAGE_HINT_APPLE,GL_STORAGE_SHARED_APPLE); // slow
	glTexParameteri(textarget,GL_TEXTURE_STORAGE_HINT_APPLE,GL_STORAGE_CACHED_APPLE);

	if(!created)
	{
		glTexImage2D(textarget,0,texintformat,realwidth,height,0,texformat,textype,data);
		created=YES;
	}
	else if(!XeeSpanEmpty(upload))
	{
		glTexSubImage2D(textarget,0,0,0,realwidth,XeeSpanStart(upload)+XeeSpanLength(upload),texformat,textype,data);
	}

	uploaded=completed;
}

-(void)invalidate { uploaded=XeeEmptySpan; }

-(void)drawWithBounds:(NSRect)bounds minFilter:(GLuint)minfilter magFilter:(GLuint)magfilter 
{
	if(!tex||!created) return;
	if(!NSIntersectsRect(NSMakeRect(x,y,width,height),bounds)) return;

	glBindTexture(textarget,tex);
	glTexParameteri(textarget,GL_TEXTURE_MIN_FILTER,minfilter);
	glTexParameteri(textarget,GL_TEXTURE_MAG_FILTER,magfilter);

	glCallList(lists);
}

-(void)drawMultipleWithBounds:(NSRect)bounds minFilter:(GLuint)minfilter magFilter:(GLuint)magfilter num:(int)num
{
	if(!tex||!created) return;
	if(!NSIntersectsRect(NSMakeRect(x,y,width,height),bounds)) return;

	for(int i=0;i<num;i++)
	{
		glActiveTexture(GL_TEXTURE0+i);
		glBindTexture(textarget,tex);
		glTexParameteri(textarget,GL_TEXTURE_MIN_FILTER,minfilter);
		glTexParameteri(textarget,GL_TEXTURE_MAG_FILTER,magfilter);
	}

	glCallList(lists+1);
}

@end
