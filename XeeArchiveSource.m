#import "XeeArchiveSource.h"
#import "XeeImage.h"

#import <unistd.h>

@implementation XeeArchiveSource

+(NSArray *)fileTypes
{
	return [NSArray arrayWithObjects:
		@"zip",@"rar",@"cbz",@"cbr",@"lha",@"lzh",@"7z",
	nil];
}

-(id)initWithArchive:(NSString *)archivename
{
	if(self=[super init])
	{
		archive=[[self archiveForFile:archivename] retain];
		if(!archive)
		{
			[self release];
			return nil;
		}

		tmpdir=[[NSTemporaryDirectory() stringByAppendingPathComponent:
		[NSString stringWithFormat:@"Xee-archive-%04x%04x%04x",random()&0xffff,random()&0xffff,random()&0xffff]]
		retain];

		NSArray *filetypes=[XeeImage allFileTypes];
		int count=[archive numberOfEntries];
		for(int i=0;i<count;i++)
		{
			if([archive entryIsDirectory:i]) continue;
			if([archive entryIsLink:i]) continue;

			NSString *name=[archive nameOfEntry:i];
			NSDictionary *attrs=[archive attributesOfEntry:i];
			NSString *type=NSFileTypeForHFSTypeCode([attrs fileHFSTypeCode]);
			NSString *ext=[[name pathExtension] lowercaseString];

			if([filetypes indexOfObject:ext]!=NSNotFound||[filetypes indexOfObject:type]!=NSNotFound)
			{
				NSString *realpath=[tmpdir stringByAppendingPathComponent:name];
				[self addEntry:[[[XeeArchiveEntry alloc]
				initWithArchive:archive entry:i realPath:realpath] autorelease]
				sort:NO];
			}
		}

		[self sortFiles];

		[self setIcon:[[NSWorkspace sharedWorkspace] iconForFile:archivename]];
		[icon setSize:NSMakeSize(16,16)];

		[self pickImageAtIndex:0];
	}
	return self;
}

-(void)dealloc
{
	if(tmpdir) [[NSFileManager defaultManager] removeFileAtPath:tmpdir handler:nil];

	[archive release];
	[tmpdir release];

	[super dealloc];
}



-(NSString *)representedFilename { return [archive filename]; }

-(int)capabilities { return XeeNavigationCapable|XeeCopyingCapable|XeeSortingCapable; }



-(XADArchive *)archiveForFile:(NSString *)archivename
{
	Class archiveclass=NSClassFromString(@"XADArchive");

	if(!archiveclass)
	{
		NSString *unarchiver=[[NSWorkspace sharedWorkspace] fullPathForApplication:@"The Unarchiver"];
		if(!unarchiver)
		{
			NSString *ext=[[archivename pathExtension] lowercaseString];
			if([[XeeArchiveSource fileTypes] indexOfObject:ext]!=NSNotFound)
			{
				NSAlert *alert=[[[NSAlert alloc] init] autorelease];
				[alert setMessageText:NSLocalizedString(@"Problem Opening Archive",@"Error title when The Unarchiver is not installed")];
				[alert setInformativeText:NSLocalizedString(@"Xee can only open images inside archive files if The Unarchiver is also installed. You can download The Unarchiver for free by clicking the button below.",@"Error text when The Unarchiver is not installed")];
				[alert setAlertStyle:NSInformationalAlertStyle];
				[alert addButtonWithTitle:NSLocalizedString(@"Visit the The Unarchiver Download Page","Button to download The Unarchiver when it is not installed")];
				NSButton *cancel=[alert addButtonWithTitle:NSLocalizedString(@"Don't Bother","Button to not download The Unarchiver")];
				[cancel setKeyEquivalent:@"\033"];

				int res=[alert runModal];

				if(res==NSAlertFirstButtonReturn)
				[[NSWorkspace sharedWorkspace] openURL:
				[NSURL URLWithString:@"http://wakaba.c3.cx/s/apps/unarchiver.html"]];
			}

			return nil;
		}

		NSString *xadpath=[unarchiver stringByAppendingPathComponent:@"Contents/Frameworks/XADMaster.framework"];
		NSBundle *xadmaster=[NSBundle bundleWithPath:xadpath];
		if(!xadmaster) return nil;
		if(![xadmaster load]) return nil;

		NSString *unipath=[unarchiver stringByAppendingPathComponent:@"Contents/Frameworks/UniversalDetector.framework"];
		NSBundle *universal=[NSBundle bundleWithPath:unipath];
		if(!universal) return nil;
		if(![universal load]) return nil;

		archiveclass=NSClassFromString(@"XADArchive");
	}

	return [archiveclass archiveForFile:archivename];
}

@end



@implementation XeeArchiveEntry

extern xadERROR xadConvertDates(struct xadMasterBase *xadMasterBase, xadTag tag, ...)  __attribute__((weak_import));

-(id)initWithArchive:(XADArchive *)parentarchive entry:(int)num realPath:(NSString *)realpath
{
	if(self=[super init])
	{
		archive=[parentarchive retain];
		path=[realpath retain];
		n=num;
		ref=nil;

		struct xadFileInfo *info=[archive xadFileInfoForEntry:n];

		size=info->xfi_Size;
		if(!(info->xfi_Flags&XADFIF_NODATE))
		{
			struct xadDate *xd=&info->xfi_Date;
			NSCalendarDate *date=[NSCalendarDate dateWithYear:xd->xd_Year month:xd->xd_Month
			day:xd->xd_Day hour:xd->xd_Hour minute:xd->xd_Minute second:xd->xd_Second
			timeZone:[NSTimeZone defaultTimeZone]];

			time=[date timeIntervalSince1970];
		}
		else time=0;
		//xadConvertDates([archive xadMasterBase],XAD_DATEXADDATE,&info->xfi_Date,XAD_GETDATEUNIX,&time,TAG_DONE);
	}
	return self;
}

-(void)dealloc
{
	[archive release];
	[path release];
	[super dealloc];
}

-(NSString *)path { return path; }

-(XeeFSRef *)ref
{
	if(!ref)
	{
		[archive _extractEntry:n as:path];
		ref=[[XeeFSRef refForPath:path] retain];
	}
	return ref;
}

-(off_t)size { return size; }

-(long)time { return time; }

-(NSString *)descriptiveName { return [archive nameOfEntry:n]; }

-(BOOL)isEqual:(XeeArchiveEntry *)other { return [path isEqual:[other path]]; }

@end
