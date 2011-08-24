#import "XeeMayaLoader.h"
#import "XeeIFFHandle.h"
#import "XeeTypes.h"

#define MAYA_RGB 1
#define MAYA_ALPHA 2
#define MAYA_RGBA 3
#define MAYA_ZBUFFER 4

@implementation XeeMayaImage

-(SEL)identifyFile
{
	iff=nil;
	subiff=nil;
	mainimage=nil;
	zbufimage=nil;

	uint8 *headbytes=(uint8 *)[header bytes];
	if([header length]<12||read_be_uint32(headbytes+8)!='CIMG'
	||(read_be_uint32(headbytes)!='FORM'&&read_be_uint32(headbytes)!='FOR4'&&read_be_uint32(headbytes)!='FOR8'))
	return NULL;

	iff=[[XeeIFFHandle IFFHandleWithPath:filename fileType:'CIMG'] retain];
	if(!iff) return NULL;

	for(;;)
	switch([iff nextChunk])
	{
		case 'TBHD':
			width=[iff readUint32];
			height=[iff readUint32];
			[iff skipBytes:4];
			flags=[iff readUint32];
			[iff skipBytes:2];
			tiles=[iff readUint16];
			compression=[iff readUint16];

			if(compression>1) return NULL;

NSLog(@"Maya: width:%d height:%d flags:%x tiles:%d compression:%d",width,height,flags,tiles,compression);

			[self setFormat:@"Maya IFF"];
			return @selector(startLoading);

		case 0:
			return NULL;
	}
}

-(void)deallocLoader
{
	[iff release];
	[subiff release];
	[super deallocLoader];
}

-(SEL)startLoading
{
	int type=0;

	switch(flags&MAYA_RGBA)
	{
		case MAYA_RGBA: type=XeeBitmapTypeARGB8; pixelsize=4; break;
		case MAYA_RGB: type=XeeBitmapTypeRGB8; pixelsize=3; break;
		case MAYA_ALPHA: type=XeeBitmapTypeLuma8; pixelsize=1; break;
	}

	if(type)
	{
		mainimage=[[[XeeBitmapImage alloc] initWithType:type width:width height:height] autorelease];
		if(!mainimage) return NULL;
		[self addSubImage:mainimage];
	}

	switch(flags&MAYA_RGBA)
	{
		case MAYA_RGBA: [mainimage setDepthRGBA:8]; break;
		case MAYA_RGB: [mainimage setDepthRGB:8]; break;
		case MAYA_ALPHA: [mainimage setDepthGrey:8]; break;
	}

	if(flags&MAYA_ZBUFFER)
	{
		zbufimage=[[[XeeBitmapImage alloc] initWithType:XeeBitmapTypeLuma8 width:width height:height] autorelease];
		if(!zbufimage) return NULL;
		[self addSubImage:zbufimage];
		//[zbufimage setDepthGrey:];
	}

	rgbatiles=0;
	zbuftiles=0;

	for(;;)
	switch([iff nextChunk])
	{
		case 'FORM':
		case 'FOR4':
		case 'FOR8':
			if([iff readID]=='TBMP')
			{
				subiff=[[iff IFFHandleForChunk] retain];
				return @selector(load);
			}
		break;

		case 0:
			return NULL;
	}

}

-(SEL)load
{
	int x1,y1,x2,y2;
	int tile_w,tile_h;

	switch([subiff nextChunk])
	{
		case 'RGBA':
			x1=[subiff readUint16];
			y1=[subiff readUint16];
			x2=[subiff readUint16];
			y2=[subiff readUint16];

			if(x2<width&&y2<height);
			{
				tile_w=x2-x1+1;
				tile_h=y2-y1+1;

				if([subiff chunkSize]==tile_w*tile_h*pixelsize+8) [self readUncompressedAtX:x1 y:y1 width:tile_w height:tile_h];
				else [self readRLECompressedAtX:x1 y:y1 width:tile_w height:tile_h];

				rgbatiles++;
			}
		break;

		case 'ZBUF':
			NSLog(@"ZBUF %d %d %d %d",[subiff readUint16],[subiff readUint16],[subiff readUint16],[subiff readUint16]);
			zbuftiles++;
		break;

		case 0:
			if(mainimage&&rgbatiles!=tiles) return NULL;
			if(zbufimage&&zbuftiles!=tiles) return NULL;

			[mainimage setCompletedRowCount:height];
			[zbufimage setCompletedRowCount:height];

			success=YES;
			return NULL;
	}

	return @selector(load);
}

