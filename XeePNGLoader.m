#import "XeePNGLoader.h"


int is_png_gray_palette(png_structp png,png_infop info);

@implementation XeePNGImage

static void XeePNGReadData(png_structp png,png_bytep buf,png_size_t len)
{
	[(CSHandle *)png->io_ptr readBytes:len toBuffer:buf];
}

+(NSArray *)fileTypes
{
	return [NSArray arrayWithObjects:@"png",@"'PNG '",@"'PNGf'",nil];
}

+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;
{
	if([block length]>8&&png_check_sig((unsigned char *)[block bytes],8)) return YES;
	return NO;
}

-(SEL)initLoader
{
	png=NULL;
	info=NULL;

	png=png_create_read_struct(PNG_LIBPNG_VER_STRING,NULL,NULL,NULL);
	if(!png) return NULL;

	info=png_create_info_struct(png);
	if(!info) return NULL;

	if(setjmp(png_jmpbuf(png))) return NULL;

	png_set_read_fn(png,[self handle],XeePNGReadData);
	png_read_info(png,info); // read all PNG info up to image data

	width=png_get_image_width(png,info);
	height=png_get_image_height(png,info);
	bit_depth=png_get_bit_depth(png,info);
	color_type=png_get_color_type(png,info);

	switch(color_type)
	{
		case PNG_COLOR_TYPE_GRAY: [self setDepthGrey:bit_depth]; break;
		case PNG_COLOR_TYPE_GRAY_ALPHA: [self setDepthGrey:bit_depth alpha:YES floating:NO]; break;
		case PNG_COLOR_TYPE_PALETTE: [self setDepthIndexed:(1<<bit_depth)]; break;
		case PNG_COLOR_TYPE_RGB: [self setDepthRGB:bit_depth]; break;
		case PNG_COLOR_TYPE_RGB_ALPHA: [self setDepthRGBA:bit_depth]; break;
	}

	if(color_type==PNG_COLOR_TYPE_RGB_ALPHA||color_type==PNG_COLOR_TYPE_GRAY_ALPHA||
	png_get_valid(png,info,PNG_INFO_tRNS))
	{
		if(png_get_valid(png,info,PNG_INFO_bKGD))
		{
			png_color_16p background;
			float scaling=(1<<bit_depth)-1;

			png_get_bKGD(png,info,&background);

			[self setBackgroundColor:[NSColor colorWithCalibratedRed:(float)background->red/scaling
			green:(float)background->green/scaling blue:(float)background->blue/scaling alpha:1]];
		}
	}

	[self setFormat:@"PNG"];

	current_line=0;
	current_pass=0;

	return @selector(startLoading);
}

-(void)deallocLoader
{
	if(info) png_destroy_read_struct(&png,&info,NULL);
	if(png) png_destroy_read_struct(&png,NULL,NULL);
}


