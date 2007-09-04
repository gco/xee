#import <Cocoa/Cocoa.h>

@interface XeeFSRef:NSObject <NSCopying>
{
	FSRef ref;
}

+(XeeFSRef *)refForPath:(NSString *)path;

-(id)initWithPath:(NSString *)path;
-(id)initWithFSRef:(FSRef *)fsref;

-(FSRef *)FSRef;

-(BOOL)isValid;
-(BOOL)isDirectory;

-(NSString *)path;
-(XeeFSRef *)parent;

-(BOOL)isRemote;

-(NSArray *)directoryContents;

-(BOOL)isEqual:(XeeFSRef *)other;
-(NSComparisonResult)compare:(XeeFSRef *)other;
-(NSComparisonResult)compare:(XeeFSRef *)other options:(int)options;
-(unsigned)hash;

-(NSString *)description;

-(id)copyWithZone:(NSZone *)zone;

@end
