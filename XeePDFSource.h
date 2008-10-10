#import "XeeFileSource.h"
#import "PDFStream.h"

@interface XeePDFSource:XeeFileSource
{
	PDFParser *parser;
	NSString *filename;
}

+(NSArray *)fileTypes;

-(id)initWithFile:(NSString *)pdfname;
-(void)dealloc;

-(NSString *)representedFilename;
-(int)capabilities;

@end

@interface XeePDFEntry:XeeListEntry
{
	PDFStream *object;
	NSString *name;
	BOOL complained;
}

-(id)initWithPDFStream:(PDFStream *)stream name:(NSString *)descname;
-(void)dealloc;

-(NSString *)descriptiveName;
-(XeeImage *)produceImage;

@end
