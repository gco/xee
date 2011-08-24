#import "XeeDirectoryController.h"
#import "XeeView.h"
#import "XeeImage.h"
#import "XeeDelegate.h"
#import "XeeDestinationList.h"
#import "XeeStatusBar.h"
#import "XeeMisc.h"
#import "XeeSegmentedItem.h"



// XeeDirectoryController

@implementation XeeDirectoryController

static NSMutableArray *directorycontrollers=nil;

-(id)init
{
	if(self=[super init])
	{
		directory=nil;
		dircontents=nil;

		loadlock=[[NSRecursiveLock alloc] init];
		loader_running=NO;
		exiting=NO;

		previmage=nil;
		currimage=nil;
		nextimage=nil;
		loadingimage=nil;

		previndex=currindex=nextindex=-1;

		randomlist=NULL;

		drawer_mode=XeeNoMode;

		[directorycontrollers addObject:self];
    }
    return self;
}

-(void)dealloc
{
	//[controllers removeObject:self];

	[directory release];
	[dircontents release];

	[loadlock release];

	[previmage release];
	[nextimage release];

	[self freeRandomList];

	[drawer release];
	[renamepanel release];
	[collisionpanel release];

	[super dealloc];
}

-(void)windowWillClose:(NSNotification *)notification
{
	if([notification object]!=window) return; // ignore messages from the fullscreen window
	[directorycontrollers removeObject:self];

	exiting=YES;
	[loadingimage stopLoading];

	[super windowWillClose:notification];
}

-(NSRect)availableScreenSpace
{
	NSRect rect=[super availableScreenSpace];
	if([drawer state]==NSDrawerOpenState) rect.size.width-=[drawer contentSize].width+6;
	return rect;
}

-(NSSize)minViewSize
{
	NSSize size=[super minViewSize];

	if([drawer state]==NSDrawerOpenState)
	{
		int drawerheight=[table numberOfRows]*18;
		drawerheight+=[drawer leadingOffset];
		drawerheight+=[drawer trailingOffset];
		drawerheight+=19; // uh-huh, right...
		if(size.height<drawerheight) size.height=drawerheight;
	}
	return size;
}



