#import "XeeControllerImageActions.h"
#import "XeeSavePanel.h"
#import "XeeImageSaver.h"
#import "XeeView.h"
#import "XeeMoveTool.h"
#import "XeeCropTool.h"
#import "XeeImageSource.h"



float XeeZoomLevels[]={0.03125,0.044,0.0625,0.09,0.125,0.18,0.25,0.35,0.5,0.70,1,1.5,2,3,4,6,8,11,16,23,32};
int XeeNumberOfZoomLevels=21;



@implementation XeeController (ImageActions)

-(IBAction)copy:(id)sender
{
	if(currimage)
	{
		CGImageRef cgimage=[currimage createCGImage];

		if(cgimage)
		{
			[[NSPasteboard generalPasteboard] declareTypes:[NSArray arrayWithObjects:NSTIFFPboardType,NSPICTPboardType,nil] owner:self];

			copiedcgimage=cgimage;
			[self retain];
		}
		else NSBeep();
	}
	else NSBeep();
}
#import <QuickTime/ImageCompression.h>
#import <QuickTime/QuickTimeComponents.h>

-(void)pasteboard:(NSPasteboard *)pboard provideDataForType:(NSString *)type
{
	if(!copiedcgimage) return;

	if([type isEqual:NSTIFFPboardType])
	{
		NSMutableData *data=[NSMutableData data];
		CGImageDestinationRef dest=CGImageDestinationCreateWithData((CFMutableDataRef)data,kUTTypeTIFF,1,NULL);
		if(!dest) { NSBeep(); return; }

		CGImageDestinationAddImage(dest,copiedcgimage,NULL);
		if(!CGImageDestinationFinalize(dest)) NSBeep();
		CFRelease(dest);

		[pboard setData:data forType:type];
	}
	else if([type isEqual:NSPICTPboardType])
	{
		BOOL res=NO;

		Handle outhandle=NewHandle(0);
		if(outhandle)
		{
			GraphicsExportComponent exporter;
			if(OpenADefaultComponent(GraphicsExporterComponentType,kQTFileTypePicture,&exporter)==noErr)
			{
				GraphicsExportSetInputCGImage(exporter,copiedcgimage);
				GraphicsExportSetOutputHandle(exporter,outhandle);
				//GraphicsExportSetOutputDataReference(exporter,dataRef, dataRefType);

				unsigned long size;
				if(GraphicsExportDoExport(exporter,&size)==noErr)
				{
					NSData *data=[NSData dataWithBytes:*outhandle+512 length:size-512];
NSLog(@"%@",[data subdataWithRange:NSMakeRange(0,2*1024)]);
					[pboard setData:data forType:type];
					res=YES;
				}

				CloseComponent(exporter);
			}
			DisposeHandle(outhandle);
		}
		if(!res) NSBeep();
	}
}

-(void)pasteboardChangedOwner:(NSPasteboard *)pboard
{
	CGImageRelease(copiedcgimage);
	copiedcgimage=NULL;

	[self release];
}



-(IBAction)save:(id)sender
{
	if(![self validateAction:_cmd]) { NSBeep(); return; }

	[source beginSavingImage:currimage];

	[self detachBackgroundTaskWithMessage:NSLocalizedString(@"Saving...",@"Message when saving an image")
	selector:@selector(saveTask:) target:self object:[currimage retain]];
}

-(void)saveTask:(XeeImage *)saveimage
{
	NSString *filename=[saveimage filename];
	if(![saveimage losslessSaveTo:filename flags:XeeRetainUntransformableBlocksFlag])
	{
		NSAlert *alert=[[[NSAlert alloc] init] autorelease];
		[alert setMessageText:NSLocalizedString(@"Image saving failed",@"Title of the file saving failure dialog")];
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Couldn't save the file \"%@\".",
		@"Content of the file saving failure dialog"),[filename lastPathComponent]]];
		[alert addButtonWithTitle:NSLocalizedString(@"OK",@"OK button")];
		[alert performSelectorOnMainThread:@selector(runModal) withObject:nil waitUntilDone:NO];

		[source performSelectorOnMainThread:@selector(endSavingImage:) withObject:saveimage waitUntilDone:YES];
		[saveimage release];
	}
	else
	{
		[self performSelectorOnMainThread:@selector(finishSave:) withObject:saveimage waitUntilDone:YES];
	}
}

-(void)finishSave:(XeeImage *)saveimage
{
	if(currimage==saveimage) [undo removeAllActions];

	[source endSavingImage:saveimage];
	[saveimage release];
}

-(IBAction)saveAs:(id)sender
{
	if(![self validateAction:_cmd]) { NSBeep(); return; }

	[XeeSavePanel runSavePanelForImage:currimage controller:self];
}



-(IBAction)frameSkipNext:(id)sender
{
	[self setResizeBlockFromSender:sender];
	if(currimage)
	{
		int frame=[currimage frame];
		int frames=[currimage frames];
		[self setFrame:(frame+1)%frames];
	}
	[self setResizeBlock:NO];
}

-(IBAction)frameSkipPrev:(id)sender
{
	[self setResizeBlockFromSender:sender];
	if(currimage)
	{
		int frame=[currimage frame];
		int frames=[currimage frames];
		[self setFrame:(frame+frames-1)%frames];
	}
	[self setResizeBlock:NO];
}

-(IBAction)toggleAnimation:(id)sender
{
	if(!currimage||![currimage animated]) return;

	[currimage setAnimating:![currimage animating]];
}