-(SEL)startLoading
{
    if(setjmp(png_jmpbuf(png))) return NULL;

	BOOL hasalpha=NO,hascolor=NO;
	BOOL use16bit=![[NSUserDefaults standardUserDefaults] boolForKey:@"pngStrip16Bit"];

	switch(color_type)
	{
		case PNG_COLOR_TYPE_GRAY:
			if(bit_depth<8) png_set_expand(png); // expand low-bit-depth grayscale images to 8 bits
		break;

		case PNG_COLOR_TYPE_GRAY_ALPHA:
			hasalpha=YES;
		break;

		case PNG_COLOR_TYPE_PALETTE:
			if(is_png_gray_palette(png,info))
			{
				png_set_rgb_to_gray_fixed(png,1,-1,-1); // triggers a bug in libpng 1.2.8, needs patched libpng
			}
			else
			{
				png_set_expand(png); // expand palette images to RGB
				hascolor=YES;
			}
		break;

		case PNG_COLOR_TYPE_RGB:
			hascolor=YES;
		break;

		case PNG_COLOR_TYPE_RGB_ALPHA:
			hascolor=YES;
			hasalpha=YES;
		break;
	}

	if(png_get_valid(png,info,PNG_INFO_tRNS))
	{
		png_set_expand(png); // expand transparency to RGBA/LA
		hasalpha=YES;
	}

	int type;

	if(bit_depth==16&&use16bit)
	{
		#ifndef __BIG_ENDIAN__
		if(bit_depth==16) png_set_swap(png);
		#endif

		if(hascolor)
		{
			if(hasalpha) type=XeeBitmapTypeRGBA16;
			else type=XeeBitmapTypeRGB16;
		}
		else
		{
			if(hasalpha) type=XeeBitmapTypeLumaAlpha16;
			else type=XeeBitmapTypeLuma16;
		}
	}
	else
	{
		if(bit_depth==16) png_set_strip_16(png);

		if(hascolor)
		{
			if(hasalpha)
			{
				png_set_swap_alpha(png); // make ARGB values instead of RGBA
				type=XeeBitmapTypeARGB8;
			}
			else type=XeeBitmapTypeRGB8;
		}
		else
		{
			if(hasalpha) type=XeeBitmapTypeLumaAlpha8;
			else type=XeeBitmapTypeLuma8;
		}
	}

//	if(png_get_gAMA(png_ptr,info_ptr,&gamma)) png_set_gamma(png_ptr,display_exponent,gamma);

	interlace_passes=png_set_interlace_handling(png);
	png_read_update_info(png,info);

	if(![self allocWithType:type width:width height:height]) return NULL;

	if(bytesperrow<png_get_rowbytes(png,info)) return NULL; // shouldn't happen

//	if(comments) [properties addObject:[XeePropertyItem itemWithLabel:
//	NSLocalizedString(@"File comments",@"File comments section title")
//	value:comments]];


	return @selector(loadImage);
}

-(SEL)loadImage
{
    if(setjmp(png_jmpbuf(png))) return NULL;

	while(!stop)
	{
		unsigned char *row=data;
		row+=current_line*bytesperrow;

		png_read_row(png,row,NULL);

		current_line++;
		if(current_pass==interlace_passes-1) [self setCompletedRowCount:current_line];

		if(current_line>=height)
		{
			current_line=0;
			current_pass++;
			if(current_pass>=interlace_passes) return @selector(finishLoading);
		}
	}

	return @selector(loadImage);
}

-(SEL)finishLoading
{
	loaded=YES;
    if(setjmp(png_jmpbuf(png))) return NULL;

	png_read_end(png,info);

	png_textp comments;
	int num_comments=png_get_text(png,info,&comments,NULL);
	if(!num_comments) return NULL;

	NSMutableArray *commentarray=[NSMutableArray array];
	[properties addObject:[XeePropertyItem itemWithLabel:
	NSLocalizedString(@"File comments",@"File comments section title")
	value:commentarray identifier:@"common.comments"]];

	for(int i=0;i<num_comments;i++)
	{
		NSString *key;
		NSMutableString *text;

		key=[NSString stringWithCString:comments[i].key encoding:NSISOLatin1StringEncoding];

		if(comments[i].lang_key)
		{
			NSString *langkey=[NSString stringWithCString:comments[i].lang_key encoding:NSUTF8StringEncoding];
			if(langkey&&[langkey length]) key=[NSString stringWithFormat:@"%@ (%@)",key,langkey];
			text=[NSMutableString stringWithCString:comments[i].text encoding:NSUTF8StringEncoding];
		}
		else text=[NSMutableString stringWithCString:comments[i].text encoding:NSISOLatin1StringEncoding];

		[commentarray addObjectsFromArray:[XeePropertyItem itemsWithLabel:key textValue:text]];
	}

	[self triggerPropertyChangeAction];

	return NULL;
}

@end


int is_png_gray_palette(png_structp png,png_infop info)
{
	if(png_get_valid(png,info,PNG_INFO_tRNS)) return 0;
	if(png_get_color_type(png,info)!=PNG_COLOR_TYPE_PALETTE) return 0;

	png_colorp pal;
	int num;

	png_get_PLTE(png,info,&pal,&num);
	for(int i=0;i<num;i++) if(pal[i].red!=pal[i].green||pal[i].red!=pal[i].blue) return 0;

	return 1;
}
