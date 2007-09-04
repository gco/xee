#import "XeeDreamcastLoader.h"


@implementation XeeDreamcastImage

+(NSArray *)fileTypes
{
	return [NSArray arrayWithObjects:@"pvr",nil];
}

+(BOOL)canOpenFile:(NSString *)name firstBlock:(NSData *)block attributes:(NSDictionary *)attributes
{
	if([block length]>16)
	{
		uint32 magic=XeeBEUInt32([block bytes]);
		if(magic=='GBIX') return YES;
		if(magic=='PVRT') return YES;
	}

	return NO;
}

-(SEL)initLoader
{
	CSFileHandle *fh=[self fileHandle];

	uint32 magic=[fh readID];
	if(magic=='GBIX')
	{
		uint32 size=[fh readUInt32LE];
		[fh skipBytes:size];
		magic=[fh readID];
	}

	if(magic!='PVRT') return NULL;

	uint32 length=[fh readUInt32LE];
	uint32 type=[fh readUInt32LE];
	width=[fh readUInt16LE];
	height=[fh readUInt16LE];

	[self setFormat:@"Dreamcast PVR"];

	switch(type&0xff)
	{
		case 0:
			[self setDepth:@"1:5:5:5 bit ARGB" iconName:@"depth_rgba"];
			return @selector(loadARGB1555:);
		case 1:
			[self setDepth:@"5:6:5 bit RGB" iconName:@"depth_rgb"];
			return @selector(loadRGB565:);
		case 2:
			[self setDepthRGBA:4];
			return @selector(loadARGB4444:);
		case 3:
			[self setDepth:@"YUV422" iconName:@"depth_rgb"];
			return @selector(loadARGB4444:);
		case 4: // BUMP
		case 5: // 4BPP
			[self setDepthIndexed:16];
			return @selector(loadARGB4444:);
		case 6: // 8BPP
			[self setDepthIndexed:256];
			return @selector(loadARGB4444:);
		default:
			return NULL;
	}

//	current_line=0;

	return @selector(startLoading);
}

-(void)deallocLoader
{
}

-(SEL)startLoading
{
	return NULL;
}

-(SEL)load
{
	return NULL;
}


@end


#if 0

/*
	PowerVR texture Susie-plugin

	(c) 2000 by BERO

	susie by takechin http://www.digitalpad.co.jp/~takechin/
	pvr hdr by loser http://www.consoledev.com/loser-console/dc/
	twiddled decode by macsus http://mc.pp.se/dc/
	plugin skelton by 43T http://www.asahi-net.or.jp/~kh4s-smz/
*/


/***************************************************************************
 * SUSIE32 '00IN' Plug-in for BMP(8bit, 24bitÇÃÇ›)                         *
 * 2000.12.05                                                              *
 ***************************************************************************/
#include <windows.h>
#include <string.h>

typedef struct {
	BYTE  id[4];
	DWORD length;
	BYTE  type[4];
	WORD width;
	WORD height;
} PVRHDR;

#define	SKIP_GBIX(data) \
	if (memcmp(data,"GBIX",4)==0) {\
		long size = ((long*)data)[1]; \
		data+=size+8; \
	}

enum {ARGB1555,RGB565,ARGB4444,YUV422,BUMP,PAL4,PAL8};


#ifndef CONV
/*-------------------------------------------------------------------------*/
/* Ç±ÇÃPluginÇÃèÓïÒ                                                        */
/*-------------------------------------------------------------------------*/
const char *pluginfo[] = {
    "00IN",                     /* Plug-in APIÉoÅ[ÉWÉáÉì */
    "PVR - DreamCast Texture by BERO", /* Plug-inñºÅAÉoÅ[ÉWÉáÉìãyÇ— copyright */
    "*.PVR",                    /* ë„ï\ìIÇ»ägí£éq ("*.JPG" "*.JPG;*.JPEG" Ç»Ç«) */
    "DreamCast Texture (*.PVR)",          /* ÉtÉ@ÉCÉãå`éÆñº */
};

