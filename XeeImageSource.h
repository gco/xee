#import <Cocoa/Cocoa.h>

#define XeeNavigationCapable 1
#define XeeRenamingCapable 2
#define XeeCopyingCapable 4
#define XeeMovingCapable 8
#define XeeDeletionCapable 16
#define XeeSortingCapable 32

#define XeeNameSortOrder 1
#define XeeDateSortOrder 2
#define XeeSizeSortOrder 3

@class XeeImage;

@interface XeeImageSource:NSObject
{
	id delegate;
	NSImage *icon;

	int sortorder;

	struct rand_entry { int next,prev; } *rand_ordering;
	int rand_size;
}

-(id)init;
-(void)dealloc;

-(void)stop;

-(id)delegate;
-(void)setDelegate:(id)newdelegate;

-(NSImage *)icon;
-(void)setIcon:(NSImage *)newicon;

-(int)numberOfImages;
-(int)indexOfCurrentImage;
-(NSString *)representedFilename;
-(NSString *)descriptiveNameOfCurrentImage;
-(int)capabilities;

-(int)sortOrder;
-(void)setSortOrder:(int)order;

-(void)pickImageAtIndex:(int)index next:(int)next;

-(void)pickImageAtIndex:(int)index;
-(void)skip:(int)offset;
-(void)pickFirstImage;
-(void)pickLastImage;
-(void)pickNextImageAtRandom;
-(void)pickPreviousImageAtRandom;
-(void)pickCurrentImage;

-(void)updateRandomList;
-(void)triggerImageChangeAction:(XeeImage *)image;
-(void)triggerImageListChangeAction;

@end



@interface NSObject (XeeImageSourceDelegate)

-(void)xeeImageSource:(XeeImageSource *)source imageListDidChange:(int)num;
-(void)xeeImageSource:(XeeImageSource *)source imageDidChange:(XeeImage *)newimage;

@end
