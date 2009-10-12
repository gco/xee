#import "XeeArchiveSource.h"
#import "XeeImage.h"

#import <unistd.h>

@implementation XeeArchiveSource

+(NSArray *)fileTypes
{
	return [NSArray arrayWithObjects:
		@"zip",@"cbz",@"rar",@"cbr",@"7z",@"cb7",@"lha",@"lzh",
	nil];
}

-(id)initWithArchive:(NSString *)archivename
{
	if(self=[super init])
	{
		parser=nil;
		tmpdir=[[NSTemporaryDirectory() stringByAppendingPathComponent:
		[NSString stringWithFormat:@"Xee-archive-%04x%04x%04x",random()&0xffff,random()&0xffff,random()&0xffff]]
		retain];

		[[NSFileManager defaultManager] createDirectoryAtPath:tmpdir attributes:nil];

		[self setIcon:[[NSWorkspace sharedWorkspace] iconForFile:archivename]];
		[icon setSize:NSMakeSize(16,16)];

		@try
		{
			parser=[[XADArchiveParser archiveParserForPath:archivename] retain];
		}
		@catch(id e) {}

		if(parser) return self;
	}

	[self release];
	return nil;
}

-(void)dealloc
{
	[[NSFileManager defaultManager] removeFileAtPath:tmpdir handler:nil];

	[parser release];
	[tmpdir release];

	[super dealloc];
}



-(void)start
{
	[self startListUpdates];

	@try
	{
		n=0;
		[parser setDelegate:self];
		[parser parse];
	}
	@catch(id e)
	{
		NSLog(@"Error parsing archive file %@: %@",[parser filename],e);
	}

	[self runSorter];

	[self endListUpdates];
	[self pickImageAtIndex:0];

	[parser release];
	parser=nil;
}

-(void)archiveParser:(XADArchiveParser *)dummy foundEntryWithDictionary:(NSDictionary *)dict
{
	NSNumber *isdir=[dict objectForKey:XADIsDirectoryKey];
	NSNumber *islink=[dict objectForKey:XADIsLinkKey];

	if(isdir&&[isdir boolValue]) return;
	if(islink&&[islink boolValue]) return;

	NSString *name=[[dict objectForKey:XADFileNameKey] string];
	NSString *ext=[[name pathExtension] lowercaseString];
	NSNumber *typenum=[dict objectForKey:XADFileTypeKey];
	uint32_t typeval=typenum?[typenum unsignedIntValue]:0;
	NSString *type=NSFileTypeForHFSTypeCode(typeval);

	NSArray *filetypes=[XeeImage allFileTypes];

	if([filetypes indexOfObject:ext]!=NSNotFound||[filetypes indexOfObject:type]!=NSNotFound)
	{
		NSString *realpath=[tmpdir stringByAppendingPathComponent:[NSString stringWithFormat:@"%d",n++]];
		[self addEntry:[[[XeeArchiveEntry alloc]
		initWithArchiveParser:parser entry:dict realPath:realpath] autorelease]];
	}
}



-(NSString *)representedFilename { return [parser filename]; }



-(BOOL)canBrowse { return YES; }
-(BOOL)canSort { return YES; }
-(BOOL)canCopyCurrentImage { return YES; }



/*
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
*/

@end



@implementation XeeArchiveEntry

-(id)initWithArchiveParser:(XADArchiveParser *)parent entry:(NSDictionary *)entry realPath:(NSString *)realpath
{
	if(self=[super init])
	{
		parser=[parent retain];
		dict=[entry retain];
		path=[realpath retain];
		ref=nil;

		size=[[dict objectForKey:XADFileSizeKey] unsignedLongLongValue];

		NSDate *date=[dict objectForKey:XADLastModificationDateKey];
		if(date) time=[date timeIntervalSinceReferenceDate];
		else date=0;
	}
	return self;
}

-(id)initAsCopyOf:(XeeArchiveEntry *)other
{
	if(self=[super initAsCopyOf:other])
	{
		parser=[other->parser retain];
		dict=[other->dict retain];
		ref=[other->ref retain];
		path=[other->path retain];
		size=other->size;
		time=other->time;
	}
	return self;
}

-(void)dealloc
{
	[parser release];
	[dict release];
	[path release];
	[ref release];
	[super dealloc];
}

-(NSString *)descriptiveName { return [[dict objectForKey:XADFileNameKey] string]; }

-(XeeFSRef *)ref
{
	if(!ref)
	{
		int fh=open([path fileSystemRepresentation],O_WRONLY|O_CREAT|O_TRUNC,0666);
		if(fh==-1) return nil;

		@try
		{
			CSHandle *srchandle=[parser handleForEntryWithDictionary:dict wantChecksum:NO];
			if(!srchandle) @throw @"Failed to get handle";

			uint8_t buf[65536];
			for(;;)
			{
				int actual=[srchandle readAtMost:sizeof(buf) toBuffer:buf];
				if(actual==0) break;
				if(write(fh,buf,actual)!=actual) @throw @"Failed to write to file";
			}
		}
		@catch(id e)
		{
			NSLog(@"Error extracting file %@ from archive %@.",[self descriptiveName],[parser filename]);
			close(fh);
			return nil;
		}

		close(fh);

		ref=[[XeeFSRef refForPath:path] retain];
	}
	return ref;
}

-(NSString *)path { return path; }

-(NSString *)filename { return [[[dict objectForKey:XADFileNameKey] string] lastPathComponent]; }

-(uint64_t)size { return size; }

-(double)time { return time; }



-(BOOL)isEqual:(XeeArchiveEntry *)other { return parser==other->parser&&dict==other->dict; }

-(unsigned long)hash { return (uintptr_t)parser^(uintptr_t)dict; }

@end
