#import "XeeGraphicsStuff.h"

#import <OpenGL/gl.h>


struct XeeGradientInfo
{
	float start_r,start_g,start_b,start_a;
	float end_r,end_g,end_b,end_a;
};

static void XeeGradientCalc(void *infoptr,const float *in,float *out)
{
	struct XeeGradientInfo *info=(struct XeeGradientInfo *)infoptr;
	float t=*in;

	*out++=info->start_r*(1-t)+info->end_r*t;
	*out++=info->start_g*(1-t)+info->end_g*t;
	*out++=info->start_b*(1-t)+info->end_b*t;
	*out++=info->start_a*(1-t)+info->end_a*t;
}

static void XeeGradientFree(void *infoptr)
{
	free(infoptr);
}

CGShadingRef XeeMakeGradient(NSColor *startcol,NSColor *endcol,NSPoint start,NSPoint end)
{
	static const float input_value_range[2]={0,1};
	static const float output_value_ranges[8]={0,1,0,1,0,1,0,1};
	static const CGFunctionCallbacks callbacks={0,&XeeGradientCalc,&XeeGradientFree}; 

	CGShadingRef shading=NULL;

	CGColorSpaceRef colorspace=CGColorSpaceCreateDeviceRGB();
	if(colorspace)
	{
		struct XeeGradientInfo *info=malloc(sizeof(struct XeeGradientInfo));
		if(info)
		{
			NSColor *devstart=[startcol colorUsingColorSpaceName:NSDeviceRGBColorSpace];
			NSColor *devend=[endcol colorUsingColorSpaceName:NSDeviceRGBColorSpace];

			info->start_r=[devstart redComponent];
			info->start_g=[devstart greenComponent];
			info->start_b=[devstart blueComponent];
			info->start_a=[devstart alphaComponent];
			info->end_r=[devend redComponent];
			info->end_g=[devend greenComponent];
			info->end_b=[devend blueComponent];
			info->end_a=[devend alphaComponent];

			CGFunctionRef func=CGFunctionCreate(info,1,input_value_range,4,output_value_ranges,&callbacks);
			if(func)
			{
				shading=CGShadingCreateAxial(colorspace,CGPointMake(start.x,start.y),CGPointMake(end.x,end.y),func,FALSE,FALSE);

				info=NULL; // inhibit freeing
				CGFunctionRelease(func);
			}
			free(info);
		}
		CGColorSpaceRelease(colorspace);
	}

	return shading;
}



void XeeDrawRoundedBar(NSRect rect)
{
	NSBezierPath *path=[NSBezierPath bezierPath];
	[path setLineCapStyle:NSRoundLineCapStyle];
	[path setLineWidth:rect.size.height-3];
	float offs=rect.size.height/2.0;
	float x=rect.origin.x+offs+2;
	float y=rect.origin.y+offs;
	[path moveToPoint:NSMakePoint(x,y)];
	[path lineToPoint:NSMakePoint(x+rect.size.width-2*offs-4,y)];
	[path stroke];
}



@implementation NSColor (XeeGLAdditions)

-(void)glSet
{
	NSColor *rgb=[self colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	glColor4f([rgb redComponent],[rgb greenComponent],[rgb blueComponent],[rgb alphaComponent]);
}

-(void)glSetWithAlpha:(float)alpha
{
	NSColor *rgb=[self colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	glColor4f([rgb redComponent],[rgb greenComponent],[rgb blueComponent],alpha);
}

-(void)glSetForClear
{
	NSColor *rgb=[self colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	glClearColor([rgb redComponent],[rgb greenComponent],[rgb blueComponent],[rgb alphaComponent]);
}

@end
