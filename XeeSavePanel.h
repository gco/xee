#import <Cocoa/Cocoa.h>

#import "XeeSimpleLayout.h"
#import "XeeSimpleLayout.h"

@class XeeImage;

@interface XeeSavePanel:NSSavePanel
{
	XeeImage *image;
	NSArray *savers;
	XeeSLPages *formats;
	XeeSimpleLayout *view;

	NSTextView *textview;

	BOOL wasanimating;
}

+(void)runSavePanelForImage:(XeeImage *)image window:(NSWindow *)window;

-(id)initWithImage:(XeeImage *)img;
-(void)dealloc;

-(void)beginSheetForWindow:(NSWindow *)window;

-(void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)res contextInfo:(void *)info;
-(void)xeeSLUpdated:(XeeSimpleLayout *)alsoview;

-(NSString *)updateExtension:(NSString *)filename;
-(void)selectNamePart;

@end
