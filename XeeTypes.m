#import "XeeTypes.h"

#import <Carbon/Carbon.h>
#import <OpenGL/gl.h>
#import <sys/time.h>



//
// Spans
//

XeeSpan XeeSpanUnion(XeeSpan span1,XeeSpan span2)
{
	int start=imin(XeeSpanStart(span1),XeeSpanStart(span2));
	int end=imax(XeeSpanPastEnd(span1),XeeSpanPastEnd(span2));
	return XeeMakeSpan(start,end-start);
}

XeeSpan XeeSpanIntersection(XeeSpan span1,XeeSpan span2)
{
	int start=imax(XeeSpanStart(span1),XeeSpanStart(span2));
	int end=imin(XeeSpanPastEnd(span1),XeeSpanPastEnd(span2));
	if(start<=end) return XeeMakeSpan(start,end-start);
	else return XeeMakeSpan(start,0);
}

XeeSpan XeeSpanDifference(XeeSpan old,XeeSpan new)
{
	BOOL start_in_old=XeeSpanStartsInSpan(new,old);
	BOOL end_in_old=XeeSpanEndsInSpan(new,old);

	if(start_in_old&&end_in_old) return XeeEmptySpan;
	else if(start_in_old) return XeeMakeSpan(XeeSpanPastEnd(old),XeeSpanPastEnd(new)-XeeSpanPastEnd(old));
	else if(end_in_old) return XeeMakeSpan(XeeSpanStart(new),XeeSpanStart(old)-XeeSpanStart(new));
	else return XeeSpanUnion(old,new);
}



//
// Matrices
//

XeeMatrix XeeMultiplyMatrices(XeeMatrix a,XeeMatrix b)
{
	return XeeMakeMatrix(
		a.a00*b.a00+a.a01*b.a10,a.a00*b.a01+a.a01*b.a11,a.a00*b.a02+a.a01*b.a12+a.a02,
		a.a10*b.a00+a.a11*b.a10,a.a10*b.a01+a.a11*b.a11,a.a10*b.a02+a.a11*b.a12+a.a12
	);
}

XeeMatrix XeeInverseMatrix(XeeMatrix m)
{
	float det=m.a00*m.a11-m.a01*m.a10;
	return XeeMakeMatrix(
		 m.a11/det,-m.a01/det,-( m.a11*m.a02-m.a01*m.a12)/det,
		-m.a10/det, m.a00/det,-(-m.a10*m.a02+m.a00*m.a12)/det
	);
}

XeeMatrix XeeTransformRectToRectMatrix(NSRect r1,NSRect r2)
{
	return XeeMultiplyMatrices(XeeMultiplyMatrices(
		XeeTranslationMatrix(r2.origin.x,r2.origin.y),
		XeeScaleMatrix(r2.size.width/r1.size.width,r2.size.height/r1.size.height)),
		XeeTranslationMatrix(-r1.origin.x,-r1.origin.y));
}

NSPoint XeeTransformPoint(XeeMatrix m,NSPoint p)
{
	return NSMakePoint(m.a00*p.x+m.a01*p.y+m.a02,m.a10*p.x+m.a11*p.y+m.a12);
}

NSRect XeeTransformRect(XeeMatrix m,NSRect r)
{
	float x1=m.a00*r.origin.x+m.a01*r.origin.y+m.a02;
	float y1=m.a10*r.origin.x+m.a11*r.origin.y+m.a12;
	float x2=m.a00*(r.origin.x+r.size.width)+m.a01*(r.origin.y+r.size.height)+m.a02;
	float y2=m.a10*(r.origin.x+r.size.width)+m.a11*(r.origin.y+r.size.height)+m.a12;
	return NSMakeRect(fminf(x1,x2),fminf(y1,y2),fabsf(x2-x1),fabsf(y2-y1));
}

