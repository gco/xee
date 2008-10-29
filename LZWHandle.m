#import "LZWHandle.h"

NSString *LZWInvalidCodeException=@"LZWInvalidCodeException";

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
