#import "XeeFSRef.h"

@implementation XeeFSRef

+(XeeFSRef *)refForPath:(NSString *)path
{
	return [[[XeeFSRef alloc] initWithPath:path] autorelease];
}

-(id)initWithPath:(NSString *)path
{
	if(self=[super init])
	{
		if(FSPathMakeRef((const UInt8 *)[path fileSystemRepresentation],&ref,NULL)!=noErr)
		{
			[self release];
			return nil;
		}
	}
	return self;
}

-(id)initWithFSRef:(FSRef *)fsref
{
	if(self=[super init])
	{
		ref=*fsref;
	}
	return self;
}

-(FSRef *)FSRef { return &ref; }

-(BOOL)isValid { return FSIsFSRefValid(&ref); }

-(BOOL)isDirectory
{
	return NO;
}

-(NSString *)path
{
	NSString *path=nil;
	CFURLRef url=CFURLCreateFromFSRef(kCFAllocatorDefault,&ref);
	if(url)
	{
		path=[(NSString *)CFURLCopyFileSystemPath(url,kCFURLPOSIXPathStyle) autorelease];
		CFRelease(url);
	}
	return path;
}

-(NSURL *)URL { return [(id)CFURLCreateFromFSRef(kCFAllocatorDefault,&ref) autorelease]; }

-(XeeFSRef *)parent
{
	FSRef parent;
	if(FSGetCatalogInfo(&ref,kFSCatInfoNone,NULL,NULL,NULL,&parent)!=noErr) return nil;
	return [[[XeeFSRef alloc] initWithFSRef:&parent] autorelease];
}

-(BOOL)isRemote
{
	FSCatalogInfo catinfo;
	FSGetCatalogInfo(&ref,kFSCatInfoVolume,&catinfo,NULL,NULL,NULL);

	HParamBlockRec pb;
	GetVolParmsInfoBuffer volparms;

	pb.ioParam.ioCompletion=NULL;
	pb.ioParam.ioNamePtr=NULL;
	pb.ioParam.ioVRefNum=catinfo.volume;
	pb.ioParam.ioBuffer=(Ptr)&volparms;
	pb.ioParam.ioReqCount=sizeof(volparms);

	if(PBHGetVolParmsSync(&pb)!=noErr) return NO;

	if((volparms.vMExtendedAttributes&((1<<bIsOnInternalBus)|(1<<bIsOnExternalBus)))==0) return YES;
	return NO;
}

-(NSArray *)directoryContents
{
	return nil;
}

-(BOOL)isEqual:(XeeFSRef *)other
{
	if(![other isKindOfClass:[self class]]) return NO;
	return FSCompareFSRefs(&ref,[other FSRef])==noErr;
}

-(NSComparisonResult)compare:(XeeFSRef *)other
{
	return [[self path] compare:[other path] options:NSCaseInsensitiveSearch|NSNumericSearch];
}

-(NSComparisonResult)compare:(XeeFSRef *)other options:(int)options
{
	return [[self path] compare:[other path] options:options];
}

-(unsigned)hash { return 0; }

-(NSString *)description { return [self path]; }

-(id)copyWithZone:(NSZone *)zone
{
	return [[XeeFSRef allocWithZone:zone] initWithFSRef:&ref];
}

@end
