#import <Foundation/Foundation.h>
#import <setjmp.h>
#import <objc/objc-class.h>

@interface CSCoroutine:NSProxy
{
	id target;
	size_t stacksize;
	void *stack;
	BOOL fired;

	CSCoroutine *caller;
	jmp_buf env;

	SEL selector;
	marg_list arguments;
	int argsize;

	NSInvocation *inv;
}
+(CSCoroutine *)mainCoroutine;
+(CSCoroutine *)currentCoroutine;
+(void)setCurrentCoroutine:(CSCoroutine *)curr;
+(void)returnFromCurrent;

-(id)initWithTarget:(id)targetobj stackSize:(size_t)stackbytes;
-(void)dealloc;

-(void)switchTo;
-(void)returnFrom;
@end

@interface NSObject (CSCoroutine)
-(CSCoroutine *)newCoroutine;
-(CSCoroutine *)newCoroutineWithStackSize:(size_t)stacksize;
@end

