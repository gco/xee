#import "XeeFileSource.h"
#import "XeeImage.h"
#import "XeeStringAdditions.h"

#define XeeAdditionChange 0x0001
#define XeeDeletionChange 0x0002
#define XeeSortingChange 0x0004

@implementation XeeFileSource

-(id)init
{
	if(self=[super init])
	{
	}
	return self;
}

-(void)dealloc
{
	[super dealloc];
}

-(NSString *)filenameOfCurrentImage
{
	return [(XeeFileEntry *)currentry filename];
}

-(uint64_t)sizeOfCurrentImage
{
	[(XeeFileEntry *)currentry prepareForSortingBy:XeeSizeSortOrder];
	return [(XeeFileEntry *)currentry size];
}

-(NSDate *)dateOfCurrentImage
{
	[(XeeFileEntry *)currentry prepareForSortingBy:XeeDateSortOrder];
	return [NSDate dateWithTimeIntervalSinceReferenceDate:[(XeeFileEntry *)currentry time]];
}

-(BOOL)isCurrentImageRemote
{
	XeeFSRef *ref=[(XeeFileEntry *)currentry ref];
	if(!ref) return NO;
	return [ref isRemote];
}

-(BOOL)isCurrentImageAtPath:(NSString *)path
{
	return [path isEqual:[(XeeFileEntry *)currentry path]];
}



-(void)setSortOrder:(int)order
{
	[super setSortOrder:order];
	[self sortFiles];
}

-(void)runSorter
{
	NSEnumerator *enumerator=[entries objectEnumerator];
	XeeFileEntry *entry;
	while(entry=[enumerator nextObject]) [entry prepareForSortingBy:sortorder];

	switch(sortorder)
	{
		case XeeDateSortOrder: [entries sortUsingSelector:@selector(compareTimes:)]; break;
		case XeeSizeSortOrder: [entries sortUsingSelector:@selector(compareSizes:)]; break;
		default: [entries sortUsingSelector:@selector(comparePaths:)]; break;
	}

	[entries makeObjectsPerformSelector:@selector(finishSorting)];

	changes|=XeeSortingChange;
}

-(void)sortFiles
{
	[self startListUpdates];
	[self runSorter];
	[self endListUpdates];
}



-(NSError *)renameCurrentImageTo:(NSString *)newname
{
	NSString *currpath=[(XeeFileEntry *)currentry path];
	NSString *newpath=[[currpath stringByDeletingLastPathComponent]
	stringByAppendingPathComponent:newname];

	if([currpath isEqual:newpath]) return nil;

	if([[NSFileManager defaultManager] fileExistsAtPath:newpath])
	{
		return [NSError errorWithDomain:XeeErrorDomain code:XeeFileExistsError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
			NSLocalizedString(@"Couldn't rename file",@"Title of the rename error dialog"),NSLocalizedDescriptionKey,
			[NSString stringWithFormat:NSLocalizedString(@"The file \"%@\" could not be renamed because another file with the same name already exists.",@"Content of the rename collision dialog"),
			[currpath lastPathComponent]],NSLocalizedRecoverySuggestionErrorKey,
		nil]];
	}

	if(![[NSFileManager defaultManager] movePath:currpath toPath:newpath handler:nil])
	{
		return [NSError errorWithDomain:XeeErrorDomain code:XeeRenameError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
			NSLocalizedString(@"Couldn't rename file",@"Title of the rename error dialog"),NSLocalizedDescriptionKey,
			[NSString stringWithFormat:NSLocalizedString(@"The file \"%@\" could not be renamed.",@"Content of the rename error dialog"),
			[currpath lastPathComponent]],NSLocalizedRecoverySuggestionErrorKey,
		nil]];
	}

	// success, let kqueue update list

	return nil;
}

-(NSError *)deleteCurrentImage
{
	XeeFSRef *ref=[(XeeFileEntry *)currentry ref];
	NSString *path=[ref path];
	BOOL res;

	if([ref isRemote]) res=[[NSFileManager defaultManager] removeFileAtPath:path handler:NULL];
	else res=[[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:[path stringByDeletingLastPathComponent]
	destination:nil files:[NSArray arrayWithObject:[path lastPathComponent]] tag:nil];

	if(!res)
	{
		return [NSError errorWithDomain:XeeErrorDomain code:XeeDeleteError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
			NSLocalizedString(@"Couldn't delete file",@"Title of the delete failure dialog"),NSLocalizedDescriptionKey,
			[NSString stringWithFormat:NSLocalizedString(@"The file \"%@\" could not be deleted.",@"Content of the delet failure dialog"),
			[path lastPathComponent]],NSLocalizedRecoverySuggestionErrorKey,
		nil]];
	}

	// success, let kqueue update list
	[self playSound:@"/System/Library/Components/CoreAudio.component/Contents/Resources/SystemSounds/dock/drag to trash.aif"];

	return nil;
}

