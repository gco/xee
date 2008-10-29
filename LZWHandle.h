#import "CSFilterHandle.h"

extern NSString *LZWInvalidCodeException;

@interface LZWHandle:CSFilterHandle
{
	BOOL early;

	int table[4096];
	int numsymbols,symbolsize;

	uint8_t *strings;
	int stringsize;

	int prevsymbol;
	int outputoffs,outputend;
}

-(id)initWithHandle:(CSHandle *)handle earlyChange:(BOOL)earlychange;

-(void)resetFilter;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
