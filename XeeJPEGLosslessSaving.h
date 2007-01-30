#import "XeeJPEGLoader.h"

@interface XeeJPEGImage (LosslessSaving)

-(int)losslessSaveFlags;
-(BOOL)losslessSaveTo:(NSString *)path flags:(int)flags;

@end
