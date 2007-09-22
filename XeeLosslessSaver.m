#import "XeeLosslessSaver.h"


@implementation XeeLosslessSaver

+(BOOL)canSaveImage:(XeeImage *)img
{
	return [img losslessSaveFlags]&XeeCanSaveLosslesslyFlag?YES:NO;
}

-(id)initWithImage:(XeeImage *)img
{
	if(self=[super initWithImage:img])
	{
		int flags=[image losslessSaveFlags];

		untransformable=nil;
		cropping=nil;

		if(flags&XeeUntransformableBlocksCanBeRetainedFlag)
		untransformable=[XeeSLPopUp popUpWithTitle:
		NSLocalizedString(@"Untransformable edge blocks:",@"Title for the popup for selecting the action for untransformable blocks when saving losslessly")
		defaultValue:0 contents:
		NSLocalizedString(@"Keep",@"Option to keep untranslatable edge blocks"),
		NSLocalizedString(@"Remove",@"Option to remove untranslatable edge blocks"),
		nil];

		if(flags&XeeCroppingIsInexactFlag)
		cropping=[XeeSLPopUp popUpWithTitle:
		NSLocalizedString(@"Cropping:",@"Title for the popup for the action when cropping in inexact when saving losslessly")
		defaultValue:0 contents:
		NSLocalizedString(@"Expand",@"Option to expand the cropping area when saving losslessly"),
		NSLocalizedString(@"Trim",@"Option to trim the cropping area when saving losslessly"),
		nil];

		if(untransformable&&cropping) [self setControl:[XeeSLGroup groupWithControls:untransformable,cropping,nil]];
		else if(untransformable) [self setControl:untransformable];
		else if(cropping) [self setControl:cropping];
	}
	return self;
}

-(NSString *)format
{
	return [NSString stringWithFormat:
	NSLocalizedString(@"%@, Without Recompressing",@"Save panel format name for lossless saving (%@ is the format name, currently always JPEG)"),
	[image losslessFormat]];
}

-(NSString *)extension
{
	return [image losslessExtension];
}

-(BOOL)save:(NSString *)filename
{
	int flags=0;

	if(untransformable&&[untransformable value]==0) flags|=XeeRetainUntransformableBlocksFlag;
	if(cropping&&[cropping value]==1) flags|=XeeTrimCroppingFlag;

	return [image losslessSaveTo:filename flags:flags];
}

@end
