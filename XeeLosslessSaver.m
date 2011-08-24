#import "XeeLosslessSaver.h"



@implementation XeeLosslessSaver

-(id)initWithImage:(XeeImage *)img
{
	if(self=[super initWithImage:img])
	{
		trim=nil;

		NSMutableArray *controls=[NSMutableArray array];

		int flags=[image losslessFlags];

		if(flags&XeeNeedsTrimmingFlag)
		{
			trim=[[XeeSLSwitch switchWithTitle:nil
			label:NSLocalizedString(@"Trim untransformable edges",
			@"Trimming edges of JPEG files checkbox for lossless saving images")
			defaultValue:YES] retain];

			[controls addObject:trim];
		}

		if(flags&XeeCroppingInexactFlag)
		{
			XeeSLText *warn=[XeeSLText textWithTitle:nil
			text:NSLocalizedString(@"Warning: Cropping will be inexact.",
			@"Waring when lossless saving can't crop exactly")];
			[controls addObject:warn];
		}

		if([controls count])
		{
			XeeSLGroup *group=[[[XeeSLGroup alloc] initWithControls:controls] autorelease];
			[self setControl:group];
		}
	}
	return self;
}

-(void)dealloc
{
	[trim release];
	[super dealloc];
}

-(NSString *)format
{
	return [NSString stringWithFormat:
		NSLocalizedString(@"%@, Without Recompressing",@"Format description for lossless saving, %@ is the normal format name (ie, JPEG)"),
		[image format]
	];
}

-(NSString *)extension { return [[image filename] pathExtension]; }

-(BOOL)save:(NSString *)filename
{
	int flags=0;

	if(trim)
	{
		if([trim value]) flags|=XeeTrimFlag;
	}

	return [image losslessSaveTo:filename flags:flags];
}

+(BOOL)canSaveImage:(XeeImage *)img { return [img losslessFlags]&XeeCanLosslesslySaveFlag?YES:NO; }

@end
