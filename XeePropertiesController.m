#import "XeePropertiesController.h"
#import "XeeController.h"
#import "XeeImage.h"

@implementation XeePropertiesController

-(void)awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(frontImageDidChange:) name:@"XeeFrontImageDidChangeNotification" object:nil];

	[[infoview preferences] setUserStyleSheetLocation:
	[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"metadata" ofType:@"css"]]];
	[[infoview preferences] setUserStyleSheetEnabled:YES];
}

-(void)frontImageDidChange:(NSNotification *)notification
{
	DOMDocument *document=[[infoview windowScriptObject] evaluateWebScript:@"document"];
	DOMNode *body=[[document documentElement] firstChild];

	while([body firstChild]) [body removeChild:[body firstChild]];

	XeeImage *image=[notification object];
	if(image)
	{
		NSArray *properties=[image properties];

		DOMElement *table=[document createElement:@"table"];
		[self parsePropertyArray:properties table:table document:document];
		[body appendChild:table];
	}
}

-(void)parsePropertyArray:(NSArray *)array table:(DOMElement *)table document:(DOMDocument *)document
{
	NSEnumerator *enumerator=[array objectEnumerator];
	for(;;)
	{
		NSString *key=[enumerator nextObject];
		id value=[enumerator nextObject];

		if(!key||!value) return;

		if([value isKindOfClass:[NSArray class]])
		{
			DOMElement *tr=[document createElement:@"tr"];
			DOMElement *th=[document createElement:@"th"];
//			DOMElement *td=[document createElement:@"td"];
//			DOMElement *h2=[document createElement:@"h2"];
			DOMNode *text=[document createTextNode:key];
			[th setAttribute:@"colspan" :@"2"];
//			[h2 appendChild:text];
//			[td appendChild:h2];
			[th appendChild:text];
			[tr appendChild:th];
			[table appendChild:tr];
			[self parsePropertyArray:value table:table document:document];
		}
		else
		{
			DOMElement *tr=[document createElement:@"tr"];
			DOMElement *td1=[document createElement:@"td"];
			DOMElement *td2=[document createElement:@"td"];
			DOMNode *text1=[document createTextNode:key];
			DOMNode *text2=[document createTextNode:[value description]];
			[td1 appendChild:text1];
			[td2 appendChild:text2];
			[tr appendChild:td1];
			[tr appendChild:td2];
			[table appendChild:tr];
		}
	}
}

-(void)show
{
	[infopanel orderFront:nil];

	NSWindow *mainwindow=[[NSApplication sharedApplication] mainWindow];
	if(mainwindow)
	{
		id delegate=[mainwindow delegate];
		if([delegate isKindOfClass:[XeeController class]])
		{
			XeeImage *image=[(XeeController *)delegate image];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"XeeFrontImageDidChangeNotification" object:image];
		}
	}
}

@end