/*-------------------------------------------------------------------------*/
/* âÊëúèÓïÒç\ë¢ëÃ                                                          */
/*-------------------------------------------------------------------------*/
#pragma pack(push)
#pragma pack(1) //ç\ë¢ëÃÇÃÉÅÉìÉoã´äEÇ1ÉoÉCÉgÇ…Ç∑ÇÈ
typedef struct PictureInfo {
    long left,top;       // âÊëúÇìWäJÇ∑ÇÈà íu
    long width;          // âÊëúÇÃïù(pixel)
    long height;         // âÊëúÇÃçÇÇ≥(pixel)
    WORD x_density;      // âÊëfÇÃêÖïΩï˚å¸ñßìx
    WORD y_density;      // âÊëfÇÃêÇíºï˚å¸ñßìx
    short colorDepth;    // âÊëfìñÇΩÇËÇÃbitêî
    HLOCAL hInfo;        // âÊëúì‡ÇÃÉeÉLÉXÉgèÓïÒ
} PictureInfo;
#pragma pack(pop)

/*-------------------------------------------------------------------------*/
/* ÉGÉâÅ[ÉRÅ[Éh                                                            */
/*-------------------------------------------------------------------------*/
#define SPI_NO_FUNCTION       -1  /* ÇªÇÃã@î\ÇÕÉCÉìÉvÉäÉÅÉìÉgÇ≥ÇÍÇƒÇ¢Ç»Ç¢ */
#define SPI_ALL_RIGHT          0  /* ê≥èÌèIóπ */
#define SPI_ABORT              1  /* ÉRÅ[ÉãÉoÉbÉNä÷êîÇ™îÒ0Çï‘ÇµÇΩÇÃÇ≈ìWäJÇíÜé~ÇµÇΩ */
#define SPI_NOT_SUPPORT        2  /* ñ¢ímÇÃÉtÉHÅ[É}ÉbÉg */
#define SPI_OUT_OF_ORDER       3  /* ÉfÅ[É^Ç™âÛÇÍÇƒÇ¢ÇÈ */
#define SPI_NO_MEMORY          4  /* ÉÅÉÇÉäÅ[Ç™ämï€èoóàÇ»Ç¢ */
#define SPI_MEMORY_ERROR       5  /* ÉÅÉÇÉäÅ[ÉGÉâÅ[ */
#define SPI_FILE_READ_ERROR    6  /* ÉtÉ@ÉCÉãÉäÅ[ÉhÉGÉâÅ[ */
#define	SPI_WINDOW_ERROR       7  /* ëãÇ™äJÇØÇ»Ç¢ (îÒåˆäJÇÃÉGÉâÅ[ÉRÅ[Éh) */
#define SPI_OTHER_ERROR        8  /* ì‡ïîÉGÉâÅ[ */
#define	SPI_FILE_WRITE_ERROR   9  /* èëÇ´çûÇ›ÉGÉâÅ[ (îÒåˆäJÇÃÉGÉâÅ[ÉRÅ[Éh) */
#define	SPI_END_OF_FILE       10  /* ÉtÉ@ÉCÉãèIí[ (îÒåˆäJÇÃÉGÉâÅ[ÉRÅ[Éh) */

/*-------------------------------------------------------------------------*/
/* '00IN'ä÷êîÇÃÉvÉçÉgÉ^ÉCÉvêÈåæ                                            */
/*-------------------------------------------------------------------------*/
typedef int (CALLBACK *SPI_PROGRESS)(int, int, long);
    int __declspec(dllexport) WINAPI GetPluginInfo
            (int infono, LPSTR buf, int buflen);
    int __declspec(dllexport) WINAPI IsSupported(LPSTR filename, DWORD dw);
    int __declspec(dllexport) WINAPI GetPictureInfo
            (LPSTR buf,long len, unsigned int flag, PictureInfo *lpInfo);
    int __declspec(dllexport) WINAPI GetPicture
            (LPSTR buf,long len, unsigned int flag,
             HANDLE *pHBInfo, HANDLE *pHBm,
             SPI_PROGRESS lpPrgressCallback, long lData);
    int __declspec(dllexport) WINAPI GetPreview
            (LPSTR buf,long len, unsigned int flag,
             HANDLE *pHBInfo, HANDLE *pHBm,
             SPI_PROGRESS lpPrgressCallback, long lData);

//---------------------------------------------------------------------------
BOOL APIENTRY DllMain(HANDLE hModule, DWORD ul_reason_for_call, LPVOID lpReserved)
{
    return TRUE;
}
//---------------------------------------------------------------------------

