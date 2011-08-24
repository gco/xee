#import "XeeEXIFReader.h"

#import "exiftags/exifint.h"

@implementation XeeEXIFReader

-(id)initWithBuffer:(void *)buffer length:(int)length { return [self initWithBuffer:buffer length:length mutable:NO]; }

-(id)initWithBuffer:(void *)buffer length:(int)length mutable:(BOOL)mutable
{
	if(self=[super init])
	{
		exiftags=exifparse(buffer,length);
		if(mutable) data=buffer;
		else data=NULL;

		if(exiftags&&exiftags->props) return self;

		[self release];
	}
	return nil;
}

-(id)initWithData:(NSData *)exifdata
{
	return [self initWithBuffer:(void *)[exifdata bytes] length:[exifdata length] mutable:NO];
}

/*-(id)initWithMutableData:(NSMutableData *)exifdata
{
	return [self initWithBuffer:(void *)[exifdata bytes] length:[exifdata length] mutable:YES];
}*/

-(void)dealloc
{
	if(exiftags) exiffree(exiftags);
	[super dealloc];
}



-(NSString *)stringForKey:(NSString *)key
{ return [self stringForExifProp:[self exifPropForKey:key]]; }

-(NSString *)stringForTag:(EXIFTag)tag set:(EXIFTagSet)set
{ return [self stringForExifProp:[self exifPropForTag:tag set:set]]; }

-(NSString *)stringForExifProp:(struct exifprop *)prop
{
	if(!prop) return nil;
	if(prop->str) return [NSString stringWithUTF8String:prop->str];
	else return [NSString stringWithFormat:@"%d",prop->value];
}



-(int)integerForKey:(NSString *)key
{ return [self integerForExifProp:[self exifPropForKey:key]]; }

-(int)integerForTag:(EXIFTag)tag set:(EXIFTagSet)set
{ return [self integerForExifProp:[self exifPropForTag:tag set:set]]; }

-(int)integerForExifProp:(struct exifprop *)prop
{
	if(!prop) return 0;
	return prop->value;
}



-(EXIFRational)rationalForKey:(NSString *)key
{ return [self rationalForExifProp:[self exifPropForKey:key]]; }

-(EXIFRational)rationalForTag:(EXIFTag)tag set:(EXIFTagSet)set
{ return [self rationalForExifProp:[self exifPropForTag:tag set:set]]; }

-(EXIFRational)rationalForExifProp:(struct exifprop *)prop
{
	if(!prop) return EXIFInvalidRational;

	switch(exiftags->md.order)
	{
		case BIG: return EXIFMakeRational(read_be_int32(data+prop->value+6),read_be_int32(data+prop->value+10));
		case LITTLE: return EXIFMakeRational(read_le_int32(data+prop->value+6),read_le_int32(data+prop->value+10));
	}
	return EXIFInvalidRational;
}



-(BOOL)setShort:(int)value forKey:(NSString *)key
{ return [self setShort:value forExifProp:[self exifPropForKey:key]]; }

-(BOOL)setShort:(int)value forTag:(EXIFTag)tag set:(EXIFTagSet)set
{ return [self setShort:value forExifProp:[self exifPropForTag:tag set:set]]; }

-(BOOL)setShort:(int)value forExifProp:(struct exifprop *)prop
{
	if(!data||!prop) return NO;
	prop->value=value;
	switch(exiftags->md.order)
	{
		case BIG: write_be_int16(prop->field->value,value); break;
		case LITTLE: write_le_int16(prop->field->value,value); break;
	}
	return YES;
}



-(BOOL)setLong:(int)value forKey:(NSString *)key
{ return [self setLong:value forExifProp:[self exifPropForKey:key]]; }

-(BOOL)setLong:(int)value forTag:(EXIFTag)tag set:(EXIFTagSet)set
{ return [self setLong:value forExifProp:[self exifPropForTag:tag set:set]]; }

-(BOOL)setLong:(int)value forExifProp:(struct exifprop *)prop
{
	if(!data||!prop) return NO;
	prop->value=value;
	switch(exiftags->md.order)
	{
		case BIG: write_be_int32(prop->field->value,value); break;
		case LITTLE: write_le_int32(prop->field->value,value); break;
	}
	return YES;
}



-(BOOL)setRational:(EXIFRational)value forKey:(NSString *)key
{ return [self setRational:value forExifProp:[self exifPropForKey:key]]; }

-(BOOL)setRational:(EXIFRational)value forTag:(EXIFTag)tag set:(EXIFTagSet)set
{ return [self setRational:value forExifProp:[self exifPropForTag:tag set:set]]; }

-(BOOL)setRational:(EXIFRational)value forExifProp:(struct exifprop *)prop
{
	if(!data||!prop) return NO;
	switch(exiftags->md.order)
	{
		case BIG:
			write_be_int32(data+prop->value+6,value.numerator);
			write_be_int32(data+prop->value+10,value.denominator);
		break;
		case LITTLE:
			write_le_int32(data+prop->value+6,value.numerator);
			write_le_int32(data+prop->value+10,value.denominator);
		break;
	}
	return YES;
}



-(struct exifprop *)exifPropForKey:(NSString *)key
{
	struct exifprop *prop=exiftags->props;
	const char *ckey=[key UTF8String];
	while(prop)
	{
		if(!strcmp(ckey,prop->name)) return prop;
		prop=prop->next;
	}
	return NULL;
}

-(struct exifprop *)exifPropForTag:(EXIFTag)tag set:(EXIFTagSet)set
{
	struct exifprop *prop=exiftags->props;
	struct exiftag *tagset;

	switch(set)
	{
		case EXIFStandardTagSet: tagset=tags; break;
		default: return NULL;
	}

	while(prop)
	{
		if(prop->tag==tag/*&&prop->tagset==tagset*/) return prop;
		prop=prop->next;
	}
	return NULL;
}



-(NSArray *)propertyArray
{
	struct exifprop *prop=exiftags->props;

	NSMutableArray *camprops=[NSMutableArray array];
	NSMutableArray *imageprops=[NSMutableArray array];
	NSMutableArray *otherprops=[NSMutableArray array];

	while(prop)
	{
		const char *name=prop->descr?prop->descr:prop->name;
		NSString *key=[NSString stringWithUTF8String:name];

		id value;
		if(prop->str) value=[NSString stringWithUTF8String:prop->str];
		else value=[NSNumber numberWithInt:prop->value];

		switch(prop->lvl)
		{
			case ED_PAS:
			case ED_CAM:
				[camprops addObject:key];
				[camprops addObject:value];
			break;
			case ED_IMG:
				[imageprops addObject:key];
				[imageprops addObject:value];
			break;
			case ED_OVR:
			case ED_BAD:
			case ED_VRB:
				[otherprops addObject:key];
				[otherprops addObject:value];
			break;
			//case ED_UNK:
			//break;
		}

		prop=prop->next;
	}

	NSMutableArray *proparray=[NSMutableArray array];

	if([camprops count])
	{
		[proparray addObject:@"EXIF camera properties"];
		[proparray addObject:camprops];
	}

	if([imageprops count])
	{
		[proparray addObject:@"EXIF image properties"],
		[proparray addObject:imageprops];
	}

	if([otherprops count])
	{
		[proparray addObject:@"EXIF other properties"],
		[proparray addObject:otherprops];
	}

	return proparray;
}

@end
