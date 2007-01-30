#import <Cocoa/Cocoa.h>



typedef struct XeeSamplePoint { float u,v,weight; } XeeSamplePoint;
typedef float (*XeeFilterFunction)(float,float);



@interface XeeSampleSet:NSObject
{
	XeeSamplePoint *samples;
	int num;
}

-(id)initWithCount:(int)count;
-(void)dealloc;

-(void)filterWithFunction:(XeeFilterFunction)filter;
-(void)sortByWeight;

-(int)count;
-(XeeSamplePoint *)samples;

+(XeeSampleSet *)sampleSetWithCount:(int)count distribution:(NSString *)distname filter:(NSString *)filtername;

@end
