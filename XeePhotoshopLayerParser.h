#import <Cocoa/Cocoa.h>

#import "XeeImage.h"

#import <XADMaster/CSHandle.h>

@class XeePhotoshopImage;

@interface XeePhotoshopLayerParser:NSObject
{
	CSHandle *handle;
	XeePhotoshopImage *parent;
	NSMutableArray *props;
	NSMutableDictionary *channeloffs;
	int mode,depth;
	int width,height,channels,compression;
	off_t dataoffs,totalsize;
}

+(NSArray *)parseLayersFromHandle:(CSHandle *)fh parentImage:(XeePhotoshopImage *)parent alphaFlag:(BOOL *)hasalpha;

-(id)initWithHandle:(CSHandle *)fh parentImage:(XeePhotoshopImage *)parentimage;
-(void)dealloc;

-(void)setDataOffset:(off_t)offset;
-(off_t)totalSize;

-(XeeImage *)image;
-(CSHandle *)handleForNumberOfChannels:(int)requiredchannels;
-(CSHandle *)handleForChannel:(int)channel;

-(BOOL)hasAlpha;

@end
