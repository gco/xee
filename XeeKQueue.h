#import <Cocoa/Cocoa.h>
#import <sys/event.h>

#import "XeeFSRef.h"

@interface XeeKQueue:NSObject
{
	int queue;
	NSMutableDictionary *observers;
}

-(id)init;
-(void)dealloc;

-(void)addObserver:(id)observer selector:(SEL)selector ref:(XeeFSRef *)ref;
-(void)addObserver:(id)observer selector:(SEL)selector ref:(XeeFSRef *)ref flags:(int)flags;
-(void)removeObserver:(id)observer ref:(XeeFSRef *)ref;

-(void)eventLoop;

+(XeeKQueue *)defaultKQueue;

@end



@interface XeeKEvent:NSObject
{
	int fd;
	XeeFSRef *ref;
	id target;
	SEL sel;
	struct kevent ev;
}

-(id)initWithFileDescriptor:(int)filedesc observer:(id)observer selector:(SEL)selector ref:(XeeFSRef *)ref;
-(void)dealloc;

-(int)fileDescriptor;
-(XeeFSRef *)ref;
-(int)flags;
-(void)triggerForEvent:(struct kevent *)event;

@end



@interface XeeKEventKey:NSObject
{
	XeeFSRef *ref;
	id target;
}

+(XeeKEventKey *)keyWithRef:(XeeFSRef *)fsref target:(id)observer;

-(id)initWithRef:(XeeFSRef *)fsref target:(id)observer;
-(XeeFSRef *)ref;
-(id)target;
-(BOOL)isEqual:(XeeKEventKey *)other;
-(unsigned)hash;
-(id)copyWithZone:(NSZone *)zone;

@end
