#import "XeeEXIFParser.h"
#import "XeeProperties.h"


@implementation XeeEXIFParser

-(id)initWithBuffer:(const uint8_t *)exifdata length:(int)len
{
	return [self initWithBuffer:(uint8_t *)exifdata length:len mutable:NO];
}

-(id)initWithBuffer:(uint8_t *)exifdata length:(int)len mutable:(BOOL)mutable
{
	if(self=[super init])
	{
		if(mutable) data=exifdata;
		else data=NULL;

		dataobj=nil;

		exiftags=exifparse(exifdata,len);
		if(exiftags)
		{
			return self;
		}
		[self release];
	}
	return nil;
}

-(id)initWithData:(NSData *)dataobject
{
	if(self=[self initWithBuffer:(void *)[dataobject bytes] length:[dataobject length] mutable:NO])
	{
		dataobj=[dataobject retain];
	}
	return self;
}

-(void)dealloc
{
	exiffree(exiftags);
	[dataobj release];
	[super dealloc];
}



-(NSString *)stringForTag:(XeeEXIFTag)tag set:(XeeEXIFTagSet)set
{
	struct exifprop *prop=[self exifPropForTag:tag set:set];
	if(!prop) return nil;

	if(prop->str) return [NSString stringWithCString:prop->str encoding:NSISOLatin1StringEncoding];
	else return [NSString stringWithFormat:@"%d",prop->value];
}

-(int)integerForTag:(XeeEXIFTag)tag set:(XeeEXIFTagSet)set
{
	struct exifprop *prop=[self exifPropForTag:tag set:set];
	if(!prop) return 0;

	return prop->value;
}

-(XeeRational)rationalForTag:(XeeEXIFTag)tag set:(XeeEXIFTagSet)set
{
	struct exifprop *prop=[self exifPropForTag:tag set:set];
	if(!prop) return XeeZeroRational;

	if(exiftags->md.order==BIG) return XeeMakeRational(XeeBEInt32(prop->valueptr),XeeBEInt32(prop->valueptr+4));
	else return XeeMakeRational(XeeLEInt32(prop->valueptr),XeeLEInt32(prop->valueptr+4));
}

-(BOOL)setShort:(int)val forTag:(XeeEXIFTag)tag set:(XeeEXIFTagSet)set
{
	if(!data) return NO;
	struct exifprop *prop=[self exifPropForTag:tag set:set];
	if(!prop) return NO;

	if(exiftags->md.order==BIG) XeeSetBEInt16(prop->valueptr,val);
	else XeeSetLEInt16(prop->valueptr,val);

	return YES;
}

-(BOOL)setLong:(int)val forTag:(XeeEXIFTag)tag set:(XeeEXIFTagSet)set
{
	if(!data) return NO;
	struct exifprop *prop=[self exifPropForTag:tag set:set];
	if(!prop) return NO;

	if(exiftags->md.order==BIG) XeeSetBEInt32(prop->valueptr,val);
	else XeeSetLEInt32(prop->valueptr,val);

	return YES;
}

-(BOOL)setRational:(XeeRational)val forTag:(XeeEXIFTag)tag set:(XeeEXIFTagSet)set
{
	if(!data) return NO;
	struct exifprop *prop=[self exifPropForTag:tag set:set];
	if(!prop) return NO;

	if(exiftags->md.order==BIG)
	{
		XeeSetBEInt32(prop->valueptr,XeeRationalNumerator(val));
		XeeSetBEInt32(prop->valueptr+4,XeeRationalDenominator(val));
	}
	else
	{
		XeeSetLEInt32(prop->valueptr,XeeRationalNumerator(val));
		XeeSetLEInt32(prop->valueptr+4,XeeRationalDenominator(val));
	}

	return YES;
}

-(struct exifprop *)exifPropForTag:(XeeEXIFTag)tag set:(XeeEXIFTagSet)set
{
	struct exiftag *tagset;
	switch(set)
	{
		case XeeStandardTagSet: tagset=tags; break;
		default: return NULL;
	}

	for(struct exifprop *prop=exiftags->props;prop;prop=prop->next)
	if(prop->tagset==tagset&&prop->tag==tag) return prop;

	return NULL;
}

