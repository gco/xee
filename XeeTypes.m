#import "XeeTypes.h"

#import <OpenGL/gl.h>


//
// Span functions
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
// Transformation functions
//

XeeTransformation XeeInverseTransformation(XeeTransformation trans)
{
	XeeTransformation inverses[9]={0,1,2,3,4,5,8,7,6};

	if(trans<0||trans>8) return XeeUnknownTransformation;
	return inverses[trans];
}

XeeTransformation XeeCombineTransformations(XeeTransformation first,XeeTransformation second)
{
	static const XeeTransformation table[9][9]={
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

	if(first<0||first>8) return XeeUnknownTransformation;
	if(second<0||second>8) return XeeUnknownTransformation;
	return table[first][second];
}


//
// Matrix functions
//

XeeTransformationMatrix XeeMatrixForTransformation(XeeTransformation trans,float width,float height)
{
	const XeeTransformationMatrix matrices[9]={
		{ 1, 0,     0, 0, 1,     0},
		{ 1, 0,     0, 0, 1,     0},
		{-1, 0, width, 0, 1,     0},
		{-1, 0, width, 0,-1,height},
		{ 1, 0,     0, 0,-1,height},
		{ 0, 1,     0, 1, 0,     0},
		{ 0,-1,height, 1, 0,     0},
		{ 0,-1,height,-1, 0, width},
		{ 0, 1,     0,-1, 0, width},
	};
	if(trans<0||trans>8) return XeeIdentityMatrix;
	return matrices[trans];
}

XeeTransformationMatrix XeeMultiplyMatrices(XeeTransformationMatrix a,XeeTransformationMatrix b)
{
	return XeeMakeMatrix(
		a.a00*b.a00+a.a01*b.a10,a.a00*b.a01+a.a01*b.a11,a.a00*b.a02+a.a01*b.a12+a.a02,
		a.a10*b.a00+a.a11*b.a10,a.a10*b.a01+a.a11*b.a11,a.a10*b.a02+a.a11*b.a12+a.a12);
}

XeeTransformationMatrix XeeInverseMatrix(XeeTransformationMatrix m)
{
	float det=m.a00*m.a11-m.a10*m.a01;
	return XeeMakeMatrix(
		 m.a11/det,-m.a01/det,(-m.a11*m.a02+m.a01*m.a12)/det,
		-m.a10/det, m.a00/det,( m.a10*m.a02-m.a00*m.a12)/det);
}

NSRect XeeTransformRectWithMatrix(XeeTransformationMatrix mtx,NSRect rect)
{
	float x1=rect.origin.x*mtx.a00+rect.origin.y*mtx.a01+mtx.a02;
	float y1=rect.origin.x*mtx.a10+rect.origin.y*mtx.a11+mtx.a12;
	float x2=x1+rect.size.width*mtx.a00+rect.size.height*mtx.a01;
	float y2=y1+rect.size.width*mtx.a10+rect.size.height*mtx.a11;

	return NSMakeRect(fminf(x1,x2),fminf(y1,y2),fabsf(x1-x2),fabsf(y1-y2));
}

void XeeGLMultMatrix(XeeTransformationMatrix mtx)
{
	float a[16]={mtx.a00,mtx.a10,0,0,mtx.a01,mtx.a11,0,0,0,0,1,0,mtx.a02,mtx.a12,0,1};
	glMultMatrixf(a);
}



/*

EXIF orientations and group theory:

Value	0th Row	0th Column
1	top	left side
2	top	right side
3	bottom	right side
4	bottom	left side
5	left side	top
6	right side	top
7	right side	bottom
8	left side	bottom

Read this table as follows (thanks to Peter Nielsen for clarifying this - see also below):
Entry #6 in the table says that the 0th row in the stored image is the right side of the captured scene, and the 0th column in the stored image is the top side of the captured scene.

Here is another description given by Adam M. Costello:

For convenience, here is what the letter F would look like if it were tagged correctly and displayed by a program that ignores the orientation tag (thus showing the stored image):

      1        2       3      4         5            6           7          8

    888888  888888      88  88      8888888888  88                  88  8888888888
    88          88      88  88      88  88      88  88          88  88      88  88
    8888      8888    8888  8888    88          8888888888  8888888888          88
    88          88      88  88
    88          88  888888  888888

This corresponds to the D4 group:

    /  1  0 \
I = |       |  (normal)
    \  0  1 /

    /  0 -1 \
A = |       |  (rotate 90 degrees CW)
    \  1  0 /

    / -1  0 \
B = |       |  (rotate 180 degrees)
    \  0 -1 /

    /  0  1 \
C = |       |  (rotate 90 degrees CCW)
    \ -1  0 /

    / -1  0 \
D = |       |  (mirror X)
    \  0  1 /

    /  0  1 \
E = |       |  (transpose)
    \  1  0 /

    /  1  0 \
F = |       |  (mirror Y)
    \  0 -1 /

    /  0 -1 \
G = |       |  (transverse)
    \ -1  0 /

The multiplication table of D4 is

IABCDEFG
ABCIEFGD
BCIAFGDE
CIABGDEF
DGFEICBA
EDGFAICB
FEDGBAIC
GFEDCBAI

The inverses of D4 are

I A B C D E F G
I C B A D E F G

The correspondance between the EXIF orientation numbering and D4 is

1 2 3 4 5 6 7 8
I D B F E A G C

Thus, the multiplication table of the EXIF orientations is

16382547
63815472
38164725
81637254
27451836
52746183
45273618
74528361

12345678
21438765
34127856
43216587
56781234
65874321
78563412
87652143


And the inverses

1 2 3 4 5 6 7 8
1 2 3 4 5 8 7 6


*/

