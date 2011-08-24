#import <Cocoa/Cocoa.h>

//
// Base types
//

typedef unsigned char byte;
typedef unsigned char uint8;
typedef signed char int8;
typedef unsigned short uint16;
typedef signed short int16;
typedef unsigned long uint32;
typedef signed long int32;
typedef unsigned long long uint64;
typedef signed long long int64;



//
// Endian-independent types
//

typedef byte eint16[2];
typedef byte eint32[4];
typedef byte eint64[8];

#define read_be_uint16(ptr) (((ptr)[0]<<8)|(ptr)[1])
#define read_be_int16(ptr) ((int16)read_be_uint16(ptr))
#define read_be_uint32(ptr) (((ptr)[0]<<24)|((ptr)[1]<<16)|((ptr)[2]<<8)|(ptr)[3])
#define read_be_int32(ptr) ((int32)read_be_uint32(ptr))
#define read_be_uint64(ptr) (((uint64)(ptr)[0]<<56)|((uint64)(ptr)[1]<<48)|((uint64)(ptr)[2]<<40)|((uint64)(ptr)[3]<<32)|((uint64)(ptr)[4]<<24)|((uint64)(ptr)[5]<<16)|((uint64)(ptr)[6]<<8)|(uint64)(ptr)[7])
#define read_be_int64(ptr) ((int64)read_be_uint64(ptr))

#define read_le_uint16(ptr) (((ptr)[1]<<8)|(ptr)[0])
#define read_le_int16(ptr) ((int16)read_le_uint16(ptr))
#define read_le_uint32(ptr) (((ptr)[3]<<24)|((ptr)[2]<<16)|((ptr)[1]<<8)|(ptr)[0])
#define read_le_int32(ptr) ((int32)read_le_uint32(ptr))
#define read_le_uint64(ptr) (((uint64)(ptr)[7]<<56)|((uint64)(ptr)[6]<<48)|((uint64)(ptr)[5]<<40)|((uint64)(ptr)[4]<<32)|((uint64)(ptr)[3]<<24)|((uint64)(ptr)[1]<<16)|((uint64)(ptr)[1]<<8)|(uint64)(ptr)[0])
#define read_le_int64(ptr) ((int64)read_le_uint64(ptr))

#define write_be_uint16(ptr,val) { (ptr)[0]=((val)>>8)&0xff; (ptr)[1]=(val)&0xff; }
#define write_be_int16(ptr,val) write_be_uint16(ptr,val)
#define write_be_uint32(ptr,val) { (ptr)[0]=((val)>>24)&0xff; (ptr)[1]=((val)>>16)&0xff; (ptr)[2]=((val)>>8)&0xff; (ptr)[3]=(val)&0xff; }
#define write_be_int32(ptr,val) write_be_uint32(ptr,val)

#define write_le_uint16(ptr,val) { (ptr)[0]=(val)&0xff; (ptr)[1]=((val)>>8)&0xff; }
#define write_le_int16(ptr,val) write_le_uint16(ptr,val)
#define write_le_uint32(ptr,val) { (ptr)[0]=(val)&0xff; (ptr)[1]=((val)>>8)&0xff; (ptr)[2]=((val)>>16)&0xff; (ptr)[3]=((val)>>24)&0xff; }
#define write_le_int32(ptr,val) write_le_uint32(ptr,val)



//
// Pixel spans
//

#define XeeEmptySpan XeeMakeSpan(0,0)

typedef struct XeeSpan { int start,length; } XeeSpan;

static inline XeeSpan XeeMakeSpan(int start,int length) { XeeSpan span={start,length}; return span; }

static inline int XeeSpanStart(XeeSpan span) { return span.start; }

static inline int XeeSpanEnd(XeeSpan span) { return span.start+span.length-1; }

static inline int XeeSpanPastEnd(XeeSpan span) { return span.start+span.length; }

static inline int XeeSpanLength(XeeSpan span) { return span.length; }

static inline BOOL XeeSpanEmpty(XeeSpan span) { return span.length==0; }

static inline BOOL XeePointInSpan(int point,XeeSpan span) { return point>=XeeSpanStart(span)&&point<XeeSpanPastEnd(span); }

