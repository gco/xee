#import <Cocoa/Cocoa.h>

@interface XeeFSRef:NSObject <NSCopying>
{
	FSRef ref;
	FSIterator iterator;
	int hash;
}

+(XeeFSRef *)refForPath:(NSString *)path;

-(id)initWithPath:(NSString *)path;
-(id)initWithFSRef:(FSRef *)fsref;

-(FSRef *)FSRef;

-(BOOL)isValid;
-(BOOL)isDirectory;
-(BOOL)isRemote;

-(NSString *)name;
-(NSString *)path;
-(NSURL *)URL;
-(XeeFSRef *)parent;

-(off_t)dataSize;
-(off_t)dataPhysicalSize;
-(off_t)resourceSize;
-(off_t)resourcePhysicalSize;

-(CFAbsoluteTime)creationTime;
-(CFAbsoluteTime)modificationTime;
-(CFAbsoluteTime)attributeModificationTime;
-(CFAbsoluteTime)accessTime;
-(CFAbsoluteTime)backupTime;

-(NSString *)HFSTypeCode;
-(NSString *)HFSCreatorCode;

-(BOOL)startReadingDirectoryWithRecursion:(BOOL)recursive;
-(void)stopReadingDirectory;
-(XeeFSRef *)nextDirectoryEntry;
-(NSArray *)directoryContents;

-(BOOL)isEqual:(XeeFSRef *)other;
-(NSComparisonResult)compare:(XeeFSRef *)other;
-(NSComparisonResult)compare:(XeeFSRef *)other options:(int)options;
-(unsigned)hash;

-(NSString *)description;

-(id)copyWithZone:(NSZone *)zone;

@end