/***************************************************************************
 * âÊëúå`éÆàÀë∂ÇÃèàóùÅB                                                    *
 * Å`Exä÷êîÇâÊëúå`éÆÇ…çáÇÌÇπÇƒèëÇ´ä∑Ç¶ÇÈÅB                                *
 ***************************************************************************/
//---------------------------------------------------------------------------
//ÉwÉbÉ_Çå©ÇƒëŒâûÉtÉHÅ[É}ÉbÉgÇ©ämîFÅB
//ëŒâûÇµÇƒÇ¢ÇÈÇ‡ÇÃÇ»ÇÁtrueÅAÇªÇ§Ç≈Ç»ÇØÇÍÇŒfalseÅAÇï‘Ç∑ÅB
//filnameÇÕÉtÉ@ÉCÉãñºÇ≈ÅANULLÇ™ì¸Ç¡ÇƒÇ¢ÇÈÇ±Ç∆Ç‡Ç†ÇÈÅB
//dataÇÕÉtÉ@ÉCÉãÇÃÉwÉbÉ_Ç≈ÅAÉTÉCÉYÇÕ2000ÉoÉCÉgà»è„ÅB
#define HEADBUF_SIZE 2000 /* 2kbyte=2048byte? */

BOOL IsSupportedEx(char *filename, char *data)
{
	SKIP_GBIX(data);
	if (memcmp(data,"PVRT",4)!=0) return FALSE;

    return TRUE;
}

static	char *str_table[]={"ARGB1555","RGB565","ARGB4444","YUV422","BUMP","PAL4","PAL8"};
//---------------------------------------------------------------------------
//âÊëúÉtÉ@ÉCÉãÇÃèÓïÒÇèëÇ´çûÇ›ÅAÉGÉâÅ[ÉRÅ[ÉhÇï‘Ç∑ÅB
//dataÇÕÉtÉ@ÉCÉãÉCÉÅÅ[ÉWÇ≈ÅAÉTÉCÉYÇÕdatasizeÉoÉCÉgÅB
int GetPictureInfoEx(long datasize, struct PictureInfo *lpInfo, char *data)
{
    HLOCAL htxt;
    char *txt;
    char str[] = "test";
	PVRHDR *hdr;
	static int depth_table[]={16,16,16,16,8,8/*?*/,4,8};

	SKIP_GBIX(data);
	if (memcmp(data,"PVRT",4)!=0) return SPI_NOT_SUPPORT;

    hdr = (PVRHDR*)data;

    lpInfo->left       = 0;
    lpInfo->top        = 0;
    lpInfo->width      = hdr->width;
    lpInfo->height     = hdr->height;
    lpInfo->x_density  = 0;
    lpInfo->y_density  = 0;
    lpInfo->colorDepth = depth_table[hdr->type[0]];
#if 1
    //ÉRÉÅÉìÉgÇ»Ç«ÇÃì‡ë†ÉeÉLÉXÉgÇ™ñ≥Ç¢èÍçá
    lpInfo->hInfo      = NULL;
#else
    //"BMP"ÇÃÉvÉâÉOÉCÉìÇ»ÇÃÇ≈ÅAÇ±ÇÃÉvÉâÉOÉCÉìÇ™èàóùÇµÇΩÇÃÇ©ïsñæäm
    //Ç±ÇÃÉvÉâÉOÉCÉìÇ™èàóùÇµÇΩèÿñæÇ…ì‡ë†ÉeÉLÉXÉgÇèëÇ´Ç±Çﬁ
    htxt = LocalAlloc(LMEM_MOVEABLE, strlen(str)+1);
    txt = (char *)LocalLock(htxt);
    strcpy(txt, str);
    lpInfo->hInfo      = htxt;
    LocalUnlock(htxt);
#endif

    return SPI_ALL_RIGHT;
}


