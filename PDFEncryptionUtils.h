#import <Foundation/Foundation.h>
#import <openssl/md5.h>
#import <openssl/aes.h>
#import "CSHandle.h"
#import "CSBufferedStreamHandle.h"

extern NSString *PDFMD5FinishedException;



@interface PDFMD5Engine:NSObject
{
	MD5_CTX md5;
	unsigned char digest_bytes[16];
	BOOL done;
}

+(PDFMD5Engine *)engine;
+(NSData *)digestForData:(NSData *)data;
+(NSData *)digestForBytes:(const void *)bytes length:(int)length;

-(id)init;

-(void)updateWithData:(NSData *)data;
-(void)updateWithBytes:(const void *)bytes length:(unsigned long)length;

-(NSData *)digest;
-(NSString *)hexDigest;

-(NSString *)description;

@end



@interface PDFRC4Engine:NSObject
{
	unsigned char s[256];
	int i,j;
}

+(PDFRC4Engine *)engineWithKey:(NSData *)key;

-(id)initWithKey:(NSData *)key;

-(NSData *)encryptedData:(NSData *)data;

-(void)encryptBytes:(unsigned char *)bytes length:(int)length;
-(void)skipBytes:(int)length;

@end



@interface PDFRC4Handle:CSHandle
{
	CSHandle *parent;
	PDFRC4Engine *rc4;
	NSData *key;
	off_t pos,startoffs;
}

-(id)initWithHandle:(CSHandle *)handle key:(NSData *)keydata;
-(void)dealloc;

-(off_t)offsetInFile;
-(BOOL)atEndOfFile;
-(void)seekToFileOffset:(off_t)offs;
-(int)readAtMost:(int)num toBuffer:(void *)buffer;

@end



@interface PDFAESHandle:CSBufferedStreamHandle
{
	CSHandle *parent;
	off_t startoffs;

	NSData *key,*iv;

	AES_KEY aeskey;
	unsigned char ivbuffer[16];
}

-(id)initWithHandle:(CSHandle *)handle key:(NSData *)keydata;
-(void)dealloc;

-(int)fillBufferAtOffset:(off_t)pos;

@end
