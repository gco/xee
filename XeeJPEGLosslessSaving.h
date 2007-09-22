#import "XeeJPEGLoader.h"

@interface XeeJPEGImage (LosslessSaving)

-(int)losslessSaveFlags;
-(NSString *)losslessFormat;
-(NSString *)losslessExtension;
-(BOOL)losslessSaveTo:(NSString *)path flags:(int)flags;

@end
