#import "XeeFileSource.h"
#import "PDFStream.h"

@interface XeePDFSource:XeeListSource
{
	NSString *filename;
	PDFParser *parser;
}

+(NSArray *)fileTypes;

-(id)initWithFile:(NSString *)pdfname;
-(void)dealloc;

-(NSString *)windowTitle;
-(NSString *)windowRepresentedFilename;
-(BOOL)canBrowse;

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
