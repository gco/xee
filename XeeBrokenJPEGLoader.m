#import "XeeBrokenJPEGLoader.h"



@implementation XeeBrokenJPEGImage

+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;
{
	const unsigned char *head=[block bytes];
	int len=[block length];

	NSString *ext=[[name pathExtension] lowercaseString];
	if([ext isEqual:@"jpg"]||[ext isEqual:@"jpeg"]||[ext isEqual:@"jpe"]||[attributes fileHFSTypeCode]=='JPEG')
	{
		for(int i=1;i<len-1;i++) if(head[i]==0xff&&head[i+1]==0xd8) return YES;
	}

	return NO;
}

-(SEL)initLoader
{
	XeeFileHandle *fh=[self fileHandle];
	uint8 prev=0;
	for(;;)
	{
		uint8 b=[fh readUInt8];
		if(prev==0xff&&b==0xd8) break;
		prev=b;
	}
	FILE *fp=[fh filePointer];
	ungetc(0xd8,fp);
	ungetc(0xff,fp);

	return [super initLoader];
}

-(int)losslessSaveFlags
{
	return 0; // Lossless saver isn't fixed to handle these files yet.
}

@end
