#import <Cocoa/Cocoa.h>

#define XeeDefaultSortOrder 0
#define XeeNameSortOrder 1
#define XeeDateSortOrder 2
#define XeeSizeSortOrder 3

extern NSString *XeeErrorDomain;

#define XeeFileExistsError 1
#define XeeRenameError 2
#define XeeDeleteError 3
#define XeeCopyError 4
#define XeeMoveError 5
#define XeeNotSupportedError 6

@class XeeImage;

@interface XeeImageSource:NSObject
{
	id delegate;
	NSImage *icon;

	int sortorder;

	BOOL actionsblocked;
	BOOL pendingimagechange,pendinglistchange;
	XeeImage *pendingimage;

	struct rand_entry { int next,prev; } *rand_ordering;
	int rand_size;
}

-(id)init;
-(void)dealloc;

-(void)start;
-(void)stop;

-(id)delegate;
-(void)setDelegate:(id)newdelegate;

-(NSImage *)icon;
-(void)setIcon:(NSImage *)newicon;

-(int)numberOfImages;
-(int)indexOfCurrentImage;
-(NSString *)windowTitle;
-(NSString *)windowRepresentedFilename;
-(NSString *)descriptiveNameOfCurrentImage;
-(NSString *)filenameOfCurrentImage;
-(uint64_t)sizeOfCurrentImage;
-(NSDate *)dateOfCurrentImage;
-(BOOL)isCurrentImageRemote;
-(BOOL)isCurrentImageAtPath:(NSString *)path;

-(BOOL)canBrowse;
-(BOOL)canSort;
-(BOOL)canRenameCurrentImage;
-(BOOL)canDeleteCurrentImage;
-(BOOL)canCopyCurrentImage;
-(BOOL)canMoveCurrentImage;
-(BOOL)canOpenCurrentImage;
-(BOOL)canSaveCurrentImage;

-(int)sortOrder;
-(void)setSortOrder:(int)order;

-(void)setActionsBlocked:(BOOL)blocked;

-(void)pickImageAtIndex:(int)index next:(int)next;

-(void)pickImageAtIndex:(int)index;
-(void)skip:(int)offset;
-(void)pickFirstImage;
-(void)pickLastImage;
-(void)pickNextImageAtRandom;
-(void)pickPreviousImageAtRandom;
-(void)pickCurrentImage;

-(NSError *)renameCurrentImageTo:(NSString *)newname;
-(NSError *)deleteCurrentImage;
-(NSError *)copyCurrentImageTo:(NSString *)destination;
-(NSError *)moveCurrentImageTo:(NSString *)destination;
-(NSError *)openCurrentImageInApp:(NSString *)app;

-(void)beginSavingImage:(XeeImage *)image;
-(void)endSavingImage:(XeeImage *)image;

-(void)updateRandomList;
-(void)triggerImageChangeAction:(XeeImage *)image;
-(void)triggerImageListChangeAction;
-(NSString *)demandPassword;

@end



@interface NSObject (XeeImageSourceDelegate)

-(void)xeeImageSource:(XeeImageSource *)source imageListDidChange:(int)num;
-(void)xeeImageSource:(XeeImageSource *)source imageDidChange:(XeeImage *)newimage;
-(NSString *)xeeImageSourceDemandsPassword:(XeeImageSource *)source;

@end
