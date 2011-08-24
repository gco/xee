#import "XeeNSImageLoader.h"

#import "XeeBitmapImage.h";


/*
@implementation XeeNSImage

-(id)initWithFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes;
{
	if(self=[super initWithFile:name firstBlock:block attributes:attributes])
	{
		NSImage *image=[[[NSImage alloc] initWithContentsOfFile:name] autorelease];

		if(image)
		{
//			width=;
///			height=;
//			depth=;
			[self setFormat:[[filename pathExtension] uppercaseString]];

			NSArray *images=[XeeNSImage convertRepresentations:[image representations]];
			if(images)
			{
				[self addSubImages:images];
				[self setState:XeeImageStateLoaded];

				return self;
			}
		}

		[self release];
		return nil;
	}

	return self;
}

-(id)initWithPasteboard:(NSPasteboard *)pboard
{
	if(self=[super initWithFile:nil firstBlock:nil attributes:nil])
	{
		NSString *type=[pboard availableTypeFromArray:[NSArray arrayWithObjects:NSTIFFPboardType,NSPICTPboardType,nil]];

		if(type)
		{
			NSImage *image=[[[NSImage alloc] initWithData:[pboard dataForType:type]] autorelease];

			if(image)
			{
//				width=;
///				height=;
//				depth=;
				[self setFormat:type];

				NSArray *images=[XeeNSImage convertRepresentations:[image representations]];
				if(images)
				{
					[self addSubImages:images];
					[self setState:XeeImageStateLoaded];

					return self;
				}
			}
		}

		[self release];
		return nil;
	}

	return self;
}

-(void)dealloc
{
	[super dealloc];
}

+(BOOL)canInitFromPasteboard:(NSPasteboard *)pboard
{
	NSString *type=[pboard availableTypeFromArray:[NSArray arrayWithObjects:NSTIFFPboardType,NSPICTPboardType,nil]];
	return type?YES:NO;
}

+(NSArray *)convertRepresentations:(NSArray *)representations
{
	NSMutableArray *images=[NSMutableArray arrayWithCapacity:[representations count]];
	NSEnumerator *enumerator=[representations objectEnumerator];
	NSBitmapImageRep *rep;

	while(rep=[enumerator nextObject])
	{
		if(![rep isKindOfClass:[NSBitmapImageRep class]])
		{
			if([rep isKindOfClass:[NSPICTImageRep class]]
			||[rep isKindOfClass:[NSEPSImageRep class]])
			{
				NSSize size=[rep size];

				NSImage *image=[[NSImage alloc] initWithSize:size];
				[image lockFocus];
	
				[rep draw];

				rep=[[[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0,0,size.width,size.height)] autorelease];
	
				[image unlockFocus];
				[image release];
			}
			else continue;
		}

		XeeBitmapImage *image=[[XeeBitmapImage alloc] initWithImageRep:rep];

		if(image)
		{
			[images addObject:image];
			[image release];
		}
	}

	return images&&[images count]?images:nil;
}

+(NSArray *)fileTypes { return [NSBitmapImageRep imageFileTypes]; }

@end

*/
