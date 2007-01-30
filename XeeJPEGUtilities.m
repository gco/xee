#import "XeeJPEGUtilities.h"



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



static void XeeMemoryJPEGInitSource(j_decompress_ptr cinfo) {}

static boolean XeeMemoryJPEGFillInputBuffer(j_decompress_ptr cinfo)
{
	static uint8 eoi[2]={0xff,0xd9};
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



void XeeJPEGPlanarToChunky(uint8 *row,uint8 *y_row,uint8 *cb_row,uint8 *cr_row,int width)
{
	#ifdef __BIG_ENDIAN__
	#define MOVE(val,from,to) ( ( ((to)>(from)) ? ((val)>>(((to)-(from))*8)) : (((val)<<((from)-(to))*8)) ) & (0xff<<(24-(to)*8)) )
	#else
	#define MOVE(val,from,to) ( ( ((to)>(from)) ? ((val)<<(((to)-(from))*8)) : (((val)>>((from)-(to))*8)) ) & (0xff<<((to)*8)) )
	#endif

	int n=(width+1)/4;
	uint32 *row_l=(uint32 *)row;
	uint32 *y_l=(uint32 *)y_row;
	uint32 *cb_l=(uint32 *)cb_row;
	uint32 *cr_l=(uint32 *)cr_row;
	uint32 y,cb,cr;

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
		uint8 *row_b=(uint8 *)row_l;
		uint8 *y_b=(uint8 *)y_l;
		uint8 *cb_b=cb_row+(width-1)/2;
		uint8 *cr_b=cr_row+(width-1)/2;
		*row_b++=*cb_b;
		*row_b++=*y_b++;
		*row_b++=*cr_b;
		*row_b=*y_b;
	}
}