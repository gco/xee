#import "XeeTypes.h"
#import "libjpeg/jpeglib.h"

#import <XADMaster/CSHandle.h>

#define XeeJPEGSourceBufferSize 4096

struct XeeJPEGSource
{
	struct jpeg_source_mgr pub;
	CSHandle *handle;
	uint8_t buffer[XeeJPEGSourceBufferSize];
};

struct jpeg_error_mgr *XeeJPEGErrorManager(struct jpeg_error_mgr *err);
//struct jpeg_source_mgr *XeeMemoryJPEGSourceManager(struct jpeg_source_mgr *src,const void *bytes,int len);
struct jpeg_source_mgr *XeeJPEGSourceManager(struct XeeJPEGSource *src,CSHandle *handle);
void XeeJPEGPlanarToChunky(uint8_t *row,uint8_t *y_row,uint8_t *cb_row,uint8_t *cr_row,int width);
BOOL XeeTestJPEGMarker(struct jpeg_marker_struct *marker,int n,int ident_len,void *ident_data);