-(NSError *)copyCurrentImageTo:(NSString *)destination
{
	NSString *currpath=[(XeeFileEntry *)currentry path];

	if([[NSFileManager defaultManager] fileExistsAtPath:destination])
	[[NSFileManager defaultManager] removeFileAtPath:destination handler:nil];

	if(![[NSFileManager defaultManager] copyPath:currpath toPath:destination handler:nil])
	{
		return [NSError errorWithDomain:XeeErrorDomain code:XeeCopyError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
			NSLocalizedString(@"Couldn't copy file",@"Title of the copy failure dialog"),NSLocalizedDescriptionKey,
			[NSString stringWithFormat:NSLocalizedString(@"The file \"%@\" could not be copied to the folder \"%@\".",@"Content of the copy failure dialog"),
			[currpath lastPathComponent],[destination stringByDeletingLastPathComponent]],NSLocalizedRecoverySuggestionErrorKey,
		nil]];
	}

	// "copied" message in status bar
	[self playSound:@"/System/Library/Components/CoreAudio.component/Contents/Resources/SystemSounds/system/Volume Mount.aif"];

	return nil;
}

-(NSError *)moveCurrentImageTo:(NSString *)destination
{
	NSString *currpath=[(XeeFileEntry *)currentry path];

	if([[NSFileManager defaultManager] fileExistsAtPath:destination])
	[[NSFileManager defaultManager] removeFileAtPath:destination handler:nil];

	if(![[NSFileManager defaultManager] movePath:currpath toPath:destination handler:nil])
	{
		return [NSError errorWithDomain:XeeErrorDomain code:XeeMoveError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
			NSLocalizedString(@"Couldn't move file",@"Title of the move failure dialog"),NSLocalizedDescriptionKey,
			[NSString stringWithFormat:NSLocalizedString(@"The file \"%@\" could not be moved to the folder \"%@\".",@"Content of the move failure dialog"),
			[currpath lastPathComponent],[destination stringByDeletingLastPathComponent]],NSLocalizedRecoverySuggestionErrorKey,
		nil]];
	}

	// "moved" message in status bar
	[self playSound:@"/System/Library/Components/CoreAudio.component/Contents/Resources/SystemSounds/system/Volume Mount.aif"];
	// success, let kqueue update list

	return nil;
}

-(NSError *)openCurrentImageInApp:(NSString *)app
{
	NSString *currpath=[(XeeFileEntry *)currentry path];

	// TODO: handle errors
	[[NSWorkspace sharedWorkspace] openFile:currpath withApplication:app];

	return nil;
}

-(void)playSound:(NSString *)filename
{
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"com.apple.sound.uiaudio.enabled"])
	[self performSelector:@selector(actuallyPlaySound:) withObject:filename afterDelay:0];
}

-(void)actuallyPlaySound:(NSString *)filename
{
	[[[[NSSound alloc] initWithContentsOfFile:filename byReference:NO] autorelease] play];
}

@end



@implementation XeeFileEntry

-(id)init
{
	if(self=[super init])
	{
		pathbuf=NULL;
	}
	return self;
}

-(void)dealloc
{
	free(pathbuf);
	[super dealloc];
}




-(XeeImage *)produceImage
{
	return [XeeImage imageForRef:[self ref]];
}



-(XeeFSRef *)ref { return nil; }

-(NSString *)path { return [[self ref] path]; }

-(NSString *)filename { return nil; }

-(uint64_t)size { return 0; }

-(double)time { return 0; }



-(void)prepareForSortingBy:(int)sortorder
{
	switch(sortorder)
	{
		case XeeDateSortOrder: break;
		case XeeSizeSortOrder: break;
		default:
		{
			NSString *path=[self descriptiveName];
			pathlen=[path length];
			pathbuf=malloc(pathlen*sizeof(UniChar));
			[path getCharacters:pathbuf];
		}
	}
}

-(void)finishSorting
{
	free(pathbuf);
	pathbuf=NULL;
}

-(NSComparisonResult)comparePaths:(XeeFileEntry *)other
{
	SInt32 res;
	UCCompareTextDefault(kUCCollateComposeInsensitiveMask|kUCCollateWidthInsensitiveMask|
	kUCCollateCaseInsensitiveMask|kUCCollateDigitsOverrideMask|kUCCollateDigitsAsNumberMask|
	kUCCollatePunctuationSignificantMask,pathbuf,pathlen,other->pathbuf,other->pathlen,NULL,&res);
	return res;
}

-(NSComparisonResult)compareSizes:(XeeFileEntry *)other
{
	uint64_t size1=[self size];
	uint64_t size2=[other size];

	if(size1==size2) return NSOrderedSame;
	else if(size1>size2) return NSOrderedAscending;
	else return NSOrderedDescending;
}

-(NSComparisonResult)compareTimes:(XeeFileEntry *)other
{
	double time1=[self time];
	double time2=[other time];

	if(time1==time2) return NSOrderedSame;
	else if(time1>time2) return NSOrderedAscending;
	else return NSOrderedDescending;
}

-(NSString *)description { return [NSString stringWithFormat:@"%@",[self path]]; }

@end