-(BOOL)loadImage:(NSString *)filename
{
	BOOL dir;

	if(![[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:&dir]) return NO;

	[loadlock lock];

	[self setPreviousImage:nil index:-1];
	[self setCurrentImage:nil index:-1];
	[self setNextImage:nil index:-1];
	[loadingimage stopLoading];

	[loadlock unlock];

	[self freeRandomList];

	NSString *filepart;

	if(dir)
	{
		[directory release];
		directory=[filename retain];
		filepart=nil;
	}
	else
	{
		[directory release];
		directory=[[filename stringByDeletingLastPathComponent] retain];
		filepart=[filename lastPathComponent];
	}

	[dircontents release];
	dircontents=[[NSMutableArray alloc] initWithCapacity:256];

	NSFileManager *fm=[NSFileManager defaultManager];
	NSArray *filetypes=[XeeImage fileTypes];
	NSArray *files=[fm directoryContentsAtPath:directory];

	NSEnumerator *enumerator=[files objectEnumerator];
	NSString *file;

	while(file=[enumerator nextObject])
	{
		NSDictionary *attrs=[fm fileAttributesAtPath:[directory stringByAppendingPathComponent:file] traverseLink:YES];
		NSString *type=NSFileTypeForHFSTypeCode([attrs fileHFSTypeCode]);
		NSString *ext=[[file pathExtension] lowercaseString];

		if( (filepart&&[file isEqual:filepart])
		||[filetypes indexOfObject:ext]!=NSNotFound
		||[filetypes indexOfObject:type]!=NSNotFound)
		[dircontents addObject:file];
	}

	[self sortFiles];

	int index;

	if(filepart)
	{
		index=[self findFile:filepart];
	}
	else
	{
		if([dircontents count]) index=0;
		else index=-1;
	}

	[self displayImage:index next:index+1];

	return index!=-1;
}

-(void)displayImage:(int)index next:(int)next
{
	[loadlock lock];

	XeeImage *newcurrimage=nil,*newnextimage=nil;

	if(index<0 || index>=[dircontents count]) index=-1;
	else newcurrimage=[self imageAtIndex:index];

	if(next<0 || next>=[dircontents count]) next=-1;
	else newnextimage=[self imageAtIndex:next];

	[self setPreviousImage:currimage index:currindex];
	[self setCurrentImage:newcurrimage index:index];
	[self setNextImage:newnextimage index:next];

	if(loadingimage&&loadingimage!=currimage) [loadingimage stopLoading];

	[self launchLoader];

	[loadlock unlock];

	[window setTitleWithRepresentedFilename:[self currentFilename]];
}

-(XeeImage *)imageAtIndex:(int)index
{
	if(index<0) return nil;
	else if(index==currindex) return currimage;
	else if(index==nextindex) return nextimage;
	else if(index==previndex) return previmage;
	else return [XeeImage imageForFilename:[directory stringByAppendingPathComponent:[dircontents objectAtIndex:index]]];
}

-(void)setCurrentImage:(XeeImage *)image index:(int)index
{
	currindex=index;
	[self setImage:image];
}

-(void)setPreviousImage:(XeeImage *)image index:(int)index
{
	previndex=index;
	[previmage autorelease];
	previmage=[image retain];
}

-(void)setNextImage:(XeeImage *)image index:(int)index
{
	nextindex=index;
	[nextimage autorelease];
	nextimage=[image retain];
}

-(void)reloadImage
{
	[loadlock lock];

	[self setImage:[XeeImage imageForFilename:[directory stringByAppendingPathComponent:[dircontents objectAtIndex:currindex]]]];

	[loadingimage stopLoading];
	[self launchLoader];

	[loadlock unlock];
}

-(void)imageLoader:(id)nothing
{
	NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

	[self retain];

	[NSThread setThreadPriority:0.1];

	[loadlock lock];

	for(;;)
	{
		if(exiting) break;

		NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

		if(currimage&&![currimage completed]) loadingimage=currimage;
		else if(nextimage&&![nextimage completed]) loadingimage=nextimage;
		else break;

		[loadingimage retain];
		[loadlock unlock];

		double starttime=XeeGetTime();
		[loadingimage runLoader];
		double endtime=XeeGetTime();

		NSLog(@"%@: %g s (%@)",[loadingimage descriptiveFilename],endtime-starttime,loadingimage);

		[loadlock lock];
		[loadingimage release];

		[pool release];
	}

	loader_running=NO;
	loadingimage=nil;

	[loadlock unlock];

	[self release];

	[pool release];
}

-(void)launchLoader
{
	if(!loader_running)
	{
		[NSThread detachNewThreadSelector:@selector(imageLoader:) toTarget:self withObject:nil];
		loader_running=YES;
	}
}

-(void)setupStatusBar
{
	filescell=[XeeStatusCell statusWithImageNamed:@"" title:@""];
	zoomcell=[XeeStatusCell statusWithImageNamed:@"zoom" title:@""];
	framescell=[XeeStatusCell statusWithImageNamed:@"frames" title:@""];
	rescell=[XeeStatusCell statusWithImageNamed:@"size" title:@""];
	colourscell=[XeeStatusCell statusWithImageNamed:@"" title:@""];
	filesizecell=[XeeStatusCell statusWithImageNamed:@"filesize" title:@""];
	formatcell=[XeeStatusCell statusWithImageNamed:@"" title:@""];
	filenamecell=[XeeStatusCell statusWithImageNamed:@"" title:@""];
	datecell=[XeeStatusCell statusWithImageNamed:@"" title:@""];
	messagecell=[XeeStatusCell statusWithImageNamed:@"message" title:@""];
	errorcell=[XeeStatusCell statusWithImageNamed:@"error" title:@""];

	[statusbar addCell:filescell priority:10];
	[statusbar addCell:zoomcell priority:9];
	[statusbar addCell:framescell priority:8];
	[statusbar addCell:rescell priority:7];
	[statusbar addCell:colourscell priority:6];
	[statusbar addCell:filesizecell priority:5];
	[statusbar addCell:datecell priority:4];
	[statusbar addCell:formatcell priority:3];
	[statusbar addCell:filenamecell priority:2];
	[statusbar addCell:messagecell priority:1];
	[statusbar addCell:errorcell priority:100];

	[statusbar setHiddenFrom:0 to:10 values:YES,YES,YES,YES,YES,YES,YES,YES,YES,YES,YES];
}

-(void)updateStatusBar
{
	if(currindex>=0)
	{
		NSString *errormsg=NSLocalizedString(@"Error loading image",@"Statusbar text when loading fails");

		[filescell setTitle:[NSString stringWithFormat:@"%d/%d",currindex+1,[dircontents count]]];

		if(![filescell image])
		{
			NSImage *icon=[[NSWorkspace sharedWorkspace] iconForFile:directory];
			[icon setSize:NSMakeSize(16,16)];
			[filescell setImage:icon];
		}

		NSString *filepart;
		if(currimage) filepart=[currimage descriptiveFilename];
		else filepart=[dircontents objectAtIndex:currindex];

		if(![[filenamecell title] isEqual:filepart])
		{
			NSImage *icon=[[NSWorkspace sharedWorkspace] iconForFile:[self currentFilename]];
			[icon setSize:NSMakeSize(16,16)];
			[formatcell setImage:icon];

			[filenamecell setTitle:filepart];
		}

		if(currimage)
		{
			[statusbar setHiddenFrom:0 to:10 values:NO,NO,YES,NO,NO,NO,NO,NO,NO,YES,YES];

			[zoomcell setTitle:[NSString stringWithFormat:@"%d%%",(int)(zoom*100)]];
			[formatcell setTitle:[currimage format]];
			[filesizecell setTitle:[currimage descriptiveFileSize]];
			[rescell setTitle:[NSString stringWithFormat:@"%dx%d",[currimage width],[currimage height]]];
			[colourscell setTitle:[currimage depth]];
			[colourscell setImage:[currimage depthIcon]];
			[datecell setTitle:[currimage descriptiveDate]];

			if([currimage frames]>1)
			{
				[framescell setTitle:[NSString stringWithFormat:@"%d/%d",[currimage frame]+1,[currimage frames]]];
				[statusbar setHidden:NO forCell:framescell];
			}

			if([currimage failed])
			{
				[errorcell setTitle:errormsg];
				[statusbar setHidden:NO forCell:errorcell];
			}
			else if(![currimage completed])
			{
				[messagecell setTitle:NSLocalizedString(@"Loading...",@"Statusbar text while loading")];
				[statusbar setHidden:NO forCell:messagecell];
			}
		}
		else
		{
			[statusbar setHiddenFrom:0 to:10 values:NO,YES,YES,YES,YES,YES,YES,YES,NO,YES,NO];
			[errorcell setTitle:errormsg];
		}
	}
	else
	{
		[statusbar setHiddenFrom:0 to:10 values:YES,YES,YES,YES,YES,YES,YES,YES,YES,NO,YES];
		[messagecell setTitle:@"No file loaded"];
	}

	[statusbar setNeedsDisplay:YES];
}



int file_compare(NSString *a,NSString *b,void *context) { return [a compare:b options:NSCaseInsensitiveSearch|NSNumericSearch]; }

-(void)sortFiles
{
	[dircontents sortUsingFunction:file_compare context:nil];
}

-(int)findFile:(NSString *)filename
{
	if(!filename) return -1;

	int index=[dircontents indexOfObject:[filename lastPathComponent]];
	if(index==NSNotFound) return -1;
	return index;
}

-(int)findNextFile:(NSString *)filename
{
	if(!filename) return 0;

	int count=[dircontents count];

	for(int i=0;i<count;i++)
	{
		if(file_compare(filename,[dircontents objectAtIndex:i],nil)==NSOrderedAscending) return i;
	}

	return count-1;
}

-(void)removeFile:(NSString *)filename
{
	int index=[self findFile:filename];
	if(index<0) return;

	[self freeRandomList];

	[loadlock lock];

	NSString *prevname=previndex>=0?[[dircontents objectAtIndex:previndex] retain]:nil;
	NSString *currname=currindex>=0?[[dircontents objectAtIndex:currindex] retain]:nil;
	NSString *nextname=nextindex>=0?[[dircontents objectAtIndex:nextindex] retain]:nil;

	[dircontents removeObjectAtIndex:index];

	previndex=[self findFile:prevname];
	currindex=[self findFile:currname];
	nextindex=[self findFile:nextname];

	if(previndex<0) { [previmage release]; previmage=nil; }
	if(nextindex<0) { [nextimage release]; nextimage=nil; }
	if(currindex<0)
	{
		[self displayImage:[self findNextFile:currname] next:nextindex];
	}

	[prevname release];
	[currname release];
	[nextname release];

	[loadlock unlock];
}

-(void)insertFile:(NSString *)filename
{
	if(![[filename stringByDeletingLastPathComponent] isEqual:directory]) return; // wrong directory
	if([self findFile:filename]>=0) return; // already there

	[self freeRandomList];

	[loadlock lock];

	NSString *prevname=previndex>=0?[[dircontents objectAtIndex:previndex] retain]:nil;
	NSString *currname=currindex>=0?[[dircontents objectAtIndex:currindex] retain]:nil;
	NSString *nextname=nextindex>=0?[[dircontents objectAtIndex:nextindex] retain]:nil;

	[dircontents addObject:[filename lastPathComponent]];
	[self sortFiles];

	previndex=[self findFile:prevname]; [prevname release];
	currindex=[self findFile:currname]; [currname release];
	nextindex=[self findFile:nextname]; [nextname release];

	[loadlock unlock];

	[self displayImage:currindex next:nextindex];
}



-(NSDrawer *)drawer { return drawer; }

-(NSString *)directory { return directory; }

-(NSString *)currentFilename
{
	if(currindex<0) return nil;
	return [directory stringByAppendingPathComponent:[dircontents objectAtIndex:currindex]];
}



-(IBAction)skipNext:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[self skip:1];
}