static inline BOOL XeePointInSpan(int point,XeeSpan span) { return point>=XeeSpanStart(span)&&point<XeeSpanPastEnd(span); }

static inline BOOL XeeSpanStartsInSpan(XeeSpan span,XeeSpan inspan) { return XeePointInSpan(XeeSpanStart(span),inspan); }

static inline BOOL XeeSpanEndsInSpan(XeeSpan span,XeeSpan inspan) { return XeePointInSpan(XeeSpanEnd(span),inspan); }

static inline BOOL XeeSpansIdentical(XeeSpan span1,XeeSpan span2) { return span1.start==span2.start&&span1.length==span2.length; }

static inline XeeSpan XeeSpanShifted(XeeSpan span,int offset) { return XeeMakeSpan(XeeSpanStart(span)+offset,XeeSpanLength(span)); }

XeeSpan XeeSpanUnion(XeeSpan span1,XeeSpan span2);

XeeSpan XeeSpanIntersection(XeeSpan span1,XeeSpan span2);

XeeSpan XeeSpanDifference(XeeSpan old,XeeSpan new);



//
// Transformations
//

typedef enum {
	XeeUnknownTransformation=0,
	XeeNoTransformation=1,
	XeeMirrorHorizontalTransformation=2,
	XeeRotate180Transformation=3,
	XeeMirrorVerticalTransformation=4,
	XeeTransposeTransformation=5,
	XeeFirstFlippedTransformation=5,
	XeeRotateCWTransformation=6,
	XeeTransverseTransformation=7,
	XeeRotateCCWTransformation=8,
} XeeTransformation;

typedef struct {
	float a00,a01,a02;
	float a10,a11,a12;
} XeeTransformationMatrix;

#define XeeIdentityMatrix XeeMakeMatrix(1,0,0,0,1,0)



XeeTransformation XeeInverseTransformation(XeeTransformation trans);

XeeTransformation XeeCombineTransformations(XeeTransformation first,XeeTransformation second);



XeeTransformationMatrix XeeMatrixForTransformation(XeeTransformation trans,float width,float height);

XeeTransformationMatrix XeeMultiplyMatrices(XeeTransformationMatrix a,XeeTransformationMatrix b);

XeeTransformationMatrix XeeInverseMatrix(XeeTransformationMatrix mtx);

NSRect XeeTransformRectWithMatrix(XeeTransformationMatrix trans,NSRect rect);

void XeeGLMultMatrix(XeeTransformationMatrix trans);



static inline BOOL XeeTransformationIsNonTrivial(XeeTransformation trans) { return trans!=XeeNoTransformation&&trans!=XeeUnknownTransformation; }

static inline BOOL XeeTransformationIsFlipped(XeeTransformation trans) { return trans<XeeFirstFlippedTransformation; }

static inline NSRect XeeTransformRect(XeeTransformation trans,float width,float height,NSRect rect) { return XeeTransformRectWithMatrix(XeeMatrixForTransformation(trans,width,height),rect); }

static inline void XeeGLMultTransformation(XeeTransformation trans,float width,float height) { XeeGLMultMatrix(XeeMatrixForTransformation(trans,width,height)); }



static inline XeeTransformationMatrix XeeMakeMatrix(float a00,float a01,float a02,float a10,float a11,float a12) { XeeTransformationMatrix res={a00,a01,a02,a10,a11,a12}; return res; }

static inline XeeTransformationMatrix XeeScalingMatrix(float x_scale,float y_scale)
{ return XeeMakeMatrix(x_scale,0,0,0,y_scale,0); }

static inline XeeTransformationMatrix XeeTranslationMatrix(float x_offs,float y_offs)
{ return XeeMakeMatrix(1,0,x_offs,0,1,y_offs); }

static inline NSPoint XeeTransformPointWithMatrix(XeeTransformationMatrix mtx,NSPoint point)
{ return NSMakePoint(point.x*mtx.a00+point.y*mtx.a01+mtx.a02,point.x*mtx.a10+point.y*mtx.a11+mtx.a12); }







//
// Helper functions
//

static inline int imin(int a,int b) { return a<b?a:b; }

static inline int imax(int a,int b) { return a>b?a:b; }