-(NSArray *)propertyArray
{
	NSMutableArray *array=[NSMutableArray array];
	NSMutableArray *cameraprops=[NSMutableArray array];
	NSMutableArray *imageprops=[NSMutableArray array];
	NSMutableArray *otherprops=[NSMutableArray array];

	for(struct exifprop *prop=exiftags->props;prop;prop=prop->next)
	{
		NSMutableArray *props;
		switch(prop->lvl)
		{
			case ED_CAM: case ED_PAS: props=cameraprops; break;
			case ED_IMG: props=imageprops; break;
			case ED_VRB: case ED_OVR: case ED_BAD: props=otherprops; break;
			default: props=nil; break;
		}

		// Could use some localizing, maybe?
		id value;
		if(prop->str) value=[NSString stringWithCString:prop->str encoding:NSISOLatin1StringEncoding];
		else value=[NSNumber numberWithInt:prop->value];

		NSString *label=[NSString stringWithCString:prop->descr?prop->descr:prop->name encoding:NSISOLatin1StringEncoding];

		[props addObject:[XeePropertyItem itemWithLabel:label value:value]];
	}

	if([cameraprops count])
	{
		[array addObject:[XeePropertyItem itemWithLabel:
		NSLocalizedString(@"EXIF camera properties",@"EXIF camera properties section title")
		value:cameraprops identifier:@"exif.camera"]];
	}

	if([imageprops count])
	{
		[array addObject:[XeePropertyItem itemWithLabel:
		NSLocalizedString(@"EXIF image properties",@"EXIF image properties section title")
		value:imageprops identifier:@"exif.image"]];
	}

	if([otherprops count])
	{
		[array addObject:[XeePropertyItem itemWithLabel:
		NSLocalizedString(@"EXIF other properties",@"EXIF other properties section title")
		value:otherprops identifier:@"exif.other"]];
	}

	return array;
}

/*EXIF camera properties
Equipment Make	Canon
Camera Model	Canon DIGITAL IXUS 800 IS
Maximum Lens Aperture	f/2.8
Sensing Method	One-Chip Color Area
Lens Size	5.80 - 23.20 mm
Firmware Version	Firmware Version 1.00

EXIF image properties
Image Orientation	Left-Hand, Bottom
Horizontal Resolution	180 dpi
Vertical Resolution	180 dpi
Image Created	2007:10:27 23:22:13
Exposure Time	0.3 sec
F-Number	f/2.8
Lens Aperture	f/2.8
Exposure Bias	0 EV
Flash	No Flash, Compulsory
Focal Length	5.80 mm
Color Space Information	sRGB
Image Width	2816
Image Height	2112
Rendering	Normal
Exposure Mode	Auto
Scene Capture Type	Standard
Focus Type	Auto
Metering Mode	Evaluative
Sharpness	Normal
Saturation	Normal
Contrast	Normal
Shooting Mode	Manual
Image Size	Large
Focus Mode	Single
Drive Mode	Single
Flash Mode	Off
Compression Setting	Fine
Macro Mode	Normal
Subject Distance	1.880 m
White Balance	Auto
Exposure Compensation	3
Sensor ISO Speed	160
Image Number	100-1206

EXIF other properties
Resolution Unit	i
Chrominance Comp Positioning	Centered
Exif IFD Pointer	196
Compression Scheme	JPEG Compression (Thumbnail)
Horizontal Resolution	180 dpi
Vertical Resolution	180 dpi
Resolution Unit	i
Offset to JPEG SOI	5108
Bytes of JPEG Data	5870
Exif Version	2.20
Image Generated	2007:10:27 23:22:13
Image Digitized	2007:10:27 23:22:13
Meaning of Each Comp	Unknown
Image Compression Mode	3
Shutter Speed	1/3 sec
Metering Mode	Pattern
Focal Plane Horiz Resolution	12515 dpi
Focal Plane Vert Resolution	12497 dpi
Focal Plane Res Unit	i
File Source	Digital Still Camera
White Balance	Auto
Digital Zoom Ratio	1
Base Zoom Resolution	2816
Zoomed Resolution	2816
Exposure Mode	Easy Shooting
ISO Speed Rating	Unknown
Digital Zoom	None
Self-Timer Length	0 sec
Canon Tag1 Length	92
Flash Bias	0.00 EV
Sequence Number	0
Canon Tag4 Length	68
Image Type	IMG:DIGITAL IXUS 800 IS JPEG
Owner Name	*/


@end