-(IBAction)skipPrev:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[self skip:-1];
}

-(IBAction)skipFirst:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[self displayImage:0 next:1];
}

-(IBAction)skipLast:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[self displayImage:[dircontents count]-1 next:[dircontents count]-2];
}

-(IBAction)skip10Forward:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[self skip:10];
}

-(IBAction)skip100Forward:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[self skip:100];
}

-(IBAction)skip10Back:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[self skip:-10];
}

-(IBAction)skip100Back:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[self skip:-100];
}

-(void)skipToFile:(NSString *)filename
{
	int index=[self findFile:filename];

	if(index>=0) [self displayImage:index next:index+1];
}

-(void)skip:(int)step
{
	if(currindex==-1)
	{
		if(step>=0) [self skipFirst:nil];
		else [self skipLast:nil];
	}
	else
	{
		int newindex=currindex+step;
		int newnext=currindex+step+(step>=0?1:-1);
		int count=[dircontents count];

		if(newindex<0) newindex=0;
		if(newindex>=count) newindex=count-1;
		if(newnext<0) newnext=-1;
		if(newnext>=count) newnext=-1;

		if(newindex==currindex) return;

		[self displayImage:newindex next:newnext];
	}
}

-(IBAction)skipRandom:(id)sender
{
	if(currindex<0) return;
	if(!randomlist) [self buildRandomList];

	int newindex=randomlist[2*currindex];
	int newnext=randomlist[2*newindex];

	[self setResizeBlockFromSender:sender];
	[self displayImage:newindex next:newnext];
}

