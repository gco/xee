#import "PDFEncryptionUtils.h"

NSString *PDFMD5FinishedException=@"PDFMD5FinishedException";



@implementation PDFMD5Engine

+(PDFMD5Engine *)engine { return [[[self class] new] autorelease]; }

+(NSData *)digestForData:(NSData *)data { return [self digestForBytes:[data bytes] length:[data length]]; }

+(NSData *)digestForBytes:(const void *)bytes length:(int)length
{
	PDFMD5Engine *md5=[[self class] new];
	[md5 updateWithBytes:bytes length:length];
	NSData *res=[md5 digest];
	[md5 release];
	return res;
}

-(id)init
{
	if(self=[super init])
	{
		MD5_Init(&md5);
		done=NO;
	}
	return self;
}

-(void)updateWithData:(NSData *)data { [self updateWithBytes:[data bytes] length:[data length]]; }

-(void)updateWithBytes:(const void *)bytes length:(unsigned long)length
{
	if(done) [NSException raise:PDFMD5FinishedException format:@"Attempted to update a finished %@ object",[self class]];
	MD5_Update(&md5,bytes,length);
}

-(NSData *)digest
{
	if(!done) { MD5_Final(digest_bytes,&md5); done=YES; }
	return [NSData dataWithBytes:digest_bytes length:16];
}

-(NSString *)hexDigest
{
	if(!done) { MD5_Final(digest_bytes,&md5); done=YES; }
	return [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
	digest_bytes[0],digest_bytes[1],digest_bytes[2],digest_bytes[3],
	digest_bytes[4],digest_bytes[5],digest_bytes[6],digest_bytes[7],
	digest_bytes[8],digest_bytes[9],digest_bytes[10],digest_bytes[11],
	digest_bytes[12],digest_bytes[13],digest_bytes[14],digest_bytes[15]];
}

-(NSString *)description
{
	if(done) return [NSString stringWithFormat:@"<%@ with digest %@>",[self class],[self hexDigest]];
	else return [NSString stringWithFormat:@"<%@, unfinished>",[self class]];
}

@end



@implementation PDFRC4Engine

+(PDFRC4Engine *)engineWithKey:(NSData *)key
{
	return [[[[self class] alloc] initWithKey:key] autorelease];
}

-(id)initWithKey:(NSData *)key
{
	if(self=[super init])
	{
		const unsigned char *keybytes=[key bytes];
		int keylength=[key length];

		for(i=0;i<256;i++) s[i]=i;

		j=0;
		for(i=0;i<256;i++)
		{
			j=(j+s[i]+keybytes[i%keylength])&255;
			int tmp=s[i]; s[i]=s[j]; s[j]=tmp;
		}

		i=j=0;
	}
	return self;
}

-(NSData *)encryptedData:(NSData *)data
{
	NSMutableData *res=[data mutableCopy];
	[self encryptBytes:[res mutableBytes] length:[res length]];
	return [NSData dataWithData:res];
}

-(void)encryptBytes:(unsigned char *)bytes length:(int)length
{
	for(int n=0;n<length;n++)
	{
		i=(i+1)&255;
		j=(j+s[i])&255;
		int tmp=s[i]; s[i]=s[j]; s[j]=tmp;
		bytes[n]^=s[(s[i]+s[j])&255];
	}
}

-(void)skipBytes:(int)length
{
	for(int n=0;n<length;n++)
	{
		i=(i+1)&255;
		j=(j+s[i])&255;
		int tmp=s[i]; s[i]=s[j]; s[j]=tmp;
	}
}

@end



@implementation PDFRC4Handle

-(id)initWithHandle:(CSHandle *)handle key:(NSData *)keydata
{
	if(self=[super initWithName:[handle name]])
	{
		parent=[handle retain];
		key=[keydata retain];
		rc4=[[PDFRC4Engine engineWithKey:key] retain];
		pos=0;
		startoffs=[parent offsetInFile];
	}
	return self;
}

-(void)dealloc
{
	[parent release];
	[rc4 release];
	[key release];
	[super dealloc];
}

-(off_t)offsetInFile { return pos; }

-(BOOL)atEndOfFile { return [parent atEndOfFile]; }

-(void)seekToFileOffset:(off_t)offs
{
	if(offs==pos) return;

	if(offs<pos)
	{
		[rc4 release];
		rc4=[[PDFRC4Engine engineWithKey:key] retain];
		[rc4 skipBytes:offs];
	}
	else [rc4 skipBytes:offs-pos];

	[parent seekToFileOffset:startoffs+offs];
	pos=offs;
}

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	int actual=[parent readAtMost:num toBuffer:buffer];
	[rc4 encryptBytes:buffer length:actual];
	return actual;
}

@end





@implementation PDFAESHandle

-(id)initWithHandle:(CSHandle *)handle key:(NSData *)keydata
{
	if(self=[super initWithName:[handle name]])
	{
		parent=[handle retain];
		key=[keydata retain];

		iv=[parent copyDataOfLength:16];
		startoffs=[parent offsetInFile];

		[self setBlockPointer:streambuffer];

		AES_set_decrypt_key([key bytes],[key length]*8,&aeskey);
	}
	return self;
}

-(void)dealloc
{
	[parent release];
	[key release];
	[iv release];
	[super dealloc];
}

-(void)resetBlockStream
{
	[parent seekToFileOffset:startoffs];
	memcpy(ivbuffer,[iv bytes],16);
}

-(int)produceBlockAtOffset:(off_t)pos
{
	uint8_t inbuf[16];
	[parent readBytes:16 toBuffer:inbuf];
	AES_cbc_encrypt(inbuf,streambuffer,16,&aeskey,ivbuffer,AES_DECRYPT);

	if([parent atEndOfFile])
	{
		int val=streambuffer[15];
		if(val>0&&val<=16)
		{
			for(int i=1;i<val;i++) if(streambuffer[15-val]!=val) return 0;
			return 16-val;
		}
		else return 0;
	}
	else return 16;
}

@end

