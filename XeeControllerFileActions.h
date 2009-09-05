#import "XeeController.h"

@interface XeeController (FileActions)

-(IBAction)revealInFinder:(id)sender;

-(IBAction)renameFileFromMenu:(id)sender;
-(void)renamePanelEnd:(XeeRenamePanel *)panel returnCode:(int)res filename:(NSString *)newname;

-(IBAction)deleteFileFromMenu:(id)sender;
-(IBAction)askAndDelete:(id)sender;
-(void)deleteAlertEnd:(NSAlert *)alert returnCode:(int)res contextInfo:(void *)info;

-(IBAction)moveFile:(id)sender;
-(IBAction)copyFile:(id)sender;
-(IBAction)copyToDestination1:(id)sender;
-(IBAction)copyToDestination2:(id)sender;
-(IBAction)copyToDestination3:(id)sender;
-(IBAction)copyToDestination4:(id)sender;
-(IBAction)copyToDestination5:(id)sender;
-(IBAction)copyToDestination6:(id)sender;
-(IBAction)copyToDestination7:(id)sender;
-(IBAction)copyToDestination8:(id)sender;
-(IBAction)copyToDestination9:(id)sender;
-(IBAction)copyToDestination10:(id)sender;
-(IBAction)moveToDestination1:(id)sender;
-(IBAction)moveToDestination2:(id)sender;
-(IBAction)moveToDestination3:(id)sender;
-(IBAction)moveToDestination4:(id)sender;
-(IBAction)moveToDestination5:(id)sender;
-(IBAction)moveToDestination6:(id)sender;
-(IBAction)moveToDestination7:(id)sender;
-(IBAction)moveToDestination8:(id)sender;
-(IBAction)moveToDestination9:(id)sender;
-(IBAction)moveToDestination10:(id)sender;
-(void)triggerDrawer:(int)mode;
-(void)drawerDidClose:(NSNotification *)notification;
-(void)destinationListClick:(id)sender;
-(void)destinationPanelEnd:(NSOpenPanel *)panel returnCode:(int)res contextInfo:(void *)info;
-(void)transferToDestination:(int)index mode:(int)mode;
-(void)attemptToTransferCurrentImageTo:(NSString *)destination mode:(int)mode;
-(void)collisionPanelEnd:(XeeCollisionPanel *)panel returnCode:(int)res path:(NSString *)destination mode:(int)mode;
-(void)transferCurrentImageTo:(NSString *)destination mode:(int)mode;

-(IBAction)launchAppFromMenu:(id)sender;
-(IBAction)launchDefaultEditor:(id)sender;

@end