-(IBAction)skipRandomPrev:(id)sender
{
	if(currindex<0) return;
	if(!randomlist) [self buildRandomList];

	int newindex=randomlist[2*currindex+1];
	int newnext=randomlist[2*newindex+1];

	[self setResizeBlockFromSender:sender];
	[self displayImage:newindex next:newnext];
}

-(void)buildRandomList
{
	free(randomlist);

	srandom(time(NULL));

	int length=[dircontents count];

	int *order=malloc(sizeof(int)*length);
	randomlist=malloc(2*sizeof(int)*length);

	for(int i=0;i<length;i++) order[i]=i;

	for(int i=length-1;i>0;i--)
	{
		int randindex=random()%i;
		int tmp=order[i];
		order[i]=order[randindex];
		order[randindex]=tmp;
	}

	for(int i=0;i<length;i++)
	{
		randomlist[2*order[i]]=order[(i+1)%length];
		randomlist[2*order[i]+1]=order[(i+length-1)%length];
	}

	free(order);
}

-(void)freeRandomList
{
	free(randomlist);
	randomlist=NULL;
}



-(IBAction)revealInFinder:(id)sender
{
	if(currindex<0) return;

	NSString *filename=[self currentFilename];

	[[NSWorkspace sharedWorkspace] selectFile:filename inFileViewerRootedAtPath:nil];
}



-(IBAction)renameFileFromMenu:(id)sender
{
	if(currindex<0) return;

	[self setResizeBlockFromSender:sender];
	[renamepanel run:fullscreenwindow?nil:window image:currimage];
}

-(void)renameFile:(NSString *)filename to:(NSString *)newname
{
	if([filename isEqual:newname]) return;

	if([[NSFileManager defaultManager] fileExistsAtPath:newname])
	{
		[self errorMessage:NSLocalizedString(@"Couldn't rename file",@"Title of the rename error dialog")
		text:[NSString stringWithFormat:NSLocalizedString(@"The file \"%@\" could not be renamed because another file with the same name already exists.",@"Content of the rename collision dialog"),
		[filename lastPathComponent]]];
	}
	else
	{
		if([[NSFileManager defaultManager] movePath:filename toPath:newname handler:nil])
		{
			[self insertFile:newname];
			[self skipToFile:newname];
			[self removeFile:filename];
		}
		else
		{
			[self errorMessage:NSLocalizedString(@"Couldn't rename file",@"Title of the rename error dialog")
			text:[NSString stringWithFormat:NSLocalizedString(@"The file \"%@\" could not be renamed.",@"Content of the rename error dialog"),
			[filename lastPathComponent]]];
		}
	}
}


-(IBAction)deleteFileFromMenu:(id)sender
{
	if(currindex<0) return;

	[self setResizeBlockFromSender:sender];
	[self deleteFile:[self currentFilename]];
}

-(IBAction)askAndDelete:(id)sender
{
	if(currindex<0) return;

	[self setResizeBlockFromSender:sender];

	NSString *filename=[[self currentFilename] retain];
	NSAlert *alert=[[NSAlert alloc] init];

	[alert setMessageText:NSLocalizedString(@"Delete File",@"Title of the delete confirmation dialog")];
	[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Do you want to delete the image file \"%@\"?",@"Content of the delete confirmation dialog"),[filename lastPathComponent]]];
	[alert addButtonWithTitle:NSLocalizedString(@"Delete",@"Delete button")];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel",@"Cancel button")];
	[alert setIcon:[[[NSImage alloc] initWithContentsOfFile:@"/System/Library/CoreServices/Dock.app/Contents/Resources/trashfull.png"] autorelease]];

	if(fullscreenwindow) [self deleteAlertEnd:alert returnCode:[alert runModal] contextInfo:[filename retain]];
	else  [alert beginSheetModalForWindow:window modalDelegate:self didEndSelector:@selector(deleteAlertEnd:returnCode:contextInfo:) contextInfo:[filename retain]];
}

