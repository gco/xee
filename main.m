
#import <Cocoa/Cocoa.h>

int main(int argc, char *argv[])
{
	NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
		@"1",@"windowOpening",
		@"1",@"windowResizing",
		@"1",@"jpegYUV",
		@"1",@"shrinkToFit",
		@"0",@"enlargeToFit",
		@"0",@"useMipMapping",
		@"NO",@"ilbmUseTransparentColor",
		@"NO",@"ilbmUseMask",
		@"YES",@"pngStrip16Bit",
		@"NO",@"force2D",
		@"NO",@"useOrientation",
#ifdef BIG_ENDIAN
		@"2",@"antialiasQuality",
#else
		@"0",@"antialiasQuality",
#endif
		[NSArchiver archivedDataWithRootObject:[NSColor whiteColor]],@"defaultImageBackground",
		[NSArchiver archivedDataWithRootObject:[NSColor blackColor]],@"windowBackground",
		[NSArchiver archivedDataWithRootObject:[NSColor blackColor]],@"fullScreenBackground",
	nil]];
    [pool release];

    return NSApplicationMain(argc, (const char **) argv);
}
