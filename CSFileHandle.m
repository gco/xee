#import "CSFileHandle.h"

#include <sys/stat.h>



@implementation CSFileHandle



+(CSFileHandle *)fileHandleForReadingAtPath:(NSString *)path
{ return [self fileHandleForPath:path modes:@"rb"]; }

+(CSFileHandle *)fileHandleForWritingAtPath:(NSString *)path
{ return [self fileHandleForPath:path modes:@"wb"]; }

+(CSFileHandle *)fileHandleForPath:(NSString *)path modes:(NSString *)modes
{
	if(!path) return nil;

	#ifdef __MINGW__
	FILE *fileh=_wfopen((const unichar*)[path fileSystemRepresentation],(const unichar*)[modes cStringUsingEncoding:NSUnicodeStringEncoding]);
	#else
	FILE *fileh=fopen([path fileSystemRepresentation],[modes UTF8String]);
	#endif

	if(!fileh) [NSException raise:@"CSCannotOpenFileException"
	format:@"Error attempting to open file \"%@\" in mode \"%@\".",path,modes];

	CSFileHandle *handle=[[[CSFileHandle alloc] initWithFilePointer:fileh closeOnDealloc:YES name:path] autorelease];
	if(handle) return handle;

	fclose(fileh);
	return nil;
}



-(id)initWithFilePointer:(FILE *)file closeOnDealloc:(BOOL)closeondealloc name:(NSString *)descname
{
	if(self=[super initWithName:descname])
	{
		fh=file;
 		close=closeondealloc;
	}
	return self;
}

-(void)dealloc
{
	if(fh&&close) fclose(fh);
	[super dealloc];
}






-(off_t)offsetInFile
{
	#ifdef __MINGW__
	return ftell(fh);
	#else
	return ftello(fh);
	#endif
}

-(off_t)fileSize
{
	struct stat s;
	if(fstat(fileno(fh),&s)) [self _raiseError];
	return s.st_size;
}



-(void)seekToFileOffset:(off_t)offs
{
	if(fseek(fh,offs,SEEK_SET)) [self _raiseError];
}

-(void)seekToEndOfFile
{
	if(fseek(fh,0,SEEK_END)) [self _raiseError];
}

-(void)pushBackByte:(int)byte
{
	if(ungetc(byte,fh)==EOF) [self _raiseError];
}

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	int n=fread(buffer,1,num,fh);
	if(n<=0) [self _raiseError];
	return n;
}

-(void)writeBytes:(int)num fromBuffer:(const void *)buffer
{
	if(fwrite(buffer,1,num,fh)!=num) [self _raiseError];
}



-(void)_raiseError
{
	if(feof(fh)) [self _raiseEOF];
	else [NSException raise:@"CSFileErrorException"
	format:@"Error while attempting to read file \"%@\": %s.",name,strerror(ferror(fh))];
}

-(FILE *)filePointer { return fh; }

@end
