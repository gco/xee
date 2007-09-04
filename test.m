#import "CSCoroutine.h"

@interface TestObject:NSObject
{
}
-(void)test:(int)val;
-(void)test2:(int)val;
@end

@implementation TestObject

-(void)test:(int)val
{
	CSCoroutine *coro=[self newCoroutine];
	[(id)coro test2:val];

	for(int i=0;i<=10;i++)
	{
		printf("a: %d\n",val+i);
		[coro switchTo];
	} 

	[coro release];
}

-(void)test2:(int)val
{
	[CSCoroutine returnFromCurrent];
	for(int i=0;i<=10;i++)
	{
		printf("b: %d\n",val-i);
		[CSCoroutine returnFromCurrent];
	}
}

@end

int main(int argc,char **argv)
{
	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	TestObject *test=[TestObject new];
	[test test:15];
	[test release];

	[pool release];
}
