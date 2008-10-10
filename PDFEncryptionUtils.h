#import <Foundation/Foundation.h>
#import <openssl/md5.h>
#import "CSHandle.h"

extern NSString *PDFUnsupportedEncryptionException;
extern NSString *PDFMD5FinishedException;

@class PDFParser,PDFObjectReference;

@interface PDFEncryptionHandler:NSObject
{
	NSDictionary *encrypt;
	NSData *permanentid;

	unsigned char key[5];

	BOOL needspassword;
}

-(id)initWithParser:(PDFParser *)parser;
-(void)dealloc;

-(BOOL)needsPassword;

-(NSData *)decryptedData:(NSData *)data reference:(PDFObjectReference *)ref;
-(CSHandle *)decryptedHandle:(CSHandle *)handle reference:(PDFObjectReference *)ref;

-(NSData *)keyForReference:(PDFObjectReference *)ref;
-(NSData *)userKey;
-(void)calculateKey:(NSString *)password;

@end




@interface PDFMD5Digest:NSObject
{
	MD5_CTX md5;
	unsigned char digest_bytes[16];
	BOOL done;
}

+(PDFMD5Digest *)MD5Digest;

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
