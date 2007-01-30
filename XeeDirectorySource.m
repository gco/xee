#import "XeeDirectorySource.h"
#import "XeeImage.h"
#import "XeeKQueue.h"
#import "CSDesktopServices.h"

#import <sys/stat.h>

@implementation XeeDirectorySource

-(id)initWithDirectory:(NSString *)directoryname
{
	if(self=[super init])
	{
		imgref=dirref=nil;

		if([self scanDirectory:directoryname])
		{
			[self pickImageAtIndex:0];
			return self;
		}
	}
	[self release];
	return nil;
}

-(id)initWithFilename:(NSString *)filename
{
	if(self=[super init])
	{
		imgref=dirref=nil;

		[self addEntry:[XeeDirectoryEntry entryWithFilename:filename] sort:NO]; // make sure this file is in the list
		[self pickImageAtIndex:0];
		if([self scanDirectory:[filename stringByDeletingLastPathComponent]]) return self;
	}
	[self release];
	return nil;
}

-(id)initWithImage:(XeeImage *)image
{
	if(self=[super init])
	{
		imgref=dirref=nil;

		NSString *filename=[image filename];
		[self addEntry:[XeeDirectoryEntry entryWithFilename:filename] sort:NO]; // make sure this file is in the list
		[self setCurrentImage:image index:0];
		if([self scanDirectory:[filename stringByDeletingLastPathComponent]]) return self;
	}
	[self release];
	return nil;
}

-(void)dealloc
{
	[[XeeKQueue defaultKQueue] removeObserver:self ref:dirref];
	[[XeeKQueue defaultKQueue] removeObserver:self ref:imgref];
	[dirref release];
	[imgref release];

	[super dealloc];
}



-(int)capabilities
{
	return XeeNavigationCapable|XeeRenamingCapable|XeeCopyingCapable|
	XeeMovingCapable|XeeDeletionCapable|XeeSortingCapable;
}

-(void)_runSorter
{
	if(sortorder==XeeDateSortOrder||sortorder==XeeSizeSortOrder) [entries makeObjectsPerformSelector:@selector(readAttributes)];
	[super _runSorter];
}



-(BOOL)scanDirectory:(NSString *)directoryname
{
	dirref=[[XeeFSRef refForPath:directoryname] retain];
	if(!dirref) return NO;

	sortorder=[[NSUserDefaults standardUserDefaults] integerForKey:@"defaultSortOrder"];

	if(!sortorder)
	{
		sortorder=XeeNameSortOrder;

		NSDictionary *dsdict=CSParseDSStore([[directoryname stringByDeletingLastPathComponent] stringByAppendingPathComponent:@".DS_Store"]);
		NSData *lsvo=[[dsdict objectForKey:[directoryname lastPathComponent]] objectForKey:@"lsvo"];
		if(lsvo&&[lsvo length]>=11)
		{
			switch(XeeBEUInt32((uint8 *)[lsvo bytes]+7))
			{
				case 'phys': sortorder=XeeSizeSortOrder; break;
				case 'modd': sortorder=XeeDateSortOrder; break; // !5JrU4QOlH6
			}
		}
	}

	[self addEntries:[self readDirectory:dirref] sort:YES clear:NO]; 

	[self setIcon:[[NSWorkspace sharedWorkspace] iconForFile:directoryname]];
	[icon setSize:NSMakeSize(16,16)];

	[[XeeKQueue defaultKQueue] addObserver:self selector:@selector(directoryChanged:)
	ref:dirref flags:NOTE_WRITE|NOTE_DELETE|NOTE_RENAME];

	needsrefresh=NO;

	return YES;
}

-(NSArray *)readDirectory:(XeeFSRef *)ref
{
	NSMutableArray *res=[NSMutableArray array];
	NSString *directoryname=[ref path];
	NSFileManager *fm=[NSFileManager defaultManager];
	NSArray *dircontents=[fm directoryContentsAtPath:directoryname];
	NSArray *filetypes=[XeeImage allFileTypes];

	NSEnumerator *enumerator=[dircontents objectEnumerator];
	NSString *file;
	while(file=[enumerator nextObject])
	{
		NSString *path=[directoryname stringByAppendingPathComponent:file];
		NSDictionary *attrs=[fm fileAttributesAtPath:path traverseLink:YES];
		NSString *type=NSFileTypeForHFSTypeCode([attrs fileHFSTypeCode]);
		NSString *ext=[[file pathExtension] lowercaseString];

		if([filetypes indexOfObject:ext]!=NSNotFound
		||[filetypes indexOfObject:type]!=NSNotFound)
		[res addObject:[XeeDirectoryEntry entryWithFilename:path]];
	}

	return res;
}

