#import "XeeRawImage.h"

#define XeeRawFlipGreyAlpha8 1
#define XeeRawFlipGreyAlpha16 2
#define XeeRawFlipGreyAlpha32 3
#define XeeRawReverseFlipRGBAlpha8 4
#define XeeRawFlipRGBAlpha16 5
#define XeeRawFlipRGBAlpha32 6
#define XeeRawCMYKConversion8 7
#define XeeRawCMYKAConversion8 8
#define XeeRawCMYKConversion16 9
#define XeeRawCMYKAConversion16 10
#define XeeRawLabConversion8 11
#define XeeRawLabConversion16 12

#define XeeRawUncomposeAlphaLast8 1
#define XeeRawUncomposeAlphaFirst8 2
#define XeeRawUncomposeAlphaLab8 3
#define XeeRawUncomposeAlphaLast16 4
#define XeeRawUncomposeAlphaFirst16 5
#define XeeRawUncomposeAlphaLab16 6

static inline float cube(float a) { return a*a*a; }
static inline uint8 clamp8(int a) { if(a<0) return 0; else if(a>255) return 255; else return a; }
static inline uint16 clamp16(int a) { if(a<0) return 0; else if(a>65535) return 65535; else return a; }

@implementation XeeRawImage

-(id)initWithHandle:(CSHandle *)inhandle width:(int)framewidth height:(int)frameheight
depth:(int)framedepth colourSpace:(int)space flags:(int)flags
parentImage:(XeeMultiImage *)parent
{
	return [self initWithHandle:inhandle width:framewidth height:frameheight depth:framedepth
	colourSpace:space flags:flags bytesPerRow:0 parentImage:parent];
}

