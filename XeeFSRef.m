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
		iterator=NULL;

		if(FSPathMakeRef((const UInt8 *)[path fileSystemRepresentation],&ref,NULL)!=noErr)
		{
			[self release];
			return nil;
		}

		FSCatalogInfo catinfo;
		FSGetCatalogInfo(&ref,kFSCatInfoNodeID,&catinfo,NULL,NULL,NULL)/*!=noErr)*/;
		hash=catinfo.nodeID;
	}
	return self;
}

-(id)initWithFSRef:(FSRef *)fsref
{
	if(self=[super init])
	{
		ref=*fsref;
		iterator=NULL;

		FSCatalogInfo catinfo;
		FSGetCatalogInfo(&ref,kFSCatInfoNodeID,&catinfo,NULL,NULL,NULL)/*!=noErr*/;
		hash=catinfo.nodeID;
	}
	return self;
}

-(void)dealloc
{
	if(iterator) FSCloseIterator(iterator);
	[super dealloc];
}

-(FSRef *)FSRef { return &ref; }

-(BOOL)isValid { return FSIsFSRefValid(&ref); }

-(BOOL)isDirectory
{
	FSCatalogInfo catinfo;
	if(FSGetCatalogInfo(&ref,kFSCatInfoNodeFlags,&catinfo,NULL,NULL,NULL)!=noErr) return NO;
	return catinfo.nodeFlags&kFSNodeIsDirectoryMask?YES:NO;
}