-(IBAction)zoomIn:(id)sender
{
	[self setResizeBlockFromSender:sender];

	int i;
	for(i=0;i<XeeNumberOfZoomLevels-1;i++) if(XeeZoomLevels[i]>zoom) break;

	[self setZoom:XeeZoomLevels[i]];

	[self setResizeBlock:NO];
}

-(IBAction)zoomOut:(id)sender
{
	[self setResizeBlockFromSender:sender];

	int i;
	for(i=XeeNumberOfZoomLevels-1;i>0;i--) if(XeeZoomLevels[i]<zoom) break;

	[self setZoom:XeeZoomLevels[i]];

	[self setResizeBlock:NO];
}

-(IBAction)zoomActual:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[self setZoom:1];
	[self setResizeBlock:NO];
}

-(IBAction)zoomFit:(id)sender
{
	[self setResizeBlockFromSender:sender];

	NSSize maxsize=[self maxViewSize];

	float horiz_zoom=maxsize.width/(float)[currimage width];
	float vert_zoom=maxsize.height/(float)[currimage height];

	[self setZoom:horiz_zoom<vert_zoom?horiz_zoom:vert_zoom];

	[self setResizeBlock:NO];
}

-(IBAction)setAutoZoom:(id)sender
{
	[self setResizeBlockFromSender:sender];
	[self setStandardImageSize];
	[self updateStatusBar];
	[self setResizeBlock:NO];
}



-(void)setOrientation:(int)orientation
{
	[[undo prepareWithInvocationTarget:self] setOrientation:[currimage orientation]];
	[currimage setOrientation:orientation];
}

-(IBAction)rotateCW:(id)sender
{
	if(!currimage) return;
	[self setResizeBlockFromSender:sender];
	[self setOrientation:XeeCombineTransformations([currimage orientation],XeeRotateCWTransformation)];
	[undo setActionName:NSLocalizedString(@"Rotate Clockwise",@"Name of rotate clockwise action in undo list")];
	[self setResizeBlock:NO];
}

-(IBAction)rotateCCW:(id)sender
{
	if(!currimage) return;
	[self setResizeBlockFromSender:sender];
	[self setOrientation:XeeCombineTransformations([currimage orientation],XeeRotateCCWTransformation)];
	[undo setActionName:NSLocalizedString(@"Rotate Counter-clockwise",@"Name of rotate counter-clockwise action in undo list")];
	[self setResizeBlock:NO];
}

-(IBAction)rotate180:(id)sender
{
	if(!currimage) return;
	[self setResizeBlockFromSender:sender];
	[self setOrientation:XeeCombineTransformations([currimage orientation],XeeRotate180Transformation)];
	[undo setActionName:NSLocalizedString(@"Rotate 180",@"Name of rotate 180 action in undo list")];
	[self setResizeBlock:NO];
}

-(IBAction)autoRotate:(id)sender
{
	if(!currimage) return;
	XeeTransformation orientation=[currimage correctOrientation];
	if(orientation==XeeUnknownTransformation) return;

	[self setResizeBlockFromSender:sender];
	[self setOrientation:orientation];
	[undo setActionName:NSLocalizedString(@"Automatic Orientation",@"Name of automatic orientation action in undo list")];
	[self setResizeBlock:NO];
}

-(IBAction)rotateActual:(id)sender
{
	if(!currimage) return;
	[self setResizeBlockFromSender:sender];
	[self setOrientation:XeeNoTransformation];
	[undo setActionName:NSLocalizedString(@"Actual Orientation",@"Name of actual orientation action in undo list")];
	[self setResizeBlock:NO];
}

-(IBAction)mirrorHorizontal:(id)sender
{
	if(!currimage) return;
	[self setResizeBlockFromSender:sender];
	[self setOrientation:XeeCombineTransformations([currimage orientation],XeeMirrorHorizontalTransformation)];
	[undo setActionName:NSLocalizedString(@"Mirror Horizontal",@"Name of mirror horizontal action in undo list")];
	[self setResizeBlock:NO];
}

-(IBAction)mirrorVertical:(id)sender
{
	if(!currimage) return;
	[self setResizeBlockFromSender:sender];
	[self setOrientation:XeeCombineTransformations([currimage orientation],XeeMirrorVerticalTransformation)];
	[undo setActionName:NSLocalizedString(@"Mirror Vertical",@"Name of mirror vertical action in undo list")];
	[self setResizeBlock:NO];
}



-(void)setCroppingRect:(NSRect)rect
{
	[[undo prepareWithInvocationTarget:self] setCroppingRect:[currimage croppingRect]];
	[currimage setCroppingRect:rect];
}

-(BOOL)isCropping
{
	return [imageview tool]==croptool;
}

-(IBAction)crop:(id)sender
{
	if(!currimage) return;

	[self setResizeBlockFromSender:sender];

	if([self isCropping])
	{
		NSRect currcrop=[currimage croppingRect];
		NSRect newcrop=[croptool croppingRect];
		newcrop.origin.x+=currcrop.origin.x;
		newcrop.origin.y+=currcrop.origin.y;
		[self setCroppingRect:newcrop];
		[undo setActionName:NSLocalizedString(@"Crop",@"Name of crop action in undo list")];

		[imageview setTool:movetool];
		croptool=nil;
	}
	else
	{
		croptool=(XeeCropTool *)[XeeCropTool toolForView:imageview];
		[imageview setTool:croptool];
	}

	[[window toolbar] validateVisibleItems];

	[self setResizeBlock:NO];
}


@end
