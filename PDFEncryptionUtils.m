#import "PDFEncryptionUtils.h"
#import "PDFParser.h"
#import "NSDictionaryNumberExtension.h"

NSString *PDFUnsupportedEncryptionException=@"PDFUnsupportedEncryptionException";
NSString *PDFMD5FinishedException=@"PDFMD5FinishedException";

static const char PDFPasswordPadding[32]=
{
	0x28,0xBF,0x4E,0x5E,0x4E,0x75,0x8A,0x41,0x64,0x00,0x4E,0x56,0xFF,0xFA,0x01,0x08, 
	0x2E,0x2E,0x00,0xB6,0xD0,0x68,0x3E,0x80,0x2F,0x0C,0xA9,0xFE,0x64,0x53,0x69,0x7A
};


@implementation PDFEncryptionHandler

-(id)initWithParser:(PDFParser *)parser
{
	if(self=[super init])
	{
		encrypt=[[[parser trailerDictionary] objectForKey:@"Encrypt"] retain];
		permanentid=[[parser permanentID] retain];

		NSString *filter=[encrypt objectForKey:@"Filter"];
		int v=[encrypt intValueForKey:@"V" default:0];

		if(![filter isEqual:@"Standard"]||v!=1)
		{
			[self release];
			[NSException raise:PDFUnsupportedEncryptionException format:@"PDF encryption filter \"%@\" version %d is not supported.",filter,v];
		}

		[self calculateKey:@""];

		PDFRC4Engine *rc4=[PDFRC4Engine engineWithKey:[self userKey]];
		NSData *test=[rc4 encryptedData:[[encrypt objectForKey:@"U"] rawData]];
		needspassword=[test length]!=32||memcmp(PDFPasswordPadding,[test bytes],32);
	}
	return self;
}

-(void)dealloc
{
	[encrypt release];
	[permanentid release];
	[super dealloc];
}

-(BOOL)needsPassword { return needspassword; }



-(NSData *)decryptedData:(NSData *)data reference:(PDFObjectReference *)ref
{
	PDFRC4Engine *rc4=[PDFRC4Engine engineWithKey:[self keyForReference:ref]];
	return [rc4 encryptedData:data];
}

-(CSHandle *)decryptedHandle:(CSHandle *)handle reference:(PDFObjectReference *)ref
{
	return [[[PDFRC4Handle alloc] initWithHandle:handle key:[self keyForReference:ref]] autorelease];
}



-(NSData *)keyForReference:(PDFObjectReference *)ref
{
	int num=[ref number];
	int gen=[ref generation];
	unsigned char refbytes[5]={num&0xff,(num>>8)&0xff,(num>>16)&0xff,gen&0xff,(gen>>8)&0xff};

	PDFMD5Digest *md5=[PDFMD5Digest MD5Digest];
	[md5 updateWithBytes:key length:5];
	[md5 updateWithBytes:refbytes length:5];

	return [[md5 digest] subdataWithRange:NSMakeRange(0,10)];
}

-(NSData *)userKey { return [NSData dataWithBytes:key length:5]; }

-(void)calculateKey:(NSString *)password
{
	PDFMD5Digest *md5=[PDFMD5Digest MD5Digest];

	NSData *passdata=[password dataUsingEncoding:NSISOLatin1StringEncoding];
	int passlength=[passdata length];
	const unsigned char *passbytes=[passdata bytes];
	if(passlength<32)
	{
		[md5 updateWithBytes:passbytes length:passlength];
		[md5 updateWithBytes:PDFPasswordPadding length:32-passlength];
	}
	else [md5 updateWithBytes:passbytes length:32];

	[md5 updateWithData:[[encrypt objectForKey:@"O"] rawData]];

	unsigned int p=[encrypt unsignedIntValueForKey:@"P" default:0];
	unsigned char pbytes[4]={p&0xff,(p>>8)&0xff,(p>>16)&0xff,p>>24};
	[md5 updateWithBytes:pbytes length:4];

	[md5 updateWithData:permanentid];

	NSData *digest=[md5 digest];
	const unsigned char *digestbytes=[digest bytes];

	for(int i=0;i<5;i++) key[i]=digestbytes[i];
}

@end



@implementation PDFMD5Digest

+(PDFMD5Digest *)MD5Digest { return [[[self class] new] autorelease]; }

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