-(BOOL)isRemote
{
	FSCatalogInfo catinfo;
	if(FSGetCatalogInfo(&ref,kFSCatInfoVolume,&catinfo,NULL,NULL,NULL)!=noErr) return NO;

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



-(NSString *)name;
{
	HFSUniStr255 name;
	if(FSGetCatalogInfo(&ref,kFSCatInfoNone,NULL,&name,NULL,NULL)!=noErr) return nil;
	return [NSString stringWithCharacters:name.unicode length:name.length];
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



-(off_t)dataSize
{
	FSCatalogInfo catinfo;
	if(FSGetCatalogInfo(&ref,kFSCatInfoDataSizes,&catinfo,NULL,NULL,NULL)!=noErr) return 0;
	return catinfo.dataLogicalSize;
}

-(off_t)dataPhysicalSize
{
	FSCatalogInfo catinfo;
	if(FSGetCatalogInfo(&ref,kFSCatInfoDataSizes,&catinfo,NULL,NULL,NULL)!=noErr) return 0;
	return catinfo.dataPhysicalSize;
}

-(off_t)resourceSize
{
	FSCatalogInfo catinfo;
	if(FSGetCatalogInfo(&ref,kFSCatInfoDataSizes,&catinfo,NULL,NULL,NULL)!=noErr) return 0;
	return catinfo.rsrcLogicalSize;
}

-(off_t)resourcePhysicalSize
{
	FSCatalogInfo catinfo;
	if(FSGetCatalogInfo(&ref,kFSCatInfoDataSizes,&catinfo,NULL,NULL,NULL)!=noErr) return 0;
	return catinfo.rsrcPhysicalSize;
}



-(CFAbsoluteTime)creationTime
{
	FSCatalogInfo catinfo;
	if(FSGetCatalogInfo(&ref,kFSCatInfoCreateDate,&catinfo,NULL,NULL,NULL)!=noErr) return 0;
	CFAbsoluteTime res;
	UCConvertUTCDateTimeToCFAbsoluteTime(&catinfo.createDate,&res);
	return res;
}

-(CFAbsoluteTime)modificationTime
{
	FSCatalogInfo catinfo;
	if(FSGetCatalogInfo(&ref,kFSCatInfoAllDates,&catinfo,NULL,NULL,NULL)!=noErr) return 0;
	CFAbsoluteTime res;
	UCConvertUTCDateTimeToCFAbsoluteTime(&catinfo.contentModDate,&res);
	return res;
}

-(CFAbsoluteTime)attributeModificationTime
{
	FSCatalogInfo catinfo;
	if(FSGetCatalogInfo(&ref,kFSCatInfoAllDates,&catinfo,NULL,NULL,NULL)!=noErr) return 0;
	CFAbsoluteTime res;
	UCConvertUTCDateTimeToCFAbsoluteTime(&catinfo.attributeModDate,&res);
	return res;
}

-(CFAbsoluteTime)accessTime
{
	FSCatalogInfo catinfo;
	if(FSGetCatalogInfo(&ref,kFSCatInfoAccessDate,&catinfo,NULL,NULL,NULL)!=noErr) return 0;
	CFAbsoluteTime res;
	UCConvertUTCDateTimeToCFAbsoluteTime(&catinfo.accessDate,&res);
	return res;
}

-(CFAbsoluteTime)backupTime
{
	FSCatalogInfo catinfo;
	if(FSGetCatalogInfo(&ref,kFSCatInfoBackupDate,&catinfo,NULL,NULL,NULL)!=noErr) return 0;
	CFAbsoluteTime res;
	UCConvertUTCDateTimeToCFAbsoluteTime(&catinfo.backupDate,&res);
	return res;
}


-(NSString *)HFSTypeCode
{
	FSCatalogInfo catinfo;
	if(FSGetCatalogInfo(&ref,kFSCatInfoFinderInfo,&catinfo,NULL,NULL,NULL)!=noErr) return nil;
	struct FileInfo *info=(struct FileInfo *)&catinfo.finderInfo;
	OSType type=info->fileType;
	return [NSString stringWithFormat:@"%c%c%c%c",(type>>24)&0xff,(type>>16)&0xff,(type>>8)&0xff,type&0xff];
}

-(NSString *)HFSCreatorCode
{
	FSCatalogInfo catinfo;
	if(FSGetCatalogInfo(&ref,kFSCatInfoFinderInfo,&catinfo,NULL,NULL,NULL)!=noErr) return nil;
	struct FileInfo *info=(struct FileInfo *)&catinfo.finderInfo;
	OSType type=info->fileType;
	return [NSString stringWithFormat:@"%c%c%c%c",(type>>24)&0xff,(type>>16)&0xff,(type>>8)&0xff,type&0xff];
}


-(BOOL)startReadingDirectoryWithRecursion:(BOOL)recursive
{
	if(iterator) FSCloseIterator(iterator);
	// "Iteration over subtrees which do not originate at the root directory of a volume are not currently supported"
	if(FSOpenIterator(&ref,recursive?kFSIterateSubtree:kFSIterateFlat,&iterator)!=noErr) return NO;
	return YES;
}

-(void)stopReadingDirectory
{
	if(iterator) FSCloseIterator(iterator);
	iterator=NULL;
}

-(XeeFSRef *)nextDirectoryEntry
{
	if(!iterator) return nil;

	FSRef newref;
	ItemCount num;
	OSErr err=FSGetCatalogInfoBulk(iterator,1,&num,NULL,kFSCatInfoNone,NULL,&newref,NULL,NULL);
	// ignoring num

	if(err==errFSNoMoreItems)
	{
		FSCloseIterator(iterator);
		iterator=NULL;
		return nil;
	}
	else if(err!=noErr) return nil;

	return [[[XeeFSRef alloc] initWithFSRef:&newref] autorelease];
}

-(NSArray *)directoryContents
{
	if(![self startReadingDirectoryWithRecursion:NO]) return nil;

	NSMutableArray *array=[NSMutableArray array];
	XeeFSRef *entry;
	while(entry=[self nextDirectoryEntry]) [array addObject:entry];

	return array;
}



-(BOOL)isEqual:(XeeFSRef *)other
{
//	if(![other isKindOfClass:[self class]]) return NO;
	//if(![self isValid]||![other isValid]) return NO; // This is REALLY SLOW for some reason.
	if(hash!=other->hash) return NO;
	return FSCompareFSRefs(&ref,&other->ref)==noErr;
}

-(NSComparisonResult)compare:(XeeFSRef *)other
{
	return [[self path] compare:[other path] options:NSCaseInsensitiveSearch|NSNumericSearch];
}

-(NSComparisonResult)compare:(XeeFSRef *)other options:(int)options
{
	return [[self path] compare:[other path] options:options];
}

-(unsigned)hash { return hash; }

-(NSString *)description { return [self path]; }

-(id)copyWithZone:(NSZone *)zone
{
	return [[XeeFSRef allocWithZone:zone] initWithFSRef:&ref];
}

@end
