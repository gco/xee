#import <Foundation/Foundation.h>
#import <setjmp.h>
#import <objc/objc-class.h>

@interface CSCoroutine:NSProxy
{
	jmp_buf env;
	size_t stacksize;
	void *stack;
	id target;
	SEL selector;
	marg_list arguments;
	int argsize;
	BOOL fired;
	CSCoroutine *caller;
}
+(void)initialize;
+(CSCoroutine *)mainCoroutine;
+(CSCoroutine *)currentCoroutine;
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

