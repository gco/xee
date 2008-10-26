#import <Foundation/Foundation.h>

#import "CSFilterHandle.h"

extern NSString *CCITTCodeException;

@interface CCITTFaxHandle:CSFilterHandle
{
	int cols,white;
	int col,colour,bitsleft;
}

-(id)initWithHandle:(CSHandle *)handle columns:(int)columns white:(int)whitevalue;

-(void)resetFilter;
-(uint8)produceByte;

-(void)startNewLine;
-(void)findNextSpanLength;

@end

@interface CCITTFaxT6Handle:CCITTFaxHandle
{
	int *prevchanges,numprevchanges;
	int *currchanges,numcurrchanges;
	int prevpos,previndex,currpos,currcol,nexthoriz;
}

-(id)initWithHandle:(CSHandle *)handle columns:(int)columns white:(int)whitevalue;
-(void)dealloc;

-(void)resetFilter;
-(void)startNewLine;
-(void)findNextSpanLength;

@end