//---------------------------------------------------------------------------
//âÊëúÉtÉ@ÉCÉãÇDIBÇ…ïœä∑ÇµÅAÉGÉâÅ[ÉRÅ[ÉhÇï‘Ç∑ÅB
//dataÇÕÉtÉ@ÉCÉãÉCÉÅÅ[ÉWÇ≈ÅAÉTÉCÉYÇÕdatasizeÉoÉCÉgÅB
int GetPictureEx(long datasize, HANDLE *pHBInfo, HANDLE *pHBm,
             SPI_PROGRESS lpPrgressCallback, long lData, char *data)
{

    unsigned int info_size;
    unsigned int img_size;
    BITMAPINFOHEADER *pInfo;
    char *pBm;
	PVRHDR *hdr;
	int bits;

    if (lpPrgressCallback != NULL)
        if (lpPrgressCallback(0, 1, lData)) //0%
            return SPI_ABORT;

	SKIP_GBIX(data);
	hdr = (PVRHDR*)data;

    *pHBInfo = LocalAlloc(LMEM_MOVEABLE, sizeof(BITMAPINFOHEADER));
    if (*pHBInfo==NULL) return SPI_NO_MEMORY;

    pInfo = LocalLock(*pHBInfo);
    pvr2bmphdr(pInfo,hdr);
    img_size = pInfo->biSizeImage;
    LocalUnlock(*pHBInfo);

    *pHBm    = LocalAlloc(LMEM_MOVEABLE, img_size);
    if (*pHBm == NULL) {
        if (*pHBInfo != NULL) LocalFree(*pHBInfo);
        return SPI_NO_MEMORY;
    }

    //ÉÅÉÇÉäÇÉçÉbÉN
    pBm   = LocalLock(*pHBm);
    pvr2bmp(pBm,hdr);
    LocalUnlock(*pHBm);

    //ÉÅÉÇÉäÇÉAÉìÉçÉbÉN

    if (lpPrgressCallback != NULL)
        if (lpPrgressCallback(1, 1, lData)) //100%
            return SPI_ABORT;
            
    return SPI_ALL_RIGHT;
}
//---------------------------------------------------------------------------

/***************************************************************************
 * SPIä÷êî                                                                 *
 * åàÇ‹ÇËêÿÇ¡ÇΩèàóùÇÕÇ±ÇøÇÁÇ≈çœÇ‹ÇπÇƒÇ¢ÇÈÅB                                *
 ***************************************************************************/