-(id)initWithHandle:(CSHandle *)inhandle width:(int)framewidth height:(int)frameheight
depth:(int)framedepth colourSpace:(int)space flags:(int)flags bytesPerRow:(int)bytesperinputrow
parentImage:(XeeMultiImage *)parent
{
	if(self=[super initWithParentImage:parent])
	{
		handle=[inhandle retain];
		width=framewidth;
		height=frameheight;
		bitdepth=framedepth;
		inbpr=bytesperinputrow;

		BOOL alphafirst=flags&XeeAlphaFirstRawFlag;
		BOOL alphalast=flags&XeeAlphaLastRawFlag;
		BOOL hasalpha=alphafirst||alphalast;
		BOOL premult=hasalpha&&(flags&XeeAlphaPremultipliedRawFlag);
		BOOL isfloat=flags&XeeFloatingPointRawFlag;


		transformation=uncomposition=0;
		buffer=NULL;
		type=0;

		#ifdef __BIG_ENDIAN__
		flipendian=(flags&XeeBigEndianRawFlag)?NO:YES;
		#else
		flipendian=(flags&XeeBigEndianRawFlag)?YES:NO;
		#endif

		if(hasalpha&&(flags&XeeAlphaPrecomposedRawFlag))
		{
			if(bitdepth==8)
			{
				if(alphafirst) uncomposition=XeeRawUncomposeAlphaFirst8;
				else if(space==XeeLabRawColourSpace) uncomposition=XeeRawUncomposeAlphaLab8;
				else uncomposition=XeeRawUncomposeAlphaLast8;
			}
			else if(bitdepth==16)
			{
				if(alphafirst) uncomposition=XeeRawUncomposeAlphaFirst16;
				else if(space==XeeLabRawColourSpace) uncomposition=XeeRawUncomposeAlphaLab16;
				else uncomposition=XeeRawUncomposeAlphaLast16;
			}
			else
			{
				[self release];
				return nil;
			}
		}

		switch(space)
		{
			case XeeGreyRawColourSpace:
				if(bitdepth==8)
				{
					type=XeeBitmapType(XeeGreyBitmap,8,hasalpha?(premult?XeeAlphaPremultipliedLast:XeeAlphaLast):XeeAlphaNone,0);
					if(alphafirst) transformation=XeeRawFlipGreyAlpha8;
				}
				else if(bitdepth==16)
				{
					type=XeeBitmapType(XeeGreyBitmap,16,hasalpha?(premult?XeeAlphaPremultipliedLast:XeeAlphaLast):XeeAlphaNone,0);
					if(alphafirst) transformation=XeeRawFlipGreyAlpha16;
				}
				else if(bitdepth==32)
				{
					type=XeeBitmapType(XeeGreyBitmap,32,hasalpha?(premult?XeeAlphaPremultipliedLast:XeeAlphaLast):XeeAlphaNone,isfloat?XeeBitmapFloatingPointFlag:0);
					if(alphafirst) transformation=XeeRawFlipGreyAlpha32;
				}
				channels=1;
			break;

			case XeeRGBRawColourSpace:
				if(bitdepth==8)
				{
					type=XeeBitmapType(XeeRGBBitmap,8,hasalpha?(premult?XeeAlphaPremultipliedFirst:XeeAlphaFirst):XeeAlphaNone,0);
					if(alphalast) transformation=XeeRawReverseFlipRGBAlpha8;
				}
				else if(bitdepth==16)
				{
					type=XeeBitmapType(XeeRGBBitmap,16,hasalpha?(premult?XeeAlphaPremultipliedLast:XeeAlphaLast):XeeAlphaNone,0);
					if(alphafirst) transformation=XeeRawFlipRGBAlpha16;
				}
				else if(bitdepth==32)
				{
					type=XeeBitmapType(XeeRGBBitmap,32,hasalpha?(premult?XeeAlphaPremultipliedLast:XeeAlphaLast):XeeAlphaNone,isfloat?XeeBitmapFloatingPointFlag:0);
					if(alphafirst) transformation=XeeRawFlipRGBAlpha32;
				}
				channels=3;
			break;

			case XeeCMYKRawColourSpace:
				if(bitdepth==8&&!alphafirst)
				{
					type=XeeBitmapType(XeeRGBBitmap,8,hasalpha?(premult?XeeAlphaPremultipliedFirst:XeeAlphaFirst):XeeAlphaNone,0);
					if(hasalpha) transformation=XeeRawCMYKAConversion8;
					else transformation=XeeRawCMYKConversion8;
					needsbuffer=YES;
				}
				else if(bitdepth==16&&!alphafirst)
				{
					type=XeeBitmapType(XeeRGBBitmap,16,hasalpha?(premult?XeeAlphaPremultipliedLast:XeeAlphaLast):XeeAlphaNone,0);
					if(hasalpha) transformation=XeeRawCMYKAConversion16;
					else transformation=XeeRawCMYKConversion16;
					needsbuffer=YES;
				}
				channels=4;
			break;

			case XeeLabRawColourSpace:
				if(bitdepth==8&&!alphafirst)
				{
					type=XeeBitmapType(XeeRGBBitmap,8,hasalpha?(premult?XeeAlphaPremultipliedFirst:XeeAlphaFirst):XeeAlphaNone,0);
					transformation=XeeRawLabConversion8;
				}
				else if(bitdepth==16&&!alphafirst)
				{
					type=XeeBitmapType(XeeRGBBitmap,16,hasalpha?(premult?XeeAlphaPremultipliedLast:XeeAlphaLast):XeeAlphaNone,0);
					transformation=XeeRawLabConversion16;
				}
				channels=3;
			break;
		}

		if(hasalpha) channels++;

		if(type)
		{
			return self;
		}

		[self release];
	}
	return nil;
}

-(void)dealloc
{
	free(buffer);
	[super dealloc];
}

-(SEL)initLoader
{
	if(!handle) return NULL;

	if(![self allocWithType:type width:width height:height]) return NULL;

	if(needsbuffer)
	{
		buffer=malloc((bitdepth/8)*width*channels);
		if(!buffer) return NULL;
	}

	row=0;
	return @selector(load);
}