void XeeGLLoadMatrix(XeeMatrix m)
{
	float a[16]=
	{
		m.a00,m.a10,0,0,
		m.a01,m.a11,0,0,
		    0,    0,1,0,
		m.a02,m.a12,0,1,
	};
	glLoadMatrixf(a);
}

void XeeGLMultMatrix(XeeMatrix m)
{
	float a[16]=
	{
		m.a00,m.a10,0,0,
		m.a01,m.a11,0,0,
		    0,    0,1,0,
		m.a02,m.a12,0,1,
	};
	glMultMatrixf(a);
}

//
// Transformations
//

XeeTransformation XeeInverseOfTransformation(XeeTransformation trans)
{
	static const XeeTransformation table[9]=
	{
		[XeeUnknownTransformation]=XeeUnknownTransformation,
		[XeeNoTransformation]=XeeNoTransformation,
		[XeeMirrorHorizontalTransformation]=XeeMirrorHorizontalTransformation,
		[XeeRotate180Transformation]=XeeRotate180Transformation,
		[XeeMirrorVerticalTransformation]=XeeMirrorVerticalTransformation,
		[XeeTransposeTransfromation]=XeeTransposeTransfromation,
		[XeeRotateCWTransformation]=XeeRotateCCWTransformation,
		[XeeTransverseTransformation]=XeeTransverseTransformation,
		[XeeRotateCCWTransformation]=XeeRotateCWTransformation,
	};
	if(trans>8) return XeeUnknownTransformation;
	return table[trans];
}

XeeTransformation XeeCombineTransformations(XeeTransformation a,XeeTransformation b)
{
	static const XeeTransformation table[9][9]=
	{
		{0,1,2,3,4,5,6,7,8},
		{1,1,2,3,4,5,6,7,8},
		{2,2,1,4,3,8,7,6,5},
		{3,3,4,1,2,7,8,5,6},
		{4,4,3,2,1,6,5,8,7},
		{5,5,6,7,8,1,2,3,4},
		{6,6,5,8,7,4,3,2,1},
		{7,7,8,5,6,3,4,1,2},
		{8,8,7,6,5,2,1,4,3},
	};
	if(a>8||b>8) return XeeUnknownTransformation;
	return table[a][b]; // order uncertain
}

XeeMatrix XeeMatrixForTransformation(XeeTransformation trans,float w,float h)
{
	const XeeMatrix table[9]=
	{
		{ 1, 0, 0, 0, 1, 0},
		{ 1, 0, 0, 0, 1, 0},
		{-1, 0, w, 0, 1, 0},
		{-1, 0, w, 0,-1, h},
		{ 1, 0, 0, 0,-1, h},
		{ 0, 1, 0, 1, 0, 0},
		{ 0,-1, h, 1, 0, 0},
		{ 0,-1, h,-1, 0, w},
		{ 0, 1, 0,-1, 0, w},
	};
	if(trans>8) return table[0];
	return table[trans];
}



//
// Time
//

double XeeGetTime()
{
	struct timeval tv;
	gettimeofday(&tv,0);
	return (double)tv.tv_sec+(double)tv.tv_usec/1000000.0;
}



//
// Hex data
//

NSString *XeeHexDump(const uint8_t *data,int length,int maxlen)
{
	NSMutableString *str=[NSMutableString string];

	int len=imin(length,maxlen);
	for(int i=0;i<len;i++) [str appendFormat:@"%s%02x",i==0?"":" ",data[i]];

	if(length>maxlen) [str appendFormat:@"..."];

	return str;
}



//
// Events
//

BOOL IsSmoothScrollEvent(NSEvent *event)
{
	const EventRef carbonevent=(EventRef)[event eventRef];
	if(!carbonevent) return NO;
	if(GetEventKind(carbonevent)!=kEventMouseScroll) return NO;
	if(![event respondsToSelector:@selector(deviceDeltaX)]) return NO;
	if(![event respondsToSelector:@selector(deviceDeltaY)]) return NO;
	return YES;
}


