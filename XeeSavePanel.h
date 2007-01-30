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

	BOOL wasanimating;
}

+(void)runSavePanelForImage:(XeeImage *)image controller:(XeeController *)controller;

-(id)initWithImage:(XeeImage *)img controller:(XeeController *)cont;
-(void)dealloc;

-(void)beginSheetForWindow:(NSWindow *)window;

-(void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)res contextInfo:(void *)info;
-(void)xeeSLUpdated:(XeeSimpleLayout *)alsoview;

-(NSString *)updateExtension:(NSString *)filename;
-(void)selectNamePart;

@end
