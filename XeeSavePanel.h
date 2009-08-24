#import <Cocoa/Cocoa.h>

@class XeeImage,XeeController,XeeSLPages,XeeSimpleLayout;

@interface XeeSavePanel:NSSavePanel
{
	XeeImage *image;
	XeeController *controller;
	NSArray *savers;
	XeeSLPages *formats;
	XeeSimpleLayout *view;

	NSTextView *textview;
	NSTextField *textfield;

	BOOL wasanimating;
}

+(void)runSavePanelForImage:(XeeImage *)image controller:(XeeController *)controller;

-(id)initWithImage:(XeeImage *)img controller:(XeeController *)cont;
-(void)dealloc;

-(void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)res contextInfo:(void *)info;
-(void)xeeSLUpdated:(XeeSimpleLayout *)alsoview;

-(NSString *)updateExtension:(NSString *)filename;
-(NSString *)filenameFieldContents;
-(void)setFilenameFieldContents:(NSString *)filename;
-(void)selectNamePart;

@end