//---------------------------------------------------------------------------
int WINAPI GetPluginInfo(int infono, LPSTR buf, int buflen)
{
    if (infono < 0 || infono >= (sizeof(pluginfo) / sizeof(char *))) 
        return 0;

    lstrcpyn(buf, pluginfo[infono], buflen);

    return lstrlen(buf);
}
//---------------------------------------------------------------------------
int WINAPI IsSupported(LPSTR filename, DWORD dw)
{
    char *data;
    char buff[HEADBUF_SIZE];

    if ((dw & 0xFFFF0000) == 0) {
    /* dwÇÕÉtÉ@ÉCÉãÉnÉìÉhÉã */
        DWORD ReadBytes;
        memset(buff, 0, HEADBUF_SIZE);
        if (!ReadFile((HANDLE)dw, buff, HEADBUF_SIZE, &ReadBytes, NULL)) {
            return 0;
        }
        data = buff;
    } else {
    /* dwÇÕÉoÉbÉtÉ@Ç÷ÇÃÉ|ÉCÉìÉ^ */
        data = (char *)dw;
    }


    /* ÉtÉHÅ[É}ÉbÉgämîF */
    if (IsSupportedEx(filename, data)) return 1;

    return 0;
}
//---------------------------------------------------------------------------
int WINAPI GetPictureInfo
(LPSTR buf, long len, unsigned int flag, struct PictureInfo *lpInfo)
{
    int ret = SPI_OTHER_ERROR;
    char *data;
    char *filename;
    long datasize;

    if ((flag & 7) == 0) {
    /* bufÇÕÉtÉ@ÉCÉãñº */
        HANDLE hf;
        DWORD ReadBytes;
        hf = CreateFile(buf, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
        if (hf == INVALID_HANDLE_VALUE) return SPI_FILE_READ_ERROR;
        datasize = GetFileSize(hf, NULL) -len;
        if (datasize < 0) {
            CloseHandle(hf);
            return SPI_NOT_SUPPORT;
        }
        SetFilePointer(hf, len, NULL, FILE_BEGIN);

        data = (char *)LocalAlloc(LMEM_FIXED, datasize);
        if (data == NULL) {
            CloseHandle(hf);
            return SPI_NO_MEMORY;
        }
        if (!ReadFile(hf, data, datasize, &ReadBytes, NULL)) {
            CloseHandle(hf);
            LocalFree(data);
            return SPI_FILE_READ_ERROR;
        }
        CloseHandle(hf);
        filename = buf;
    } else {
    /* bufÇÕÉtÉ@ÉCÉãÉCÉÅÅ[ÉWÇ÷ÇÃÉ|ÉCÉìÉ^ */
        data = (char *)buf;
        datasize = len;
        filename = NULL;
    }

    /* àÍâûÉtÉHÅ[É}ÉbÉgämîF */
    if (!IsSupportedEx(filename, data)) {
        ret = SPI_NOT_SUPPORT;
    } else {
        ret = GetPictureInfoEx(datasize, lpInfo, data);
    }

    if ((flag & 7) == 0) LocalFree(data);

    return ret;
}
//---------------------------------------------------------------------------
int WINAPI GetPicture(
        LPSTR buf, long len, unsigned int flag, 
        HANDLE *pHBInfo, HANDLE *pHBm,
        SPI_PROGRESS lpPrgressCallback, long lData)
{
    int ret = SPI_OTHER_ERROR;
    char *data;
    char *filename;
    long datasize;

    if ((flag & 7) == 0) {
    /* bufÇÕÉtÉ@ÉCÉãñº */
#ifdef USE_MMAP
		/* memory mapped file */
		HANDLE hShare = OpenFileMapping(FILE_MAP_READ,FALSE,buf);
		data = MapViewOfFile(hShare,FILE_MAP_READ,0,len,datasize);
#else
		/* file io */
        HANDLE hf;
        DWORD ReadBytes;
        hf = CreateFile(buf, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
        if (hf == INVALID_HANDLE_VALUE) return SPI_FILE_READ_ERROR;
        datasize = GetFileSize(hf, NULL) -len;
        if (datasize < 0) {
            CloseHandle(hf);
            return SPI_NOT_SUPPORT;
        }
        SetFilePointer(hf, len, NULL, FILE_BEGIN);

        data = (char *)LocalAlloc(LMEM_FIXED, datasize);
        if (data == NULL) {
            CloseHandle(hf);
            return SPI_NO_MEMORY;
        }
        if (!ReadFile(hf, data, datasize, &ReadBytes, NULL)) {
            CloseHandle(hf);
            LocalFree(data);
            return SPI_FILE_READ_ERROR;
        }

        CloseHandle(hf);
#endif
        filename = buf;
    } else {
    /* bufÇÕÉtÉ@ÉCÉãÉCÉÅÅ[ÉWÇ÷ÇÃÉ|ÉCÉìÉ^ */
        data = buf;
        datasize = len;
        filename = NULL;
    }

    /* àÍâûÉtÉHÅ[É}ÉbÉgämîF */
    if (!IsSupportedEx(filename, data)) {
        ret = SPI_NOT_SUPPORT;
    } else {
        ret = GetPictureEx(datasize, pHBInfo, pHBm, lpPrgressCallback, lData, data);
    }

    if ((flag & 7) == 0) {
#ifdef USE_MMAP
		/* memory mapped file */
		UnMapViewOfFile(data);
		CloseHandle(hShare);
#else
		LocalFree(data);
#endif
	}

    return ret;
}
//---------------------------------------------------------------------------
int WINAPI GetPreview(
    LPSTR buf, long len, unsigned int flag,
    HANDLE *pHBInfo, HANDLE *pHBm,
    SPI_PROGRESS lpPrgressCallback, long lData)
{
    return SPI_NO_FUNCTION;
}
//---------------------------------------------------------------------------

#else

#include <stdio.h>
#include <stdlib.h>
int pvr2bmpfile(char *infile,char *outfile)
{
	FILE *in,*out;
	char *buf,*data,*pBm;
	int fsize,img_size;
	PVRHDR *hdr;
	BITMAPINFOHEADER bmih;
	BITMAPFILEHEADER bf;

	in = fopen(infile,"rb");
	if (in==NULL) return -1;

	fseek(in,0,SEEK_END);
	fsize = ftell(in);
	fseek(in,0,SEEK_SET);

	buf = malloc(fsize);
	fread(buf,1,fsize,in);
	fclose(in);

	data = buf;
	SKIP_GBIX(data);
	if (memcmp(data,"PVRT",4)) return -1;
	hdr = (PVRHDR*)data;

	pvr2bmphdr(&bmih,hdr);

	img_size = bmih.biSizeImage;
	pBm = malloc(img_size);

	pvr2bmp(pBm,hdr);

	out = fopen(outfile,"wb");
	if (out==NULL) return -1;

	bf.bfType = 'B'+'M'*256;
	bf.bfSize = img_size + sizeof(bmih);
	bf.bfReserved1 = 0;
	bf.bfReserved2 = 0;
	bf.bfOffBits = sizeof(bmih) + sizeof(bf);

	fwrite(&bf,1,sizeof(bf),out);
	fwrite(&bmih,1,sizeof(bmih),out);
	fwrite(pBm,1,img_size,out);

	fclose(out);
	
	free(pBm);
	free(buf);

	return 0;
}

int main(int argc,char **argv)
{
	int i;

	if (argc<2) {
		printf("DreamCast PVR->BMP converter by bero\n"
		" pvr2bmp <infile>\n"
		"http://www.geocities.co.jp/Playtown/2004/\n"
		);
		return -1;
	}

	for(i=1;i<argc;i++) {
		char *infile = argv[i];
		char *p,outfile[256];

		p = strrchr(infile,'\\');
		if (p) p++; else p=infile;
		strcpy(outfile,p);

		p = strrchr(outfile,'.');
		if (!p) p = outfile+strlen(outfile);
		strcpy(p,".bmp");

		pvr2bmpfile(infile,outfile);
	}
	return 0;
}

#endif

static int calc_n(int n)
{
	int sum = 1;
	while(n) {
		n>>=1;
		sum +=n*n;
	}
	return sum;
}

typedef struct {
	int rshift,rmask;
	int gshift,gmask;
	int bshift,bmask;
} SHIFTTBL;

const static SHIFTTBL shifttbl[]= {
	{ /* ARGB1555 */
		7,0xf8,
		2,0xf8,
		3,0xf8
	},{
		/* RGB565 */
		8,0xf8,
		3,0xfc,
		3,0xf8
	},{
		/* ARGB4444 */
		4,0xf0,
		0,0xf0,
		4,0xf0
	}
};

/* form marcus tatest */
static void init_twiddletab(int *twiddletab)
{
	int x;
#if 0
  for(x=0; x<1024; x++)
    twiddletab[x] = (x&1)|((x&2)<<1)|((x&4)<<2)|((x&8)<<3)|((x&16)<<4)|
      ((x&32)<<5)|((x&64)<<6)|((x&128)<<7)|((x&256)<<8)|((x&512)<<9);
#else
	for(x=0;x<32;x++)
		twiddletab[x] = (x&1)|((x&2)<<1)|((x&4)<<2)|((x&8)<<3)|((x&16)<<4);
	for(;x<1024;x++)
		twiddletab[x] = twiddletab[x&31] | (twiddletab[(x>>5)&31]<<10);
#endif
}

enum {B,G,R};

int decode_small_vq(char *out,void *in0,void *in1,int width,int height,int mode)
{
	unsigned char vqtab[3*4*16];
	unsigned char *in;

	int twiddletab[1024];
	int x,y,wbyte;
	const SHIFTTBL *s;

	unsigned short *in_w = in1;
	char *p = vqtab;

	s = &shifttbl[mode];
	for(x=0;x<16*4;x++) {
		int c = in_w[x];
		p[R] = (c >> s->rshift) & s->rmask;
		p[G] = (c >> s->gshift) & s->gmask;
		p[B] = (c << s->bshift) & s->bmask;
		p+=3;
	}

	init_twiddletab(twiddletab);

	in = (unsigned char*)in0;
	wbyte = (width*3+3)&~3;
	for(y=0;y<height;y+=4) {
		char *p = out+(height-y-1)*wbyte;
		for(x=0;x<width;x+=2) {
			int c = in[(twiddletab[y/2]>>1)|twiddletab[x/2]];
			unsigned char *vq;

			vq = &vqtab[(c&15)*12];

			p[0] = vq[0];
			p[1] = vq[1];
			p[2] = vq[2];

			p[3] = vq[6];
			p[4] = vq[7];
			p[5] = vq[8];

			p[0-wbyte] = vq[3];
			p[1-wbyte] = vq[4];
			p[2-wbyte] = vq[5];

			p[3-wbyte] = vq[9];
			p[4-wbyte] = vq[10];
			p[5-wbyte] = vq[11];

			vq = &vqtab[(c>>4)*12];
			p-=wbyte*2;

			p[0] = vq[0];
			p[1] = vq[1];
			p[2] = vq[2];

			p[3] = vq[6];
			p[4] = vq[7];
			p[5] = vq[8];

			p[0-wbyte] = vq[3];
			p[1-wbyte] = vq[4];
			p[2-wbyte] = vq[5];

			p[3-wbyte] = vq[9];
			p[4-wbyte] = vq[10];
			p[5-wbyte] = vq[11];

			p+=wbyte*2;
			p+=6;
		}
	}
}

int decode_twiddled_vq(char *out,void *in0,void *in1,int width,int height,int mode)
{
	unsigned char vqtab[3*4*256];
	unsigned char *in;

	int twiddletab[1024];
	int x,y,wbyte;
	const SHIFTTBL *s;

	unsigned short *in_w = in1;
	char *p = vqtab;

	s = &shifttbl[mode];
	for(x=0;x<256*4;x++) {
		int c = in_w[x];
		p[R] = (c >> s->rshift) & s->rmask;
		p[G] = (c >> s->gshift) & s->gmask;
		p[B] = (c << s->bshift) & s->bmask;
		p+=3;
	}

	init_twiddletab(twiddletab);

	in = (unsigned char*)in0;
	wbyte = (width*3+3)&~3;
	for(y=0;y<height;y+=2) {
		char *p = out+(height-y-1)*wbyte;
		for(x=0;x<width;x+=2) {
			int c = in[twiddletab[y/2]|(twiddletab[x/2]<<1)];
			unsigned char *vq = &vqtab[c*12];

			p[0] = vq[0];
			p[1] = vq[1];
			p[2] = vq[2];

			p[3] = vq[6];
			p[4] = vq[7];
			p[5] = vq[8];

			p[0-wbyte] = vq[3];
			p[1-wbyte] = vq[4];
			p[2-wbyte] = vq[5];

			p[3-wbyte] = vq[9];
			p[4-wbyte] = vq[10];
			p[5-wbyte] = vq[11];

			p+=6;
		}
	}
}

int decode_twiddled(char *out,void *in0,int width,int height,int mode)
{
	int twiddletab[1024];
	int x,y,wbyte;
	const SHIFTTBL *s;

	init_twiddletab(twiddletab);

	if (0) {char tmp[80];
	wsprintf(tmp,"%d x %d x %d %s",width,height,mode,str_table[mode]);
	MessageBox(NULL,tmp,"AAA",MB_OK);
	}

  switch(mode){
  case PAL4:
	wbyte = (width/2+3)&~3;
	for(y=0;y<height;y+=2) {
		char *p = out+(height-y-1)*wbyte;
		unsigned char *in=in0;
		for(x=0;x<width;x+=2) {
			int c0 = in[(twiddletab[y]>>1)|twiddletab[x  ]];
			int c1 = in[(twiddletab[y]>>1)|twiddletab[x+1]];
			p[x/2      ] = c0&0x0f | c1<<4;
			p[x/2-wbyte] = c0>>4   | c1&0xf0;
		}
	}
	break;
  case PAL8:
	wbyte = (width+3)&~3;
	for(y=0;y<height;y++) {
		char *p = out+(height-y-1)*wbyte;
		unsigned char *in=in0;
		for(x=0;x<width;x++) {
			p[x] = in[twiddletab[y]|(twiddletab[x]<<1)];
		}
	}
	break;
  default:
	s = &shifttbl[mode];
	wbyte = (width*3+3)&~3;
	for(y=0;y<height;y++) {
		unsigned char *p = out+(height-y-1)*wbyte;
		unsigned short *in=in0;
		for(x=0;x<width;x++) {
			int c = in[twiddletab[y]|(twiddletab[x]<<1)];
#if 1
			p[R] = p[G] = p[B] = (c >> 8);
#else
			p[R] = (c >> s->rshift) & s->rmask;
			p[G] = (c >> s->gshift) & s->gmask;
			p[B] = (c << s->bshift) & s->bmask;
#endif
			p+=3;
		}
	}
  }
}

int decode_rectangle(char *out,void *in0,int width,int height,int mode)
{
	int x,y,wbyte;
	const SHIFTTBL *s;
	if (mode<=2)
		s = &shifttbl[mode];

	wbyte = (width*3+3)&~3;
	for(y=0;y<height;y++) {
		char *p = out+(height-y-1)*wbyte;
		unsigned short *in = in0;
		for(x=0;x<width;x++) {
			int c = in[x];
			p[R] = (c >> s->rshift) & s->rmask;
			p[G] = (c >> s->gshift) & s->gmask;
			p[B] = (c << s->bshift) & s->bmask;
			p+=3;
		}
	}
}

int pvr2bmphdr(BITMAPINFOHEADER *pInfo,PVRHDR *hdr)
{
	int bits,img_size;

	switch(hdr->type[0]){
	case 0x00: /* ARGB155 */
	case 0x01: /* RGB565 */
	case 0x02: /* ARGB4444 */
	case 0x03: /* YUV422 */
		bits = 24; break;
	case 0x04: /* BUMP */
	case 0x05: /* 4BPP */
		bits = 4; break;
	case 0x06: /* 8BPP */
		bits = 8; break;
	default:
	}
	img_size = ((hdr->width*bits/8+3)&~3) * hdr->height;

    //*pHBInfoÇ…ÇÕBITMAPINFOÇì¸ÇÍÇÈ
	pInfo->biSize = sizeof(BITMAPINFOHEADER);
	pInfo->biWidth = hdr->width;
	pInfo->biHeight = hdr->height;
	pInfo->biPlanes = 1;
	pInfo->biBitCount = bits;
	pInfo->biCompression = BI_RGB;
	pInfo->biSizeImage = img_size;
	pInfo->biXPelsPerMeter = 0;
	pInfo->biYPelsPerMeter = 0;
	pInfo->biClrUsed = 0;
	pInfo->biClrImportant = 0;
}

int pvr2bmp(char *pBm,PVRHDR *hdr)
{
	char *data = (char*)(hdr+1);
	
    //*pHBmÇ…ÇÕÉrÉbÉgÉ}ÉbÉvÉfÅ[É^Çì¸ÇÍÇÈ
	switch(hdr->type[1]){
	case 0x01: /* twiddled */
		decode_twiddled(pBm,data,hdr->width,hdr->height,hdr->type[0]);
		break;
	case 0x02: /* twiddled & mipmap */
		decode_twiddled(pBm,data+calc_n(hdr->width)*2,hdr->width,hdr->height,hdr->type[0]);
		break;
	case 0x03: /* VQ */
		decode_twiddled_vq(pBm,data+2048,data,hdr->width,hdr->height,hdr->type[0]);
		break;
	case 0x04: /* VQ & MIPMAP */
		decode_twiddled_vq(pBm,data+2048+calc_n(hdr->width/2),data,hdr->width,hdr->height,hdr->type[0]);
		break;
	case 0x05: /* twiddled 4bit? */
		decode_twiddled(pBm,data,hdr->width,hdr->height,hdr->type[0]);
		break;
	case 0x06: /* twiddled & mipmap 4bit? */
		decode_twiddled(pBm,data+calc_n(hdr->width)/2,hdr->width,hdr->height,hdr->type[0]);
		break;
	case 0x07: /* twiddled 8bit? */
		decode_twiddled(pBm,data,hdr->width,hdr->height,hdr->type[0]);
		break;
	case 0x08: /* twiddled & mipmap 8bit? */
		decode_twiddled(pBm,data+calc_n(hdr->width),hdr->width,hdr->height,hdr->type[0]);
		break;
	case 0x09: /* RECTANGLE */
		decode_rectangle(pBm,data,hdr->width,hdr->height,hdr->type[0]);
		break;
	case 0x10: /* SMALL_VQ */
		decode_small_vq(pBm,data+128,data,hdr->width,hdr->height,hdr->type[0]);
		break;
	case 0x11: /* SMALL_VQ & MIPMAP */
		decode_small_vq(pBm,data+128+calc_n(hdr->width/2)/2,data,hdr->width,hdr->height,hdr->type[0]);
		break;
	default:
		break;
	}
}


#endif
