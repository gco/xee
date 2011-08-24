#import <Cocoa/Cocoa.h>
#import "XeeTypes.h"

@class XeeFileHandle;

void XeeUnPackBitsFromMemory(uint8 *src,uint8 *dest,int srcsize,int destsize,int stride);
void XeeUnPackBitsFromFile(XeeFileHandle *fh,uint8 *dest,int destsize,int stride);
NSString *XeeNSStringFromByteBuffer(void *buffer,int len);