-(void)deleteAlertEnd:(NSAlert *)alert returnCode:(int)res contextInfo:(NSString *)filename
{
	if(res==NSAlertFirstButtonReturn)
	{
		[self deleteFile:filename];
	}
	[filename release];
}

-(void)deleteFile:(NSString *)filename
{
	if([[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:[filename stringByDeletingLastPathComponent]
	destination:nil files:[NSArray arrayWithObject:[filename lastPathComponent]] tag:nil])
	{
		[self removeFile:filename];
		[self playSound:@"/System/Library/Components/CoreAudio.component/Contents/Resources/SystemSounds/dock/drag to trash.aif"];
	}
	else
	{
		[self errorMessage:NSLocalizedString(@"Couldn't delete file",@"Title of the delete failure dialog")
		text:[NSString stringWithFormat:NSLocalizedString(@"The file \"%@\" could not be deleted.",@"Content of the delet failure dialog"),
		[filename lastPathComponent]]];
	}
}



-(IBAction)moveFile:(id)sender
{
	[self triggerDrawer:XeeMoveMode];
}

-(IBAction)copyFile:(id)sender
{
	[self triggerDrawer:XeeCopyMode];
}

-(void)triggerDrawer:(int)mode
{
	int newseg;
	if(mode==XeeCopyMode) newseg=0;
	else newseg=1;

	int state=[drawer state];

	if(state==NSDrawerClosedState||state==NSDrawerClosingState)
	{
		[drawer openOnEdge:NSMaxXEdge];
	}
	else
	{
		if([drawerseg selectedSegment]==newseg) [closebutton performClick:nil];
	}

	[drawerseg setSelectedSegment:newseg];
}

-(void)drawerWillOpen:(NSNotification *)notification
{
	[window makeFirstResponder:table];
	[imageview setNextKeyView:table];
	[[drawer contentView] setNextResponder:window];
}

-(void)drawerDidClose:(NSNotification *)notification
{
	[imageview setNextKeyView:nil];
}

-(void)destinationListClick:(id)sender
{
	if(currindex<0) return;
	if(fullscreenwindow) return; // just to be safe

	if([drawerseg selectedSegment]==0) drawer_mode=XeeCopyMode;
	else drawer_mode=XeeMoveMode;

	NSString *filename=[self currentFilename];
	int index=[sender selectedRow];

	if(index==0)
	{
		NSOpenPanel *panel=[NSOpenPanel openPanel];
		[panel setCanChooseDirectories:YES];
		[panel setCanChooseFiles:NO];
		[panel setCanCreateDirectories:YES];
		if(drawer_mode==XeeMoveMode) [panel setPrompt:NSLocalizedString(@"Move",@"Move button")];
		else if(drawer_mode==XeeCopyMode) [panel setPrompt:NSLocalizedString(@"Copy",@"Copy button and menuitem")];

		[panel beginSheetForDirectory:nil file:nil types:nil modalForWindow:window modalDelegate:self
		didEndSelector:@selector(destinationPanelEnd:returnCode:contextInfo:) contextInfo:[filename retain]];
	}
	else
	{
		NSString *destination=[[sender pathForRow:index] stringByAppendingPathComponent:[filename lastPathComponent]];
		[self attemptToTransferFile:filename to:destination mode:drawer_mode];
	}
}

-(void)destinationPanelEnd:(NSOpenPanel *)panel returnCode:(int)res contextInfo:(NSString *)filename
{
	if(res==NSOKButton)
	{
		NSString *destdir=[[panel filenames] objectAtIndex:0];
		NSString *destination=[destdir stringByAppendingPathComponent:[filename lastPathComponent]];

		[XeeDestinationView suggestInsertion:destdir];

		[self attemptToTransferFile:filename to:destination mode:drawer_mode];
	}
	[filename release];
}

-(void)attemptToTransferFile:(NSString *)filename to:(NSString *)destination mode:(int)mode
{
	if([filename isEqual:destination])
	{
		[self errorMessage:NSLocalizedString(@"File already there",@"Title of the move/copy to same folder dialog")
		text:NSLocalizedString(@"The source and destination locations are the same.",@"Content of the move/copy to same folder dialog")];
	}
	else
	{
		NSDictionary *destinfo=[[NSFileManager defaultManager] fileAttributesAtPath:destination traverseLink:YES];

		if(destinfo)
		{
			XeeImage *destimage=[XeeImage imageForFilename:destination];
			[collisionpanel run:window source:currimage destination:destimage mode:drawer_mode];
		}
		else
		{
//		[self performSelector:@selector() withObject: afterDelay:0];
			[self transferFile:filename to:destination mode:drawer_mode];
		}
	}
}

-(void)transferFile:(NSString *)filename to:(NSString *)destination mode:(int)mode
{
	if([[NSFileManager defaultManager] fileExistsAtPath:destination])
	{
		[[NSFileManager defaultManager] removeFileAtPath:destination handler:nil];
	}

	if(mode==XeeMoveMode)
	{
		if([[NSFileManager defaultManager] movePath:filename toPath:destination handler:nil])
		{
			// "moved" message in status bar
			[self playSound:@"/System/Library/Components/CoreAudio.component/Contents/Resources/SystemSounds/system/Volume Mount.aif"];
			[self removeFile:filename];
		}
		else
		{
			[self errorMessage:NSLocalizedString(@"Couldn't move file",@"Title of the move failure dialog")
			text:[NSString stringWithFormat:NSLocalizedString(@"The file \"%@\" could not be moved to the folder \"%@\".",@"Content of the move failure dialog"),
			[filename lastPathComponent],[destination stringByDeletingLastPathComponent]]];
		}
	}
	else
	{
		if([[NSFileManager defaultManager] copyPath:filename toPath:destination handler:nil])
		{
			// "copied" message in status bar
			[self playSound:@"/System/Library/Components/CoreAudio.component/Contents/Resources/SystemSounds/system/Volume Mount.aif"];
		}
		else
		{
			[self errorMessage:NSLocalizedString(@"Couldn't copy file",@"Title of the copy failure dialog")
			text:[NSString stringWithFormat:NSLocalizedString(@"The file \"%@\" could not be copied to the folder \"%@\".",@"Content of the copy failure dialog"),
			[filename lastPathComponent],[destination stringByDeletingLastPathComponent]]];
		}
	}
}



-(void)playSound:(NSString *)filename
{
	[self performSelector:@selector(actuallyPlaySound:) withObject:filename afterDelay:0];
}

-(void)actuallyPlaySound:(NSString *)filename
{
	[[[[NSSound alloc] initWithContentsOfFile:filename byReference:NO] autorelease] play];
}




/*-(IBAction)jpegAutoRotate:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[self jpegTransform:@"-a"];
}

-(IBAction)jpegRotateCW:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[self jpegTransform:@"-9"];
}

-(IBAction)jpegRotateCCW:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[self jpegTransform:@"-2"];
}

-(IBAction)jpegRotate180:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[self jpegTransform:@"-1"];
}

-(IBAction)jpegFlipHorizontal:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[self jpegTransform:@"-F"];
}

-(IBAction)jpegFlipVertical:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[self jpegTransform:@"-f"];
}

-(void)jpegTransform:(NSString *)option
{
	if(currindex<0) return;
	if(!currimage) return;
	if(![[currimage format] isEqual:@"JPEG"]) return;

	NSString *filename=[self currentFilename];
	NSTask *task=[NSTask launchedTaskWithLaunchPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"exiftran"]
	arguments:[NSArray arrayWithObjects:@"-ip",option,filename,nil]];

	[task waitUntilExit];

	if([task terminationStatus])
	{
		[self errorMessage:NSLocalizedString(@"JPEG Transform Failed",@"Title of the JPEG transformation failure dialog")
		text:[NSString stringWithFormat:NSLocalizedString(@"Couldn't transform the file \"%@\".",@"Content of the JPEG transformation failure dialog"),
		filename]];
	}
	[self reloadImage];
}*/

-(IBAction)launchAppFromMenu:(id)sender
{
	if(currindex<0) return;

	NSString *filename=[self currentFilename];
	NSString *app=[sender representedObject];

	[[NSWorkspace sharedWorkspace] openFile:filename withApplication:app];
}

-(IBAction)launchDefaultEditor:(id)sender
{
	if(currindex<0) return;

	NSString *filename=[self currentFilename];
	NSString *app=[(XeeDelegate *)[[NSApplication sharedApplication] delegate] defaultEditor];

	[[NSWorkspace sharedWorkspace] openFile:filename withApplication:app];
}



-(IBAction)closeWindowOrDrawer:(id)sender;
{
	int state=[drawer state];
	if(state==NSDrawerOpenState||state==NSDrawerOpeningState) [closebutton performClick:nil];
	else [super closeWindowOrDrawer:sender];
}



-(void)errorMessage:(NSString *)title text:(NSString *)text
{
	NSAlert *alert=[[[NSAlert alloc] init] autorelease];

	[alert setMessageText:title];
	[alert setInformativeText:text];
	[alert addButtonWithTitle:NSLocalizedString(@"OK","OK button")];

	[alert beginSheetModalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
}



-(NSArray *)makeToolbarItems
{
	XeeSegmentedItem *navitool=[XeeSegmentedItem itemWithIdentifier:@"navi"
	label:NSLocalizedString(@"Navigation",@"Navigation toolbar segment title")
	paletteLabel:NSLocalizedString(@"Navigation",@"Navigation toolbar segment title") segments:4];
	[navitool setSegment:0 imageName:@"tool_first" longLabel:NSLocalizedString(@"First Image",@"First Image toolbar button label") action:@selector(skipFirst:)];
	[navitool setSegment:1 imageName:@"tool_prev" longLabel:NSLocalizedString(@"Previous Image",@"Previous Image toolbar button label") action:@selector(skipPrev:)];
	[navitool setSegment:2 imageName:@"tool_next" longLabel:NSLocalizedString(@"Next Image",@"Next Image toolbar button label") action:@selector(skipNext:)];
	[navitool setSegment:3 imageName:@"tool_last" longLabel:NSLocalizedString(@"Last Image",@"Last Image toolbar button label") action:@selector(skipLast:)];
	[navitool setupView];

	XeeSegmentedItem *skiptool=[XeeSegmentedItem itemWithIdentifier:@"skip"
	label:NSLocalizedString(@"Prev Next",@"Prev/Next toolbar segment label")
	paletteLabel:NSLocalizedString(@"Prev/Next",@"Prev/Next toolbar segment title") segments:2];
	[skiptool setSegment:0 imageName:@"tool_prev" longLabel:NSLocalizedString(@"Previous Image",@"Previous Image toolbar button label") action:@selector(skipPrev:)];
	[skiptool setSegment:1 imageName:@"tool_next" longLabel:NSLocalizedString(@"Next Image",@"Next Image toolbar button label") action:@selector(skipNext:)];
	[skiptool setupView];

	XeeSegmentedItem *endtool=[XeeSegmentedItem itemWithIdentifier:@"end"
	label:NSLocalizedString(@"First Last",@"First/Last toolbar segment label")
	paletteLabel:NSLocalizedString(@"First/Last",@"First/Last toolbar segment title") segments:2];
	[endtool setSegment:0 imageName:@"tool_first" longLabel:NSLocalizedString(@"First Image",@"First Image toolbar button label") action:@selector(skipFirst:)];
	[endtool setSegment:1 imageName:@"tool_last" longLabel:NSLocalizedString(@"Last Image",@"Last Image toolbar button label") action:@selector(skipLast:)];
	[endtool setupView];

	XeeSegmentedItem *zoomtool=[XeeSegmentedItem itemWithIdentifier:@"zoom"
	label:NSLocalizedString(@"Zoom",@"Zoom toolbar segment title")
	paletteLabel:NSLocalizedString(@"Zoom",@"Zoom toolbar segment title") segments:4];
	[zoomtool setSegment:0 imageName:@"tool_zoomin" longLabel:NSLocalizedString(@"Zoom In",@"Zoom In toolbar button label") action:@selector(zoomIn:)];
	[zoomtool setSegment:1 imageName:@"tool_zoomout" longLabel:NSLocalizedString(@"Zoom Out",@"Zoom Out toolbar button label") action:@selector(zoomOut:)];
	[zoomtool setSegment:2 imageName:@"tool_zoomactual" longLabel:NSLocalizedString(@"Actual Size",@"Actual Size toolbar button label") action:@selector(zoomActual:)];
	[zoomtool setSegment:3 imageName:@"tool_zoomfit" longLabel:NSLocalizedString(@"Fit On Screen",@"Fit On Screen toolbar button label") action:@selector(zoomFit:)];
	[zoomtool setupView];

	XeeSegmentedItem *animtool=[XeeSegmentedItem itemWithIdentifier:@"anim"
	label:NSLocalizedString(@"Animation",@"Animation toolbar segment label")
	paletteLabel:NSLocalizedString(@"Animation And Frames",@"Animation toolbar segment title") segments:3];
	[animtool setSegment:0 imageName:@"tool_anim" longLabel:NSLocalizedString(@"Toggle Animation",@"Toggle Animation toolbar button label") action:@selector(toggleAnimation:)];
	[animtool setSegment:1 imageName:@"tool_nextframe" longLabel:NSLocalizedString(@"Next Frame",@"Next Frame toolbar button label") action:@selector(frameSkipNext:)];
	[animtool setSegment:2 imageName:@"tool_prevframe" longLabel:NSLocalizedString(@"Previous Frame",@"Previous toolbar button label") action:@selector(frameSkipPrev:)];
	[animtool setupView];

	XeeSegmentedItem *autotool=[XeeSegmentedItem itemWithIdentifier:@"auto"
	label:NSLocalizedString(@"Auto Rotation",@"Auto rotation toolbar segment label")
	paletteLabel:NSLocalizedString(@"Automatic Rotation",@"Auto rotation toolbar segment title") segments:1];
	[autotool setSegment:0 imageName:@"tool_autorot" longLabel:NSLocalizedString(@"Automatic Rotation",@"Automatic Rotation toolbar button label") action:@selector(autoRotate:)];
	[autotool setupView];

	XeeSegmentedItem *rotatetool=[XeeSegmentedItem itemWithIdentifier:@"rotate"
	label:NSLocalizedString(@"Rotation",@"Rotation segment label")
	paletteLabel:NSLocalizedString(@"Rotation",@"Rotation toolbar segment title") segments:3];
	[rotatetool setSegment:0 imageName:@"tool_cw" longLabel:NSLocalizedString(@"Rotate Clockwise",@"Rotate Clockwise toolbar button label") action:@selector(rotateCW:)];
	[rotatetool setSegment:1 imageName:@"tool_ccw" longLabel:NSLocalizedString(@"Rotate Counter-clockwise",@"Rotate Counter-clockwise toolbar button label") action:@selector(rotateCCW:)];
	[rotatetool setSegment:2 imageName:@"tool_flip" longLabel:NSLocalizedString(@"Rotate 180¼",@"Rotate 180 toolbar button label") action:@selector(rotate180:)];
	[rotatetool setupView];

	XeeSegmentedItem *deletetool=[XeeSegmentedItem itemWithIdentifier:@"delete"
	label:@"" paletteLabel:NSLocalizedString(@"Delete file",@"Delete file toolbar segment title") segments:1];
	[deletetool setSegment:0 label:@"Delete" longLabel:NSLocalizedString(@"Delete file",@"Delete file toolbar button label") action:@selector(askAndDelete:)];
	[deletetool setupView];

	XeeSegmentedItem *renametool=[XeeSegmentedItem itemWithIdentifier:@"rename"
	label:@"" paletteLabel:NSLocalizedString(@"Rename file",@"Rename file toolbar segment title") segments:1];
	[renametool setSegment:0 label:@"Rename" longLabel:NSLocalizedString(@"Rename file",@"Rename file toolbar button label") action:@selector(renameFileFromMenu:)];
	[renametool setupView];

	XeeSegmentedItem *copytool=[XeeSegmentedItem itemWithIdentifier:@"copy"
	label:@"" paletteLabel:NSLocalizedString(@"File Handling",@"Copy/move toolbar segment title") segments:2];
	[copytool setSegment:0 label:@"Copy" longLabel:NSLocalizedString(@"Copy file",@"Copy file toolbar button label") action:@selector(copyFile:)];
	[copytool setSegment:1 label:@"Move" longLabel:NSLocalizedString(@"Move file",@"Move file toolbar button label") action:@selector(moveFile:)];
	[copytool setupView];


	return [NSArray arrayWithObjects:
		navitool,skiptool,endtool,zoomtool,animtool,autotool,rotatetool,
		deletetool,renametool,copytool,
	0];
}

-(NSArray *)makeDefaultToolbarItemIdentifiers
{
	return [NSArray arrayWithObjects:
		@"skip",@"end",@"zoom",@"anim",NSToolbarFlexibleSpaceItemIdentifier,@"auto",@"rotate",
	0];
}

-(BOOL)validateAction:(SEL)action
{
	if(		action==@selector(skipNext:)||
			action==@selector(skip10Forward:)||
			action==@selector(skip100Forward:)||
			action==@selector(skipLast:)) return [dircontents count]>1&&currindex!=[dircontents count]-1;
	else if(action==@selector(skipPrev:)||
			action==@selector(skip10Back:)||
			action==@selector(skip100Back:)||
			action==@selector(skipFirst:)) return [dircontents count]>1&&currindex!=0;
	else if(action==@selector(skipRandom:)||
			action==@selector(skipRandomPrev:)) return [dircontents count]>1;
	else if(action==@selector(revealInFinder:)||
			action==@selector(renameFileFromMenu:)||
			action==@selector(deleteFileFromMenu:)||
			action==@selector(askAndDelete:)||
			action==@selector(moveFile:)||
			action==@selector(copyFile:)||
			action==@selector(launchAppFromMenu:)||
			action==@selector(launchDefaultEditor:)) return currindex>=0;
	else if(action==@selector(moveFile:)||
	        action==@selector(copyFile:)) return fullscreenwindow?NO:YES;

	return [super validateAction:action];
}



+(void)initialize
{
	if(!directorycontrollers) directorycontrollers=[[NSMutableArray alloc] initWithCapacity:16];
}

+(NSArray *)controllers { return directorycontrollers; }



static float minstep=1e10;

-(void)scrollWheel:(NSEvent *)event
{
	float step=[event deltaY];
	float absstep=fabsf(step);
	if(absstep<minstep) minstep=absstep;
	if(minstep<1) minstep=1;

	int n=-(int)((absstep+0.5)/minstep);
	if(signbit(step)) n=-n;

	[self skip:n];
}

@end



@implementation XeeDirectoryWindow

@end