-(void)setCurrentImage:(XeeImage *)image index:(int)index
{
	[[XeeKQueue defaultKQueue] removeObserver:self ref:imgref];
	[imgref release];
	imgref=nil;

	[super setCurrentImage:image index:index];

	if(image)
	{
		imgref=[[[entries objectAtIndex:currindex] ref] retain];
		written=NO;
		[[XeeKQueue defaultKQueue] addObserver:self selector:@selector(fileChanged:)
		ref:imgref flags:NOTE_WRITE|NOTE_DELETE|NOTE_RENAME|NOTE_ATTRIB];
	}
}



-(NSString *)directory { return [dirref path]; }



-(void)fileChanged:(XeeKEvent *)event
{
	int flags=[event flags];
	XeeFSRef *ref=[event ref];

	if(ref!=imgref) return; // probably doesn't happen

	if(flags&NOTE_WRITE)
	{
		written=YES;
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshImage) object:nil];
	}
	if(flags&NOTE_ATTRIB)
	{
		if(sortorder==XeeDateSortOrder) [self sortFiles];

		if(written&&!(flags&NOTE_WRITE))
		{
			written=NO;
			[self performSelector:@selector(refreshImage) withObject:nil afterDelay:0.2];
		}
	}
	if(flags&NOTE_RENAME)
	{
		if([ref isValid]&&[[ref parent] isEqual:dirref])
		{
			if(sortorder==XeeNameSortOrder) [self sortFiles];
			[currimage triggerPropertyChangeAction];
		}
		else [self removeEntryMatchingObject:ref];
	}
	if(flags&NOTE_DELETE)
	{
		[self removeEntryMatchingObject:ref];
	}
}

-(void)refreshImage
{
	int index=currindex;
	[self setCurrentImage:nil index:-1];
	[self pickImageAtIndex:index next:nextindex];
	if(sortorder==XeeSizeSortOrder) [self sortFiles];
}

-(void)directoryChanged:(XeeKEvent *)event
{
	int flags=[event flags];
	XeeFSRef *ref=[event ref];

	if(flags&NOTE_WRITE)
	{
		[self setNeedsRefresh:YES];
	}
	if(flags&NOTE_RENAME)
	{
		if(![ref isValid]) [self removeAllEntries];
		else [currimage triggerPropertyChangeAction];
	}
	if(flags&NOTE_DELETE)
	{
		[self removeAllEntries];
	}
}



-(void)setNeedsRefresh:(BOOL)refresh
{
	if(needsrefresh==refresh) return;

	needsrefresh=refresh;

	if(needsrefresh) [self performSelector:@selector(refresh) withObject:nil afterDelay:0];
}

-(void)refresh
{
	if(!needsrefresh) return;

	[self addEntries:[self readDirectory:dirref] sort:YES clear:YES];

	needsrefresh=NO;
}

@end



@implementation XeeDirectoryEntry

+(XeeDirectoryEntry *)entryWithRef:(XeeFSRef *)ref
{
	return [[[XeeDirectoryEntry alloc] initWithRef:ref] autorelease];
}

+(XeeDirectoryEntry *)entryWithFilename:(NSString *)filename
{
	return [[[XeeDirectoryEntry alloc] initWithRef:[XeeFSRef refForPath:filename]] autorelease];
}

-(id)initWithRef:(XeeFSRef *)fsref
{
	if(self=[super init])
	{
		ref=[fsref retain];
		[self readAttributes];
	}
	return self;
}

-(void)dealloc
{
	[ref release];
	[super dealloc];
}

-(void)readAttributes
{
	struct stat st;
	lstat([[ref path] fileSystemRepresentation],&st);
	size=st.st_size;
	time=st.st_mtimespec.tv_sec;
}

-(NSString *)path { return [ref path]; }

-(XeeFSRef *)ref { return ref; }

-(off_t)size { return size; }

-(long)time { return time; }

-(NSString *)descriptiveName { return [[ref path] lastPathComponent]; }

-(BOOL)matchesObject:(id)obj { return [obj isKindOfClass:[XeeFSRef class]]&&[ref isEqual:obj]; }

-(BOOL)isEqual:(XeeDirectoryEntry *)other { return [ref isEqual:[other ref]]; }

@end
