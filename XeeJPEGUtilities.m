#import "XeeJPEGUtilities.h"
#import "jerror.h"


static void XeeJPEGErrorExit(j_common_ptr cinfo)
{
	char buffer[JMSG_LENGTH_MAX];
	(*cinfo->err->format_message)(cinfo,buffer);
	[NSException raise:@"XeeLibJPEGException" format:@"libjpeg error: %s",buffer];
}

static void XeeJPEGEmitMessage(j_common_ptr cinfo,int msg_level) // Ignore warnings for now
{
}

static void XeeJPEGResetErrorMgr(j_common_ptr cinfo)
{
}

struct jpeg_error_mgr *XeeJPEGErrorManager(struct jpeg_error_mgr *err)
{
	jpeg_std_error(err);
	err->error_exit=XeeJPEGErrorExit;
	err->emit_message=XeeJPEGEmitMessage;
	err->reset_error_mgr=XeeJPEGResetErrorMgr;
	return err;
}


/*
static void XeeMemoryJPEGInitSource(j_decompress_ptr cinfo) {}

static boolean XeeMemoryJPEGFillInputBuffer(j_decompress_ptr cinfo)
{
	static uint8_t eoi[2]={0xff,0xd9};
	cinfo->src->next_input_byte=eoi;
	cinfo->src->bytes_in_buffer=2;
	return TRUE;
}

static void XeeMemoryJPEGSkipInputData(j_decompress_ptr cinfo,long num)
{
	if(num>0)
	{
		cinfo->src->next_input_byte+=num;
		cinfo->src->bytes_in_buffer-=num;
	}
}

static void XeeMemoryJPEGTermSource(j_decompress_ptr cinfo) {}

struct jpeg_source_mgr *XeeMemoryJPEGSourceManager(struct jpeg_source_mgr *src,const void *bytes,int len)
{
	src->init_source=XeeMemoryJPEGInitSource;
	src->fill_input_buffer=XeeMemoryJPEGFillInputBuffer;
	src->skip_input_data=XeeMemoryJPEGSkipInputData;
	src->resync_to_restart=jpeg_resync_to_restart;
	src->term_source=XeeMemoryJPEGTermSource;
	src->bytes_in_buffer=len;
	src->next_input_byte=bytes;
	return src;
}
*/



static void XeeJPEGInitSource(j_decompress_ptr cinfo) {}

static boolean XeeJPEGFillInputBuffer(j_decompress_ptr cinfo)
{
	struct XeeJPEGSource *src=(struct XeeJPEGSource *)cinfo->src;

	int actual=[src->handle readAtMost:XeeJPEGSourceBufferSize toBuffer:src->buffer];
	if(actual)
	{
		src->pub.next_input_byte=src->buffer;
		src->pub.bytes_in_buffer=actual;
	}
	else
	{
		src->buffer[0]=0xff;
		src->buffer[1]=JPEG_EOI;
		src->pub.next_input_byte=src->buffer;
		src->pub.bytes_in_buffer=2;
	}
	return TRUE;
}

static void XeeJPEGSkipInputData(j_decompress_ptr cinfo,long num)
{
	struct XeeJPEGSource *src=(struct XeeJPEGSource *)cinfo->src;

	if(num>0)
	{
		while (num>src->pub.bytes_in_buffer)
		{
			num-=src->pub.bytes_in_buffer;
			src->pub.fill_input_buffer(cinfo);
		}
		src->pub.next_input_byte+=num;
		src->pub.bytes_in_buffer-=num;
	}
}

static void XeeJPEGTermSource(j_decompress_ptr cinfo) {}

struct jpeg_source_mgr *XeeJPEGSourceManager(struct XeeJPEGSource *src,CSHandle *handle)
{
	src->pub.init_source=XeeJPEGInitSource;
	src->pub.fill_input_buffer=XeeJPEGFillInputBuffer;
	src->pub.skip_input_data=XeeJPEGSkipInputData;
	src->pub.resync_to_restart=jpeg_resync_to_restart;
	src->pub.term_source=XeeJPEGTermSource;
	src->pub.bytes_in_buffer=0;
	src->pub.next_input_byte=NULL;

	src->handle=handle;

	return &src->pub;
}



void XeeJPEGPlanarToChunky(uint8_t *row,uint8_t *y_row,uint8_t *cb_row,uint8_t *cr_row,int width)
{
	#ifdef __BIG_ENDIAN__
	#define MOVE(val,from,to) ( ( ((to)>(from)) ? ((val)>>(((to)-(from))*8)) : (((val)<<((from)-(to))*8)) ) & (0xff<<(24-(to)*8)) )
	#else
	#define MOVE(val,from,to) ( ( ((to)>(from)) ? ((val)<<(((to)-(from))*8)) : (((val)>>((from)-(to))*8)) ) & (0xff<<((to)*8)) )
	#endif

	int n=(width+1)/4;
	uint32_t *row_l=(uint32_t *)row;
	uint32_t *y_l=(uint32_t *)y_row;
	uint32_t *cb_l=(uint32_t *)cb_row;
	uint32_t *cr_l=(uint32_t *)cr_row;
	uint32_t y,cb,cr;

	for(;;)
	{
		if(!n--) break;

		y=*y_l++;
		cb=*cb_l++;
		cr=*cr_l++;
		*row_l++=MOVE(cb,0,0)|MOVE(y,0,1)|MOVE(cr,0,2)|MOVE(y,1,3);
		*row_l++=MOVE(cb,1,0)|MOVE(y,2,1)|MOVE(cr,1,2)|MOVE(y,3,3);

		if(!n--) break;

		y=*y_l++;
		*row_l++=MOVE(cb,2,0)|MOVE(y,0,1)|MOVE(cr,2,2)|MOVE(y,1,3);
		*row_l++=MOVE(cb,3,0)|MOVE(y,2,1)|MOVE(cr,3,2)|MOVE(y,3,3);
	}

	if((width+1)&2)
	{
		uint8_t *row_b=(uint8_t *)row_l;
		uint8_t *y_b=(uint8_t *)y_l;
		uint8_t *cb_b=cb_row+(width-1)/2;
		uint8_t *cr_b=cr_row+(width-1)/2;
		*row_b++=*cb_b;
		*row_b++=*y_b++;
		*row_b++=*cr_b;
		*row_b=*y_b;
	}
}

BOOL XeeTestJPEGMarker(struct jpeg_marker_struct *marker,int n,int ident_len,void *ident_data)
{
	if(marker->marker!=JPEG_APP0+n) return NO;
	if(marker->data_length<ident_len) return NO;
	if(memcmp(marker->data,ident_data,ident_len)) return NO;
	return YES;
}

