#import "CSCoroutine.h"

@interface TestObject:NSObject
{
	NSConditionLock *lock;
}
-(void)test;
-(void)test1:(int)val;
-(void)test1b:(int)val;
-(void)test2;
-(void)test2b:(CSCoroutine *)coro;
-(void)test2c;
@end

@implementation TestObject

-(void)test
{
	[self test1:10];
	[self test2];
}

-(void)test1:(int)val
{
	printf("Test 1: interleaved loops\n");

	CSCoroutine *coro=[self newCoroutine];
	[(id)coro test1b:val];

	for(int i=0;i<=5;i++)
	{
		printf("a: %d\n",val+i);
		[coro switchTo];
	} 

	[coro release];
}

-(void)test1b:(int)val
{
	[CSCoroutine returnFromCurrent];
	for(int i=0;i<=5;i++)
	{
		printf("b: %d\n",val-i);
		[CSCoroutine returnFromCurrent];
	}
}

-(void)test2
{
	printf("Test 2: jumping threads\n");

	CSCoroutine *coro=[self newCoroutine];
	[(id)coro test2c];

	lock=[[NSConditionLock alloc] initWithCondition:0];
	[NSThread detachNewThreadSelector:@selector(test2b:) toTarget:self withObject:coro];
	[lock lockWhenCondition:1]; // wait for thread to finish
	[lock unlock];
	[lock release];
}

-(void)test2b:(CSCoroutine *)coro
{
	printf("Separate thread started\n");
	[coro switchTo];
	[coro release];
	[lock lockWhenCondition:0];
	[lock unlockWithCondition:1];
}

-(void)test2c
{
	printf("First invocation in main thread.\n");
	[CSCoroutine returnFromCurrent];
	printf("Second invocation in separate thread.\n");
}

@end

int main(int argc,char **argv)
{
	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	TestObject *test=[TestObject new];
	[test test];
	[test release];

	[pool release];
}
