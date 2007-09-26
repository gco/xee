#include "XeeTypes.h"

#import <OpenGL/GL.h>
#import <OpenGL/GLu.h>

@interface XeeBitmapTile:NSObject
{
	int x,y,width,height;

	GLuint tex,textarget,texintformat,textype,texformat;
	int realwidth;
	void *data;

	BOOL created;
	XeeSpan uploaded;

	GLuint lists;
}

-(id)initWithTarget:(GLuint)tt internalFormat:(GLuint)tif
	x:(int)x y:(int)y width:(int)width height:(int)height
	format:(GLuint)tf type:(GLuint)tt data:(void *)d;
-(void)dealloc;

-(void)uploadWithCompletedSpan:(XeeSpan)global_completed;
-(void)invalidate;

-(void)drawWithBounds:(NSRect)bounds minFilter:(GLuint)minfilter magFilter:(GLuint)magfilter;
-(void)drawMultipleWithBounds:(NSRect)bounds minFilter:(GLuint)minfilter magFilter:(GLuint)magfilter num:(int)num;

@end
