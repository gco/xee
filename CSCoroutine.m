#import "CSCoroutine.h"
#import <pthread.h>
#import <objc/objc-runtime.h>

@interface NSProxy (Hidden)
-(void)doesNotRecognizeSelector:(SEL)sel;
@end

@implementation CSCoroutine

static void CSCoroutineFreeMain(CSCoroutine *main) { [main release]; }
static pthread_key_t currkey,mainkey;

+(void)initialize
{
	pthread_key_create(&currkey,NULL);
	pthread_key_create(&mainkey,(void (*)())CSCoroutineFreeMain);
}

+(CSCoroutine *)mainCoroutine
{
	CSCoroutine *main=(CSCoroutine *)pthread_getspecific(mainkey);
	if(!main)
	{
		main=[[self alloc] initWithTarget:nil stackSize:0];
		pthread_setspecific(mainkey,main);
	}
	return main;
}

+(CSCoroutine *)currentCoroutine
{
	CSCoroutine *curr=(CSCoroutine *)pthread_getspecific(currkey);
	if(curr) return curr;
	else return [self mainCoroutine];
}

+(void)returnFromCurrent { [[self currentCoroutine] returnFrom]; }

-(id)initWithTarget:(id)targetobj stackSize:(size_t)stackbytes
{
	target=targetobj;
	stacksize=stackbytes;
	caller=nil;
	fired=target?NO:YES;

	if(stacksize) stack=calloc(1,stacksize+16);

	return self;
}

-(void)dealloc
{
	free(stack);
	[super dealloc];
}

static void CSCoroutineStart()
{
	CSCoroutine *coro=[CSCoroutine currentCoroutine];
	objc_msgSendv(coro->target,coro->selector,coro->argsize,coro->arguments);
	[coro returnFrom];
	[NSException raise:@"CSCoroutineException" format:@"Attempted to switch to a coroutine that has ended"];
}

-forward:(SEL)sel :(marg_list)args
{
	if(fired) [NSException raise:@"CSCoroutineException" format:@"Attempted to start a coroutine that is already running"];
	fired=YES;

	selector=sel;
	arguments=args;
	Method method=class_getInstanceMethod([target class],sel);
	if(!method) { [self doesNotRecognizeSelector:sel]; return nil; }
	argsize=method_getSizeOfArguments(method);
	caller=[CSCoroutine currentCoroutine];

	_setjmp(env);
	#if defined(__i386__)
	env[9]=(((int)stack+stacksize)&~15)-4; // Why -4? I have no idea.
	env[12]=(int)CSCoroutineStart;
	#else
	env[0]=((int)stack+stacksize-64)&~3;
	env[21]=(int)CSCoroutineStart;
	#endif

	[self switchTo];
	return nil;
}

-(void)switchTo
{
	CSCoroutine *curr=(CSCoroutine *)pthread_getspecific(currkey);
	if(!curr) curr=[CSCoroutine mainCoroutine];
	pthread_setspecific(currkey,self);
	if(_setjmp(curr->env)==0) _longjmp(env,1);
}

-(void)returnFrom { [caller switchTo]; }

@end



@implementation NSObject (CSCoroutine)

-(CSCoroutine *)newCoroutine
{
	return [[CSCoroutine alloc] initWithTarget:self stackSize:1024*1024];
}

-(CSCoroutine *)newCoroutineWithStackSize:(size_t)stacksize
{
	return [[CSCoroutine alloc] initWithTarget:self stackSize:stacksize];
}

@end