-(void)readUncompressedAtX:(int)x y:(int)y width:(int)w height:(int)h
{
	uint8 *maindata=[mainimage data];
	int mainbpr=[mainimage bytesPerRow];

	for(int row=0;row<h;row++)
	[subiff readBytes:w*pixelsize toBuffer:maindata+(y+row)*mainbpr+x*pixelsize];
}


-(void)readRLECompressedAtX:(int)x y:(int)y width:(int)w height:(int)h
{
	int bpr=[mainimage bytesPerRow];
	uint8 *datastart=[mainimage data]+y*bpr+x*pixelsize;

	if(pixelsize==1)
	{
		[self readRLECompressedTo:datastart num:w*h stride:1 width:w bytesPerRow:bpr];
	}
	else if(pixelsize==3)
	{
		[self readRLECompressedTo:datastart num:w*h stride:3 width:w bytesPerRow:bpr];
		[self readRLECompressedTo:datastart+1 num:w*h stride:3 width:w bytesPerRow:bpr];
		[self readRLECompressedTo:datastart+2 num:w*h stride:3 width:w bytesPerRow:bpr];
	}
	else if(pixelsize==4)
	{
		[self readRLECompressedTo:datastart+1 num:w*h stride:3 width:w bytesPerRow:bpr];
		[self readRLECompressedTo:datastart+2 num:w*h stride:3 width:w bytesPerRow:bpr];
		[self readRLECompressedTo:datastart+3 num:w*h stride:3 width:w bytesPerRow:bpr];
		[self readRLECompressedTo:datastart num:w*h stride:3 width:w bytesPerRow:bpr];
	}
}

-(void)readRLECompressedTo:(uint8 *)dest num:(int)num stride:(int)stride width:(int)w bytesPerRow:(int)bpr
{
	int total=0,x=0;

	for(;;)
	{
		uint8 marker=[subiff readUint8];
		int count=(marker&0x7f)+1;

		if(marker&0x80)
		{
			uint8 val=[subiff readUint8];
			for(int i=0;i<count;i++)
			{
				*dest=val;
				dest+=stride;

				if(++x>=w) { dest+=bpr-w*stride; x=0; }
				if(++total>=num) return;
			}
		}
		else
		{
			for(int i=0;i<count;i++)
			{
				*dest=[subiff readUint8];
				dest+=stride;

				if(++x>=w) { dest+=bpr-w*stride; x=0; }
				if(++total>=num) return;
			}
		}
	}
}

/*
uByte * iff_decompress_rle( FILE * file, uInt32 numBytes, 
			    uByte * compressedData,
			    uInt32 compressedDataSize, 
			    uInt32 * compressedIndex ) 
{

  uByte * data = (uByte *)malloc( numBytes * sizeof( uByte ) );
  uByte nextChar, count;
  int i;
  uInt32 byteCount = 0; 
    
  for ( i = 0; i < (int)numBytes; ++i ) {
    data[i] = 0;
  }  

#ifdef __IFF_DEBUG_
  printf( "Decompressing data %d\n", numBytes );
#endif
	
  while ( byteCount < numBytes ) {

    if( *compressedIndex >= compressedDataSize ) {
      break;
    }
   
    nextChar = compressedData[ *compressedIndex ];
    (*compressedIndex)++;
        
    count = (nextChar & 0x7f) + 1;
    if ( ( byteCount + count ) > numBytes ) break;
        
    if ( nextChar & 0x80 ) {

      // We have a duplication run
			
      nextChar = compressedData[ *compressedIndex ];
      (*compressedIndex)++;
            
      //assert( ( byteCount + count ) <= numBytes ); 
      for ( i = 0; i < count; ++i ) {
	data[byteCount] = nextChar;
	byteCount++;
      }
    } 
    else {
      // We have a verbatim run 
      for ( i = 0; i < count; ++i ) {

	data[byteCount] = compressedData[ *compressedIndex ];
	(*compressedIndex)++;
	byteCount++;
      }
    }
    assert( byteCount <= numBytes ); 
  }

  return( data );    
}*/


+(NSArray *)fileTypes
{
	return [NSArray arrayWithObjects:@"iff",@"'MIFF'",nil];
}

@end
