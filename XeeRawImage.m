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
static inline uint8_t clamp8(int a) { if(a<0) return 0; else if(a>255) return 255; else return a; }
static inline uint16_t clamp16(int a) { if(a<0) return 0; else if(a>65535) return 65535; else return a; }

@implementation XeeRawImage

-(id)initWithHandle:(CSHandle *)inhandle width:(int)framewidth height:(int)frameheight
depth:(int)framedepth colourSpace:(int)space flags:(int)flags
{
	return [self initWithHandle:inhandle width:framewidth height:frameheight depth:framedepth
	colourSpace:space flags:flags bytesPerRow:0];
}

-(id)initWithHandle:(CSHandle *)inhandle width:(int)framewidth height:(int)frameheight
depth:(int)framedepth colourSpace:(int)space flags:(int)flags bytesPerRow:(int)bytesperinputrow
{
	if(self=[super initWithHandle:inhandle])
	{
		width=framewidth;
		height=frameheight;
		bitdepth=framedepth;
		inbpr=bytesperinputrow;

		BOOL alphafirst=flags&XeeAlphaFirstRawFlag;
		BOOL alphalast=flags&XeeAlphaLastRawFlag;
		BOOL hasalpha=alphafirst||alphalast;
		BOOL skipalpha=hasalpha&&(flags&XeeSkipAlphaRawFlag);
		BOOL premult=hasalpha&&(flags&XeeAlphaPremultipliedRawFlag);
		BOOL precomp=hasalpha&&(flags&XeeAlphaPrecomposedRawFlag);
		BOOL isfloat=flags&XeeFloatingPointRawFlag;

		transformation=uncomposition=0;
		buffer=NULL;
		type=0;

		#ifdef __BIG_ENDIAN__
		flipendian=(flags&XeeBigEndianRawFlag)?NO:YES;
		#else
		flipendian=(flags&XeeBigEndianRawFlag)?YES:NO;
		#endif

		adjustranges=NO;
		range[0][0]=range[1][0]=range[2][0]=range[3][0]=range[4][0]=0;
		range[0][1]=range[1][1]=range[2][1]=range[3][1]=range[4][1]=1;

		if(precomp)
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

		int modealphafirst,modealphalast;
		if(!hasalpha) { modealphafirst=XeeAlphaNone; modealphalast=XeeAlphaNone; }
		else if(skipalpha) { modealphafirst=XeeAlphaNoneSkipFirst; modealphalast=XeeAlphaNoneSkipLast; }
		else if(premult) { modealphafirst=XeeAlphaPremultipliedFirst; modealphalast=XeeAlphaPremultipliedLast; }
		else { modealphafirst=XeeAlphaFirst; modealphalast=XeeAlphaLast; }

		switch(space)
		{
			case XeeGreyRawColourSpace:
				if(bitdepth==8)
				{
					type=XeeBitmapType(XeeGreyBitmap,8,modealphalast,0);
					if(alphafirst) transformation=XeeRawFlipGreyAlpha8;
				}
				else if(bitdepth==16)
				{
					type=XeeBitmapType(XeeGreyBitmap,16,modealphalast,0);
					if(alphafirst) transformation=XeeRawFlipGreyAlpha16;
				}
				else if(bitdepth==32)
				{
					type=XeeBitmapType(XeeGreyBitmap,32,modealphalast,isfloat?XeeBitmapFloatingPointFlag:0);
					if(alphafirst) transformation=XeeRawFlipGreyAlpha32;
				}
				channels=1;
			break;

			case XeeRGBRawColourSpace:
				if(bitdepth==8)
				{
					type=XeeBitmapType(XeeRGBBitmap,8,modealphafirst,0);
					if(alphalast) transformation=XeeRawReverseFlipRGBAlpha8;
				}
				else if(bitdepth==16)
				{
					type=XeeBitmapType(XeeRGBBitmap,16,modealphalast,0);
					if(alphafirst) transformation=XeeRawFlipRGBAlpha16;
				}
				else if(bitdepth==32)
				{
					type=XeeBitmapType(XeeRGBBitmap,32,modealphalast,isfloat?XeeBitmapFloatingPointFlag:0);
					if(alphafirst) transformation=XeeRawFlipRGBAlpha32;
				}
				channels=3;
			break;

			case XeeCMYKRawColourSpace:
				if(bitdepth==8&&!alphafirst)
				{
					type=XeeBitmapType(XeeRGBBitmap,8,modealphafirst,0);
					if(hasalpha) transformation=XeeRawCMYKAConversion8;
					else transformation=XeeRawCMYKConversion8;
					needsbuffer=YES;
				}
				else if(bitdepth==16&&!alphafirst)
				{
					type=XeeBitmapType(XeeRGBBitmap,16,modealphalast,0);
					if(hasalpha) transformation=XeeRawCMYKAConversion16;
					else transformation=XeeRawCMYKConversion16;
					needsbuffer=YES;
				}
				channels=4;
			break;

			case XeeLabRawColourSpace:
				if(bitdepth==8&&!alphafirst)
				{
					type=XeeBitmapType(XeeRGBBitmap,8,modealphafirst,0);
					transformation=XeeRawLabConversion8;
				}
				else if(bitdepth==16&&!alphafirst)
				{
					type=XeeBitmapType(XeeRGBBitmap,16,modealphalast,0);
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

-(void)setZeroPoint:(float)low onePoint:(float)high forChannel:(int)channel
{
	if(channel>=channels||channel<0) return;
	adjustranges=YES;
	range[channel][0]=low;
	range[channel][1]=high;
}

-(void)load
{
	if(!handle) XeeImageLoaderDone(NO);
	XeeImageLoaderHeaderDone();

	if(![self allocWithType:type width:width height:height]) XeeImageLoaderDone(NO);

	int bytesperinputrow=(bitdepth/8)*width*channels;

	if(needsbuffer)
	{
		buffer=malloc(bytesperinputrow);
		if(!buffer) XeeImageLoaderDone(NO);
	}

	for(int row=0;row<height;row++)
	{
		uint8_t *datarow;
		if(buffer) datarow=buffer;
		else datarow=XeeImageDataRow(self,row);

		[handle readBytes:bytesperinputrow toBuffer:datarow];

		if(inbpr&&inbpr!=bytesperinputrow) [handle skipBytes:inbpr-bytesperinputrow];

		if(flipendian)
		{
			if(bitdepth==16)
			{
				uint32_t *ptr=(uint32_t *)datarow;
				int n=width*channels;
				for(;n>1;n-=2) { uint32_t a=*ptr; *ptr++=((a&0xff00ff00)>>8)|((a&0x00ff00ff)<<8); }
				if(n) { uint16_t *p16=(uint16_t *)ptr; uint16_t a=*p16; *p16=(a>>8)||(a<<8); }
			}
			else if(bitdepth==32)
			{
				uint32_t *rowptr=(uint32_t *)datarow;
				int n=width*channels;
				while(n--) { uint32_t a=rowptr[0]; *rowptr++=((a&0xff000000)>>24)|((a&0x00ff0000)>>8)|((a&0x0000ff00)<<8)|((a&0x000000ff)<<24); }
			}
		}

		switch(uncomposition)
		{
			case XeeRawUncomposeAlphaLast8:
			{
				uint8_t *ptr=datarow;
				for(int x=0;x<width;x++)
				{
					if(ptr[channels-1]) for(int i=0;i<channels-1;i++) ptr[i]=((ptr[i]-255+ptr[channels-1])*255)/ptr[channels-1];
					ptr+=channels;
				}
			}
			break;

			case XeeRawUncomposeAlphaFirst8:
			{
				uint8_t *ptr=datarow;
				for(int x=0;x<width;x++)
				{
					if(ptr[0]) for(int i=1;i<channels;i++) ptr[i]=((ptr[i]-255+ptr[0])*255)/ptr[0];
					ptr+=channels;
				}
			}
			break;

			case XeeRawUncomposeAlphaLab8:
			{
				uint8_t *ptr=datarow;
				for(int x=0;x<width;x++)
				{
					if(ptr[3]) ptr[0]=((ptr[0]-255+ptr[3])*255)/ptr[3];
					ptr+=4;
				}
			}
			break;

			case XeeRawUncomposeAlphaLast16:
			{
				uint16_t *ptr=(uint16_t *)datarow;
				for(int x=0;x<width;x++)
				{
					if(ptr[channels-1]) for(int i=0;i<channels-1;i++) ptr[i]=((uint32_t)(ptr[i]-65535+ptr[channels-1])*65535)/ptr[channels-1];
					ptr+=channels;
				}
			}
			break;

			case XeeRawUncomposeAlphaFirst16:
			{
				uint16_t *ptr=(uint16_t *)datarow;
				for(int x=0;x<width;x++)
				{
					if(ptr[0]) for(int i=0;i<channels-1;i++) ptr[i]=((uint32_t)(ptr[i]-65535+ptr[0])*65535)/ptr[0];
					ptr+=channels;
				}
			}
			break;

			case XeeRawUncomposeAlphaLab16:
			{
				uint16_t *ptr=(uint16_t *)datarow;
				for(int x=0;x<width;x++)
				{
					if(ptr[3]) ptr[0]=((uint32_t)(ptr[0]-65535+ptr[3])*65535)/ptr[3];
					ptr+=4;
				}
			}
			break;
		}

		if(adjustranges)
		{
			switch(bitdepth)
			{
				case 8:
					for(int i=0;i<width*channels;i++)
					datarow[i]=datarow[i]*range[i%channels][1]+(255-datarow[i])*range[i%channels][0];
				break;

				case 16:
				{
					uint16_t *datarow16=(uint16_t *)datarow;
					for(int i=0;i<width*channels;i++)
					datarow16[i]=datarow16[i]*range[i%channels][1]+(65535-datarow16[i])*range[i%channels][0];
				}
				break;
			}
		}

		switch(transformation)
		{
			case XeeRawFlipGreyAlpha8:
			{
				uint16_t *ptr=(uint16_t *)XeeImageDataRow(self,row);
				for(int x=0;x<width;x++) { uint16_t a=ptr[0]; *ptr++=(a<<8)|(a>>8); }
			}
			break;

			case XeeRawFlipGreyAlpha16:
			{
				uint32_t *ptr=(uint32_t *)XeeImageDataRow(self,row);
				for(int x=0;x<width;x++) { uint32_t a=ptr[0]; *ptr++=(a<<16)|(a>>16); }
			}
			break;

			case XeeRawFlipGreyAlpha32:
			{
				uint32_t *ptr=(uint32_t *)XeeImageDataRow(self,row);
				for(int x=0;x<width;x++) { uint32_t a=ptr[0],b=ptr[1]; *ptr++=b; *ptr++=a; }
			}
			break;

			case XeeRawReverseFlipRGBAlpha8:
			{
				uint32_t *ptr=(uint32_t *)XeeImageDataRow(self,row);
				#ifdef __BIG_ENDIAN__
				for(int x=0;x<width;x++) { uint32_t a=ptr[0]; *ptr++=(a<<24)|(a>>8); }
				#else
				for(int x=0;x<width;x++) { uint32_t a=ptr[0]; *ptr++=(a>>24)|(a<<8); }
				#endif
			}
			break;

			case XeeRawFlipRGBAlpha16:
			{
				uint32_t *ptr=(uint32_t *)XeeImageDataRow(self,row);
				#ifdef __BIG_ENDIAN__
				for(int x=0;x<width;x++) { uint32_t a=ptr[0],b=ptr[1]; *ptr++=(a<<16)|(b>>16); *ptr++=(b<<16)|(a>>16); }
				#else
				for(int x=0;x<width;x++) { uint32_t a=ptr[0],b=ptr[1]; *ptr++=(a>>16)|(b<<16); *ptr++=(b>>16)|(a<<16); }
				#endif
			}
			break;

			case XeeRawFlipRGBAlpha32:
			{
				uint32_t *ptr=(uint32_t *)XeeImageDataRow(self,row);
				for(int x=0;x<width;x++) { uint32_t a=ptr[0],b=ptr[1],c=ptr[2],d=ptr[3]; *ptr++=b; *ptr++=c; *ptr++=d; *ptr++=a; }
			}
			break;

			case XeeRawCMYKConversion8:
			{
				uint8_t *rgb=XeeImageDataRow(self,row);
				uint8_t *cmyk=buffer;
				for(int x=0;x<width;x++)
				{
					uint8_t c=255-*cmyk++,m=255-*cmyk++,y=255-*cmyk++,k=255-*cmyk++;
					*rgb++=(k*c)/255; *rgb++=(k*m)/255; *rgb++=(k*y)/255;
				}
			}
			break;

			case XeeRawCMYKAConversion8:
			{
				uint8_t *rgb=XeeImageDataRow(self,row);
				uint8_t *cmyk=buffer;
				for(int x=0;x<width;x++)
				{
					uint8_t c=255-*cmyk++,m=255-*cmyk++,y=255-*cmyk++,k=255-*cmyk++,a=*cmyk++;
					*rgb++=a;
					*rgb++=(k*c)/255; *rgb++=(k*m)/255; *rgb++=(k*y)/255;
				}
			}
			break;

			case XeeRawCMYKConversion16:
			{
				uint16_t *rgb=(uint16_t *)XeeImageDataRow(self,row);
				uint16_t *cmyk=(uint16_t *)buffer;
				for(int x=0;x<width;x++)
				{
					uint16_t c=65535-*cmyk++,m=65535-*cmyk++,y=65535-*cmyk++,k=65535-*cmyk++;
					*rgb++=(uint32_t)(k*c)/65535; *rgb++=(uint32_t)(k*m)/65535; *rgb++=(uint32_t)(k*y)/65535;
				}
			}
			break;

			case XeeRawCMYKAConversion16:
			{
				uint16_t *rgb=(uint16_t *)XeeImageDataRow(self,row);
				uint16_t *cmyk=(uint16_t *)buffer;
				for(int x=0;x<width;x++)
				{
					uint16_t c=65535-*cmyk++,m=65535-*cmyk++,y=65535-*cmyk++,k=65535-*cmyk++,a=*cmyk++;
					*rgb++=(uint32_t)(k*c)/65535; *rgb++=(uint32_t)(k*m)/65535; *rgb++=(uint32_t)(k*y)/65535;
					*rgb++=a;
				}
			}
			break;

			case XeeRawLabConversion8: // not sure what RGB space this ends up in, needs fixing when colourspace support is added
			{
				uint8_t *ptr=XeeImageDataRow(self,row);
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
				uint16_t *ptr=(uint16_t *)XeeImageDataRow(self,row);
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

		[self setCompletedRowCount:row+1];
		XeeImageLoaderYield();
	}

	free(buffer);
	buffer=NULL;

	XeeImageLoaderDone(YES);
}

@end
