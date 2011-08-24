#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface XeePropertiesController:NSObject
{
	IBOutlet NSPanel *infopanel;
	IBOutlet WebView *infoview;
}

-(void)awakeFromNib;
-(void)frontImageDidChange:(NSNotification *)notification;
-(void)parsePropertyArray:(NSArray *)array table:(DOMElement *)table document:(DOMDocument *)document;

-(void)show;

@end
