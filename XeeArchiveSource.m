#import "XeeArchiveSource.h"
#import "XeeImage.h"

#import <unistd.h>

@implementation XeeArchiveSource

+(NSArray *)fileTypes
{

	return [NSArray arrayWithObjects:
		@"zip",@"cbz",@"rar",@"cbr",@"7z",@"cb7",@"lha",@"lzh",
		@"000",@"001",@"iso",@"bin",@"alz",@"sit",@"sitx",
	nil];
}

-(id)initWithArchive:(NSString *)archivename
{
	if(self=[super init])
	{
		filename=[archivename retain];

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
		NSLog(@"Error parsing archive file %@: %@",filename,e);
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

-(void)archiveParserNeedsPassword:(XADArchiveParser *)dummy
{
	[parser setPassword:[self demandPassword]];
}



-(NSString *)windowTitle
{
	return [NSString stringWithFormat:@"%@ (%@)",[filename lastPathComponent],[currentry descriptiveName]];
}

-(NSString *)windowRepresentedFilename { return filename; }



-(BOOL)canBrowse { return currentry!=nil; }
-(BOOL)canSort { return currentry!=nil; }
-(BOOL)canCopyCurrentImage { return currentry!=nil; }



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
