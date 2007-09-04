#import <Cocoa/Cocoa.h>
#import "CSHandle.h"
#import "XeeImage.h"

@interface XeePhotoshopLayerParser:NSObject
{
	CSHandle *handle;
	NSMutableArray *props;
	NSMutableDictionary *channeloffs;
	int mode,depth;
	int width,height,channels,compression;
	off_t dataoffs,totalsize;
}

-(id)initWithHandle:(CSHandle *)fh mode:(int)colourmode depth:(int)bitdepth;
-(void)dealloc;

-(void)setDataOffset:(off_t)offset;
-(off_t)totalSize;

-(XeeImage *)image;
-(CSHandle *)handleForChannel:(int)channel;


-(NSArray *)propertyArray;

@end
