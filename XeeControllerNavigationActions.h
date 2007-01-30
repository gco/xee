#import "XeeController.h"

@interface XeeController (NavigationActions)

-(IBAction)skipNext:(id)sender;
-(IBAction)skipPrev:(id)sender;
-(IBAction)skipFirst:(id)sender;
-(IBAction)skipLast:(id)sender;
-(IBAction)skip10Forward:(id)sender;
-(IBAction)skip100Forward:(id)sender;
-(IBAction)skip10Back:(id)sender;
-(IBAction)skip100Back:(id)sender;
-(IBAction)skipRandom:(id)sender;
-(IBAction)skipRandomPrev:(id)sender;

-(IBAction)setSortOrder:(id)sender;

-(IBAction)runSlideshow:(id)sender;
-(IBAction)setSlideshowDelay:(id)sender;
-(IBAction)setCustomSlideshowDelay:(id)sender;
-(IBAction)delayPanelOK:(id)sender;
-(IBAction)delayPanelCancel:(id)sender;

-(void)slideshowStep:(NSTimer *)timer;
-(BOOL)isSlideshowRunning;

@end
