#import "LZWHandle.h"

NSString *LZWInvalidCodeException=@"LZWInvalidCodeException";


@implementation LZWHandle

static uint8_t FindFirstByte(LZWTreeNode *nodes,int symbol)
{
	while(nodes[symbol].parent>=0) symbol=nodes[symbol].parent;
	return nodes[symbol].chr;
}

static int FillBuffer(uint8_t *buffer,LZWTreeNode *nodes,int symbol)
{
	if(symbol<0) return 0;

	int num=FillBuffer(buffer,nodes,nodes[symbol].parent);
	buffer[num]=nodes[symbol].chr;
	return num+1;
}

-(id)initWithHandle:(CSHandle *)handle earlyChange:(BOOL)earlychange
{
	if(self=[super initWithHandle:handle])
	{
		early=earlychange;

		nodes=malloc(sizeof(LZWTreeNode)*4096);

		for(int i=0;i<256;i++)
		{
			nodes[i].chr=i;
			nodes[i].parent=-1;
		}
	}
	return self;
}

-(void)dealloc
{
	free(nodes);
	[super dealloc];
}

-(void)clearTable
{
	symbolsize=9;
	numsymbols=258;
	prevsymbol=-1;
	currbyte=numbytes=0;
}

-(void)resetByteStream
{
	[self clearTable];
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(currbyte>=numbytes)
	{
		int symbol;
		for(;;)
		{
			symbol=CSInputNextBitString(input,symbolsize);
			if(symbol==256) [self clearTable];
			else break;
		}

		if(symbol==257) CSByteStreamEOF(self);

		if(prevsymbol<0)
		{
			prevsymbol=symbol;
			return symbol;
		}
		else
		{
			if(numsymbols==4096) [NSException raise:LZWInvalidCodeException format:@"Too many codes in LZW stream"];

			int outputsymbol,prefixsymbol,postfixbyte;
			if(symbol<numsymbols) // does <code> exist in the string table?
			{
				outputsymbol=symbol; // output the string for <code> to the charstream;

				prefixsymbol=prevsymbol; // [...] <- translation for <old>;
				postfixbyte=FindFirstByte(nodes,symbol); // K <- first character of translation for <code>;
				// add [...]K to the string table;
			}
			else if(symbol==numsymbols)
			{
				prefixsymbol=prevsymbol; // [...] <- translation for <old>;
				postfixbyte=FindFirstByte(nodes,prevsymbol); // K <- first character of [...];

				outputsymbol=numsymbols; // output [...]K to charstream and add it to string table;
			}
			else
			{
				[NSException raise:LZWInvalidCodeException format:@"Undefined code in LZW bit stream (%d with dictionary size %d)",symbol,numsymbols];
			}

			nodes[numsymbols].parent=prefixsymbol;
			nodes[numsymbols].chr=postfixbyte;
			numsymbols++;

			int offs=early?1:0;
			if(numsymbols==512-offs) symbolsize=10;
			else if(numsymbols==1024-offs) symbolsize=11;
			else if(numsymbols==2048-offs) symbolsize=12;

			prevsymbol=symbol;

			numbytes=FillBuffer(buffer,nodes,outputsymbol);
			currbyte=1;

			return buffer[0];
		}
	}
	else
	{
		return buffer[currbyte++];
	}
}

@end



/*
@implementation LZWHandle

-(id)initWithHandle:(CSHandle *)handle earlyChange:(BOOL)earlychange
{
	if(self=[super initWithHandle:handle])
	{
		early=earlychange;

		stringsize=4096;
		strings=malloc(stringsize);

		for(int i=0;i<256;i++) strings[i]=i;
		for(int i=0;i<256;i++) table[i]=i;
		table[256]=table[257]=table[258]=256;
	}
	return self;
}

-(void)dealloc
{
	free(strings);
	[super dealloc];
}

-(void)clearTable
{
	symbolsize=9;
	numsymbols=258;
	prevsymbol=-1;
	outputoffs=outputend=0;
}

-(void)resetFilter
{
	[self clearTable];
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(outputoffs>=outputend)
	{
		int symbol;
		for(;;)
		{
			symbol=CSFilterNextBitString(self,symbolsize);
			if(symbol==256) [self clearTable];
			else break;
		}

		if(symbol==257) CSFilterEOF();

		if(prevsymbol<0)
		{
			prevsymbol=symbol;
			return symbol;
		}
		else
		{
			int outputsymbol,prefixsymbol,postfixbyte;
			if(symbol<numsymbols) // does <code> exist in the string table?
			{
				outputsymbol=symbol; // output the string for <code> to the charstream;

				prefixsymbol=prevsymbol; // [...] <- translation for <old>;
				postfixbyte=strings[table[symbol]]; // K <- first character of translation for <code>;
				// add [...]K to the string table;
			}
			else if(symbol==numsymbols)
			{
				prefixsymbol=prevsymbol; // [...] <- translation for <old>;
				postfixbyte=strings[table[prevsymbol]]; // K <- first character of [...];

				outputsymbol=numsymbols; // output [...]K to charstream and add it to string table;
			}
			else
			{
				[NSException raise:LZWInvalidCodeException format:@"Undefined code in LZW bit stream (%d with dictionary size %d)",symbol,numsymbols];
			}

			int len=table[prefixsymbol+1]-table[prefixsymbol];
			int end=table[numsymbols]+len+1;

			if(end>stringsize)
			{
				stringsize*=2;
				strings=realloc(strings,stringsize);
			}

			memcpy(strings+table[numsymbols],strings+table[prefixsymbol],len);
			strings[end-1]=postfixbyte;
			table[numsymbols+1]=end;
			numsymbols++;

			int offs=early?1:0;
			if(numsymbols==512-offs) symbolsize=10;
			else if(numsymbols==1024-offs) symbolsize=11;
			else if(numsymbols==2048-offs) symbolsize=12;
			else if(numsymbols==4096) [NSException raise:LZWInvalidCodeException format:@"Too many codes in LZW stream"];

			prevsymbol=symbol;
			outputoffs=table[outputsymbol]+1;
			outputend=table[outputsymbol+1];

			return strings[table[outputsymbol]];
		}
	}
	else
	{
		return strings[outputoffs++];
	}
}

@end
*/
