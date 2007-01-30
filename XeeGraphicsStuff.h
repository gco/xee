#import <Cocoa/Cocoa.h>

CGShadingRef XeeMakeGradient(NSColor *startcol,NSColor *endcol,NSPoint start,NSPoint end);

void XeeDrawRoundedBar(NSRect rect);


@interface NSColor (XeeGLAdditions)

-(void)glSet;
-(void)glSetWithAlpha:(float)alpha;
-(void)glSetForClear;

@end