-(void)deallocLoader
{
	[handle release];
	handle=nil;
	free(buffer);
	buffer=NULL;
}

-(SEL)load
{
	int bytesperinputrow=(bitdepth/8)*width*channels;

	while(!stop)
	{
		uint8 *datarow;
		if(buffer) datarow=buffer;
		else datarow=XeeImageDataRow(self,row);

		[handle readBytes:bytesperinputrow toBuffer:datarow];

		if(inbpr&&inbpr!=bytesperinputrow) [handle skipBytes:inbpr-bytesperinputrow];

		if(flipendian)
		{
			if(bitdepth==16)
			{
				uint32 *ptr=(uint32 *)datarow;
				int n=width*channels;
				for(;n>1;n-=2) { uint32 a=*ptr; *ptr++=((a&0xff00ff00)>>8)|((a&0x00ff00ff)<<8); }
				if(n) { uint16 *p16=(uint16 *)ptr; uint16 a=*p16; *p16=(a>>8)||(a<<8); }
			}
			else if(bitdepth==32)
			{
				uint32 *rowptr=(uint32 *)datarow;
				int n=width*channels;
				while(n--) { uint32 a=rowptr[0]; *rowptr++=((a&0xff000000)>>24)|((a&0x00ff0000)>>8)|((a&0x0000ff00)<<8)|((a&0x000000ff)<<24); }
			}
		}

		switch(uncomposition)
		{
			case XeeRawUncomposeAlphaLast8:
			{
				uint8 *ptr=datarow;
				for(int x=0;x<width;x++)
				{
					if(ptr[channels-1]) for(int i=0;i<channels-1;i++) ptr[i]=((ptr[i]-255+ptr[channels-1])*255)/ptr[channels-1];
					ptr+=channels;
				}
			}
			break;

			case XeeRawUncomposeAlphaFirst8:
			{
				uint8 *ptr=datarow;
				for(int x=0;x<width;x++)
				{
					if(ptr[0]) for(int i=1;i<channels;i++) ptr[i]=((ptr[i]-255+ptr[0])*255)/ptr[0];
					ptr+=channels;
				}
			}
			break;

			case XeeRawUncomposeAlphaLab8:
			{
				uint8 *ptr=datarow;
				for(int x=0;x<width;x++)
				{
					if(ptr[3]) ptr[0]=((ptr[0]-255+ptr[3])*255)/ptr[3];
					ptr+=4;
				}
			}
			break;

			case XeeRawUncomposeAlphaLast16:
			{
				uint16 *ptr=(uint16 *)datarow;
				for(int x=0;x<width;x++)
				{
					if(ptr[channels-1]) for(int i=0;i<channels-1;i++) ptr[i]=((uint32)(ptr[i]-65535+ptr[channels-1])*65535)/ptr[channels-1];
					ptr+=channels;
				}
			}
			break;

			case XeeRawUncomposeAlphaFirst16:
			{
				uint16 *ptr=(uint16 *)datarow;
				for(int x=0;x<width;x++)
				{
					if(ptr[0]) for(int i=0;i<channels-1;i++) ptr[i]=((uint32)(ptr[i]-65535+ptr[0])*65535)/ptr[0];
					ptr+=channels;
				}
			}
			break;

			case XeeRawUncomposeAlphaLab16:
			{
				uint16 *ptr=(uint16 *)datarow;
				for(int x=0;x<width;x++)
				{
					if(ptr[3]) ptr[0]=((uint32)(ptr[0]-65535+ptr[3])*65535)/ptr[3];
					ptr+=4;
				}
			}
			break;
		}

		switch(transformation)
		{
			case XeeRawFlipGreyAlpha8:
			{
				uint16 *ptr=(uint16 *)XeeImageDataRow(self,row);
				for(int x=0;x<width;x++) { uint16 a=ptr[0]; *ptr++=(a<<8)|(a>>8); }
			}
			break;

			case XeeRawFlipGreyAlpha16:
			{
				uint32 *ptr=(uint32 *)XeeImageDataRow(self,row);
				for(int x=0;x<width;x++) { uint32 a=ptr[0]; *ptr++=(a<<16)|(a>>16); }
			}
			break;

			case XeeRawFlipGreyAlpha32:
			{
				uint32 *ptr=(uint32 *)XeeImageDataRow(self,row);
				for(int x=0;x<width;x++) { uint32 a=ptr[0],b=ptr[1]; *ptr++=b; *ptr++=a; }
			}
			break;

			case XeeRawReverseFlipRGBAlpha8:
			{
				uint32 *ptr=(uint32 *)XeeImageDataRow(self,row);
				#ifdef __BIG_ENDIAN__
				for(int x=0;x<width;x++) { uint32 a=ptr[0]; *ptr++=(a<<24)|(a>>8); }
				#else
				for(int x=0;x<width;x++) { uint32 a=ptr[0]; *ptr++=(a>>24)|(a<<8); }
				#endif
			}
			break;

			case XeeRawFlipRGBAlpha16:
			{
				uint32 *ptr=(uint32 *)XeeImageDataRow(self,row);
				#ifdef __BIG_ENDIAN__
				for(int x=0;x<width;x++) { uint32 a=ptr[0],b=ptr[1]; *ptr++=(a<<16)|(b>>16); *ptr++=(b<<16)|(a>>16); }
				#else
				for(int x=0;x<width;x++) { uint32 a=ptr[0],b=ptr[1]; *ptr++=(a>>16)|(b<<16); *ptr++=(b>>16)|(a<<16); }
				#endif
			}
			break;

			case XeeRawFlipRGBAlpha32:
			{
				uint32 *ptr=(uint32 *)XeeImageDataRow(self,row);
				for(int x=0;x<width;x++) { uint32 a=ptr[0],b=ptr[1],c=ptr[2],d=ptr[3]; *ptr++=b; *ptr++=c; *ptr++=d; *ptr++=a; }
			}
			break;

			case XeeRawCMYKConversion8:
			{
				uint8 *rgb=XeeImageDataRow(self,row);
				uint8 *cmyk=buffer;
				for(int x=0;x<width;x++)
				{
					uint8 c=*cmyk++,m=*cmyk++,y=*cmyk++,k=*cmyk++;
					*rgb++=(k*c)/255; *rgb++=(k*m)/255; *rgb++=(k*y)/255;
				}
			}
			break;

			case XeeRawCMYKAConversion8:
			{
				uint8 *rgb=XeeImageDataRow(self,row);
				uint8 *cmyk=buffer;
				for(int x=0;x<width;x++)
				{
					uint8 c=*cmyk++,m=*cmyk++,y=*cmyk++,k=*cmyk++,a=*cmyk++;
					*rgb++=a;
					*rgb++=(k*c)/255; *rgb++=(k*m)/255; *rgb++=(k*y)/255;
				}
			}
			break;

			case XeeRawCMYKConversion16:
			{
				uint16 *rgb=(uint16 *)XeeImageDataRow(self,row);
				uint16 *cmyk=(uint16 *)buffer;
				for(int x=0;x<width;x++)
				{
					uint16 c=*cmyk++,m=*cmyk++,y=*cmyk++,k=*cmyk++;
					*rgb++=(uint32)(k*c)/65535; *rgb++=(uint32)(k*m)/65535; *rgb++=(uint32)(k*y)/65535;
				}
			}
			break;

			case XeeRawCMYKAConversion16:
			{
				uint16 *rgb=(uint16 *)XeeImageDataRow(self,row);
				uint16 *cmyk=(uint16 *)buffer;
				for(int x=0;x<width;x++)
				{
					uint16 c=*cmyk++,m=*cmyk++,y=*cmyk++,k=*cmyk++,a=*cmyk++;
					*rgb++=(uint32)(k*c)/65535; *rgb++=(uint32)(k*m)/65535; *rgb++=(uint32)(k*y)/65535;
					*rgb++=a;
				}
			}
			break;

			case XeeRawLabConversion8: // not sure what RGB space this ends up, needs fixing when colourspace support is added
			{
				uint8 *ptr=XeeImageDataRow(self,row);
				for(int i=0;i<width;i++)
				{
					float L=ptr[0]/2.55f,a=ptr[1]-128.0f,b=ptr[2]-128.0f;
					float fy=(L+16.0f)/116.0f,fx=fy+a/500.0f,fz=fy-b/200.0f;
					float delta=6.0f/29.0f,xn=0.34567*3,yn=0.35850*3,zn=3-xn-yn; // D50 white point, I think
					float y=fy>delta?yn*cube(fy):(fy-16.0f/116.0f)*3*delta*delta*yn;
					float x=fx>delta?xn*cube(fx):(fx-16.0f/116.0f)*3*delta*delta*xn;
					float z=fz>delta?zn*cube(fz):(fz-16.0f/116.0f)*3*delta*delta*zn;
					float R=x* 3.2406f+y*-1.5372f+z*-0.4986f;
					float G=x*-0.9689f+y* 1.8758f+z* 0.0415f;
					float B=x* 0.0557f+y*-0.2040f+z* 1.0570f;
					R=R>0.0031308f?1.055f*pow(R,1.0f/2.4f)-0.055f:12.92f*R;
					G=G>0.0031308f?1.055f*pow(G,1.0f/2.4f)-0.055f:12.92f*G;
					B=B>0.0031308f?1.055f*pow(B,1.0f/2.4f)-0.055f:12.92f*B;
					if(channels==4) { ptr[0]=ptr[3]; ptr++; } // swap alpha position
					ptr[0]=clamp8(255.0f*R+0.5);
					ptr[1]=clamp8(255.0f*G+0.5);
					ptr[2]=clamp8(255.0f*B+0.5);
					ptr+=3;
				}
			}
			break;

			case XeeRawLabConversion16:
			{
				uint16 *ptr=(uint16 *)XeeImageDataRow(self,row);
				for(int i=0;i<width;i++)
				{
					float L=ptr[0]/2.55f/256.0f,a=ptr[1]/256.0f-128.0f,b=ptr[2]/256.0f-128.0f;
					float fy=(L+16.0f)/116.0f,fx=fy+a/500.0f,fz=fy-b/200.0f;
					float delta=6.0f/29.0f,xn=0.34567*3,yn=0.35850*3,zn=3-xn-yn; // D50 white point, I think
					float y=fy>delta?yn*cube(fy):(fy-16.0f/116.0f)*3*delta*delta*yn;
					float x=fx>delta?xn*cube(fx):(fx-16.0f/116.0f)*3*delta*delta*xn;
					float z=fz>delta?zn*cube(fz):(fz-16.0f/116.0f)*3*delta*delta*zn;
					float R=x* 3.2406f+y*-1.5372f+z*-0.4986f;
					float G=x*-0.9689f+y* 1.8758f+z* 0.0415f;
					float B=x* 0.0557f+y*-0.2040f+z* 1.0570f;
					R=R>0.0031308f?1.055f*pow(R,1.0f/2.4f)-0.055f:12.92f*R;
					G=G>0.0031308f?1.055f*pow(G,1.0f/2.4f)-0.055f:12.92f*G;
					B=B>0.0031308f?1.055f*pow(B,1.0f/2.4f)-0.055f:12.92f*B;
					ptr[0]=clamp16(65535.0f*R+0.5);
					ptr[1]=clamp16(65535.0f*G+0.5);
					ptr[2]=clamp16(65535.0f*B+0.5);
					ptr+=channels;
				}
			}
			break;
		}

		row++;
		[self setCompletedRowCount:row];
		if(row>=height)
		{
			loaded=YES;
			return NULL;
		}
	}
	return @selector(load);
}

@end
