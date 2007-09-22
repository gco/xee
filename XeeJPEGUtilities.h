#import "XeeTypes.h"
#import "CSHandle.h"
#import "libjpeg/jpeglib.h"

#define XeeJPEGSourceBufferSize 4096

struct XeeJPEGSource
{
	struct jpeg_source_mgr pub;
	CSHandle *handle;
	uint8 buffer[XeeJPEGSourceBufferSize];
};

struct jpeg_error_mgr *XeeJPEGErrorManager(struct jpeg_error_mgr *err);
//struct jpeg_source_mgr *XeeMemoryJPEGSourceManager(struct jpeg_source_mgr *src,const void *bytes,int len);
struct jpeg_source_mgr *XeeJPEGSourceManager(struct XeeJPEGSource *src,CSHandle *handle);
void XeeJPEGPlanarToChunky(uint8 *row,uint8 *y_row,uint8 *cb_row,uint8 *cr_row,int width);
BOOL XeeTestJPEGMarker(struct jpeg_marker_struct *marker,int n,int ident_len,void *ident_data);
