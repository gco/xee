#import "XeeController.h"

@interface XeeController (ImageActions)

-(IBAction)copy:(id)sender;
-(void)pasteboard:(NSPasteboard *)pboard provideDataForType:(NSString *)type;
-(void)pasteboardChangedOwner:(NSPasteboard *)pboard;

-(IBAction)save:(id)sender;
-(void)saveTask:(XeeImage *)saveimage;
-(void)finishSave:(XeeImage *)saveimage;
-(IBAction)saveAs:(id)sender;

-(IBAction)frameSkipNext:(id)obj;
-(IBAction)frameSkipPrev:(id)obj;
-(IBAction)toggleAnimation:(id)obj;

-(IBAction)zoomIn:(id)sender;
-(IBAction)zoomOut:(id)sender;
-(IBAction)zoomActual:(id)sender;
-(IBAction)zoomFit:(id)sender;

-(void)setOrientation:(int)orientation;
-(IBAction)rotateCW:(id)sender;
-(IBAction)rotateCCW:(id)sender;
-(IBAction)rotate180:(id)sender;
-(IBAction)autoRotate:(id)sender;
-(IBAction)rotateActual:(id)sender;
-(IBAction)mirrorHorizontal:(id)sender;
-(IBAction)mirrorVertical:(id)sender;

-(void)setCroppingRect:(NSRect)rect;
-(BOOL)isCropping;
-(IBAction)crop:(id)sender;

@end

