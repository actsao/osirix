/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - LGPL
  
  See http://www.osirix-viewer.com/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/

#import "AppController.h"
#import "WaitRendering.h"
#import "BurnerWindowController.h"
#import <OsiriX/DCM.h>
#import "MutableArrayCategory.h"
#import <DiscRecordingUI/DRSetupPanel.h>
#import <DiscRecordingUI/DRBurnSetupPanel.h>
#import <DiscRecordingUI/DRBurnProgressPanel.h>
#import "BrowserController.h"
#import "DicomStudy.h"
#import "DicomImage.h"
#import "DicomStudy+Report.h"
#import "Anonymization.h"
#import "AnonymizationPanelController.h"
#import "AnonymizationViewController.h"
#import "ThreadsManager.h"
#import "NSThread+N2.h"
#import "NSFileManager+N2.h"
#import "N2Debug.h"
#import "NSImage+N2.h"
#import "DicomDir.h"
#import "DicomDatabase.h"
#import <DiskArbitration/DiskArbitration.h>

@implementation BurnerWindowController

@synthesize password, buttonsDisabled, selectedUSB;

- (void) createDMG:(NSString*) imagePath withSource:(NSString*) directoryPath
{
	[[NSFileManager defaultManager] removeFileAtPath:imagePath handler:nil];
	
	NSTask* makeImageTask = [[[NSTask alloc] init] autorelease];

	[makeImageTask setLaunchPath: @"/bin/sh"];
	
	imagePath = [imagePath stringByReplacingOccurrencesOfString: @"\"" withString: @"\\\""];
	directoryPath = [directoryPath stringByReplacingOccurrencesOfString: @"\"" withString: @"\\\""];
	
	NSString* cmdString = [NSString stringWithFormat: @"hdiutil create \"%@\" -srcfolder \"%@\"",
													  imagePath,
													  directoryPath];

	NSArray *args = [NSArray arrayWithObjects: @"-c", cmdString, nil];

	[makeImageTask setArguments:args];
	[makeImageTask launch];
	[makeImageTask waitUntilExit];
}


-(id) initWithFiles:(NSArray *)theFiles
{
    if( self = [super initWithWindowNibName:@"BurnViewer"])
    {
		[[NSFileManager defaultManager] removeFileAtPath:[self folderToBurn] handler:nil];
		
		files = [theFiles mutableCopy];
		burning = NO;
		
		[[self window] center];
		
		NSLog( @"Burner allocated");
	}
	return self;
}

- (id)initWithFiles:(NSArray *)theFiles managedObjects:(NSArray *)managedObjects
{
	if( self = [super initWithWindowNibName:@"BurnViewer"])
	{
		[[NSFileManager defaultManager] removeFileAtPath:[self folderToBurn] handler:nil];
		
        idatabase = [[[DicomDatabase databaseForContext:[[managedObjects objectAtIndex:0] managedObjectContext]] independentDatabase] retain];
        
		files = [theFiles mutableCopy]; // file paths
		dbObjects = [[idatabase objectsWithIDs:managedObjects] mutableCopy]; // managedObjects in idatabase
		originalDbObjects = [dbObjects mutableCopy];
		
		[files removeDuplicatedStringsInSyncWithThisArray: dbObjects];
		
		id managedObject;
		id patient = nil;
		_multiplePatients = NO;
		
		[idatabase lock];
		
		for (managedObject in dbObjects)
		{
			NSString *newPatient = [managedObject valueForKeyPath:@"series.study.patientUID"];
			
			if( patient == nil)
				patient = newPatient;
			else if( [patient compare: newPatient options: NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch | NSWidthInsensitiveSearch] != NSOrderedSame)
			{
				_multiplePatients = YES;
				break;
			}
			patient = newPatient;
		}
		
		[idatabase unlock];
		
		burning = NO;
		
		[[self window] center];
		
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(_observeVolumeNotification:) name:NSWorkspaceDidMountNotification object:nil];
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(_observeVolumeNotification:) name:NSWorkspaceDidUnmountNotification object:nil];
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(_observeVolumeNotification:) name:NSWorkspaceDidRenameVolumeNotification object:nil];
        
		NSLog( @"Burner allocated");
	}
	return self;
}

-(void)_observeVolumeNotification:(NSNotification*)notification
{
    [self willChangeValueForKey: @"volumes"];
    [self didChangeValueForKey:@"volumes"];
}

- (void)windowDidLoad
{
	NSLog(@"BurnViewer did load");
	
	[[self window] setDelegate:self];
	[self setup:nil];
	
	[compressionMode selectCellWithTag: [[NSUserDefaults standardUserDefaults] integerForKey: @"Compression Mode for Burning"]];
}

- (void)dealloc
{
	windowWillClose = YES;
	
	runBurnAnimation = NO;
	
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self name:NSWorkspaceDidMountNotification object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self name:NSWorkspaceDidUnmountNotification object:nil];
    
	[anonymizedFiles release];
	[filesToBurn release];
	[dbObjects release];
	[originalDbObjects release];
	[cdName release];
	[password release];
    [writeDMGPath release];
    [writeVolumePath release];
    [idatabase release];
	[anonymizationTags release];
    
	NSLog(@"Burner dealloc");	
	[super dealloc];
}


//------------------------------------------------------------------------------------------------------------------------------------
#pragma mark•

- (NSArray *)filesToBurn
{
	return filesToBurn;
}

- (void)setFilesToBurn:(NSArray *)theFiles
{
	[filesToBurn release];
	filesToBurn = [theFiles retain];
}

- (NSArray *)extractFileNames:(NSArray *)filenames
{
    NSString *pname;
    NSString *fname;
    NSString *pathName;
    BOOL isDir;

    NSMutableArray *fileNames = [[[NSMutableArray alloc] init] autorelease];
	//NSLog(@"Extract");
    for (fname in filenames)
	{ 
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		//NSLog(@"fname %@", fname);
        NSFileManager *manager = [NSFileManager defaultManager];
        if( [manager fileExistsAtPath:fname isDirectory:&isDir] && isDir)
		{
            NSDirectoryEnumerator *direnum = [manager enumeratorAtPath:fname];
            //Loop Through directories
            while (pname = [direnum nextObject])
			{
                pathName = [fname stringByAppendingPathComponent:pname]; //make pathanme
                if( [manager fileExistsAtPath:pathName isDirectory:&isDir] && !isDir)
				{ //check for directory
					if( [DCMObject objectWithContentsOfFile:pathName decodingPixelData:NO])
					{
                        [fileNames addObject:pathName];
					}
                }
            } //while pname
                
        } //if
        //else if( [dicomDecoder dicomCheckForFile:fname] > 0) {
		else if( [DCMObject objectWithContentsOfFile:fname decodingPixelData:NO]) {	//Pathname
				[fileNames addObject:fname];
        }
		[pool release];
    } //while
    return fileNames;
}

//Actions
-(IBAction) burn: (id)sender
{
	if( !(isExtracting || isSettingUpBurn || burning))
	{
        cancelled = NO;
        
        [sizeField setStringValue: @""];
        
        [cdName release];
        cdName = [[nameField stringValue] retain];
        
        if( [cdName length] <= 0)
        {
            [cdName release];
            cdName = [@"UNTITLED" retain];
        }
        
        [[NSFileManager defaultManager] removeFileAtPath:[self folderToBurn] handler:nil];
        [[NSFileManager defaultManager] removeFileAtPath:[NSString stringWithFormat:@"/tmp/burnAnonymized"] handler:nil];
        
        [writeVolumePath release];
        writeVolumePath = nil;
        
        [writeDMGPath release];
        writeDMGPath = nil;
        
        [anonymizationTags release];
        anonymizationTags = nil;
        
        if( [[NSUserDefaults standardUserDefaults] boolForKey:@"anonymizedBeforeBurning"])
        {
            AnonymizationPanelController* panelController = [Anonymization showPanelForDefaultsKey:@"AnonymizationFields" modalForWindow:self.window modalDelegate:NULL didEndSelector:NULL representedObject:NULL];
            
            if( panelController.end == AnonymizationPanelCancel)
                return;
            
            anonymizationTags = [panelController.anonymizationViewController.tagsValues retain];
        }
        else
        {
            [anonymizedFiles release];
            anonymizedFiles = nil;
        }
        
        self.buttonsDisabled = YES;
        
        @try
        {
            if( cdName != nil && [cdName length] > 0)
            {
                runBurnAnimation = YES;
                
                if( [[NSUserDefaults standardUserDefaults] integerForKey: @"burnDestination"] == USBKey)
                {
                    [writeVolumePath release];
                    writeVolumePath = nil;
                    if( selectedUSB != NSNotFound && selectedUSB < [self volumes].count)
                        writeVolumePath = [[[self volumes] objectAtIndex: selectedUSB] retain];
                    
                    if( writeVolumePath == nil)
                    {
                        NSInteger result = NSRunCriticalAlertPanel( NSLocalizedString( @"USB Writing", nil), NSLocalizedString( @"No destination selected.", nil), NSLocalizedString( @"OK", nil), nil, nil);
                        
                        self.buttonsDisabled = NO;
                        runBurnAnimation = NO;
                        burning = NO;
                        return;
                    }
                    
                    NSInteger result = NSRunCriticalAlertPanel( NSLocalizedString( @"USB Writing", nil), NSLocalizedString( @"The ENTIRE content of the selected media (%@) will be deleted, before writing the new data. Do you confirm?", nil), NSLocalizedString( @"OK", nil), NSLocalizedString( @"Cancel", nil), nil, writeVolumePath, nil);
                    
                    if( result != NSAlertDefaultReturn)
                    {
                        self.buttonsDisabled = NO;
                        runBurnAnimation = NO;
                        burning = NO;
                        return;
                    }
                    
                    [[BrowserController currentBrowser] removePathFromSources: writeVolumePath];
                }
                
                if( [[NSUserDefaults standardUserDefaults] integerForKey: @"burnDestination"] == DMGFile)
                {
                    NSSavePanel *savePanel = [NSSavePanel savePanel];
                    [savePanel setCanSelectHiddenExtension:YES];
                    [savePanel setRequiredFileType:@"dmg"];
                    [savePanel setTitle:@"Save as DMG"];
                    
                    if( [savePanel runModalForDirectory:nil file: cdName] == NSFileHandlingPanelOKButton)
                    {
                        [writeDMGPath release];
                        writeDMGPath = [[[savePanel URL] path] retain];
                        [[NSFileManager defaultManager] removeItemAtPath: writeDMGPath error: nil];
                    }
                    else
                    {
                        self.buttonsDisabled = NO;
                        runBurnAnimation = NO;
                        burning = NO;
                        return;
                    }
                }
                
                self.password = @"";
                
                if( [[NSUserDefaults standardUserDefaults] boolForKey: @"EncryptCD"])
                {
                    int result = 0;
                    do
                    {
                        [NSApp beginSheet: passwordWindow
                           modalForWindow: self.window
                            modalDelegate: nil
                           didEndSelector: nil
                              contextInfo: nil];
                        
                        result = [NSApp runModalForWindow: passwordWindow];
                        [passwordWindow makeFirstResponder: nil];
                        
                        [NSApp endSheet: passwordWindow];
                        [passwordWindow orderOut: self];
                    }
                    while( [self.password length] < 8 && result == NSRunStoppedResponse);
                    
                    if( result == NSRunStoppedResponse)
                    {
                        
                    }
                    else
                    {
                        self.buttonsDisabled = NO;
                        runBurnAnimation = NO;
                        burning = NO;
                        return;
                    }
                }
                
                NSThread* t = [[[NSThread alloc] initWithTarget:self selector:@selector( performBurn:) object: nil] autorelease];
                t.name = NSLocalizedString( @"Burning...", nil);
                [[ThreadsManager defaultManager] addThreadAndStart: t];
            }
            else
            {
                NSBeginAlertSheet( NSLocalizedString( @"Burn Warning", nil) , NSLocalizedString( @"OK", nil), nil, nil, nil, nil, nil, nil, nil, NSLocalizedString( @"Please add CD name", nil));
                
                self.buttonsDisabled = NO;
                runBurnAnimation = NO;
                burning = NO;
                return;
            } 
        }
        @catch (NSException *exception)
        {
            NSLog( @"*** exception: %@", exception);
        }
	}
}

- (void)performBurn: (id) object
{	 
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    @try
    {
        isSettingUpBurn = YES;
        
        if( anonymizationTags)
        {
            NSDictionary* anonOut = [Anonymization anonymizeFiles:files dicomImages: dbObjects toPath:@"/tmp/burnAnonymized" withTags: anonymizationTags];
            
            [anonymizedFiles release];
            anonymizedFiles = [[anonOut allValues] mutableCopy];
        }
        
        [self prepareCDContent];
        
        isSettingUpBurn = NO;
        
        int no = 0;
            
        if( anonymizedFiles) no = [anonymizedFiles count];
        else no = [files count];
        
        burning = YES;
        
        if( [[NSFileManager defaultManager] fileExistsAtPath: [self folderToBurn]] && cancelled == NO)
        {
            if( no)
            {
                switch( [[NSUserDefaults standardUserDefaults] integerForKey: @"burnDestination"])
                {
                    case DMGFile:
                        [self createDMG: writeDMGPath withSource:[self folderToBurn]];
                    break;
                    
                    case CDDVD:
                        [self performSelectorOnMainThread:@selector( burnCD:) withObject:nil waitUntilDone:NO];
                        return;
                    break;
                        
                    case USBKey:
                        [self saveOnVolume];
                    break;
                }
            }
        }
        
        self.buttonsDisabled = NO;
        runBurnAnimation = NO;
        burning = NO;
        
        if( cancelled == NO)
        {
            // Finished ! Close the window....
            
            [[NSSound soundNamed: @"Glass.aiff"] play];
            [self.window performSelectorOnMainThread: @selector( performClose:) withObject: self waitUntilDone: NO];
        }
    }
    @catch (NSException *exception)
    {
        NSLog( @"*** exception: %@", exception);
    }
    @finally
    {
        [pool release];
    }
}

- (IBAction) setAnonymizedCheck: (id) sender
{
	if( [anonymizedCheckButton state] == NSOnState)
	{
		if( [[nameField stringValue] isEqualToString: [self defaultTitle]])
		{
			NSDate *date = [NSDate date];
			[self setCDTitle: [NSString stringWithFormat:@"Archive-%@",  [date descriptionWithCalendarFormat:@"%Y%m%d" timeZone:nil locale:nil]]];
		}
	}
}

- (void)setCDTitle: (NSString *)title
{
	if( title)
	{
		[cdName release];
		//if( [title length] > 8)
		//	title = [title substringToIndex:8];
		cdName = [[[title uppercaseString] filenameString] retain];
		[nameField setStringValue: cdName];
	}
}

-(IBAction)setCDName:(id)sender
{
	NSString *name = [[nameField stringValue] uppercaseString];
	[self setCDTitle:name];
}

-(NSString *)folderToBurn
{
	return [NSString stringWithFormat:@"/tmp/%@",cdName];
}

-(NSArray*) volumes
{
    NSArray	*removeableMedia = [[NSWorkspace sharedWorkspace] mountedRemovableMedia];
    NSMutableArray *array = [NSMutableArray array];
    
    for( NSString *mediaPath in removeableMedia)
    {
        BOOL		isWritable, isUnmountable, isRemovable, hasDICOMDIR = NO;
        NSString	*description, *type;
        
        [[NSWorkspace sharedWorkspace] getFileSystemInfoForPath: mediaPath isRemovable:&isRemovable isWritable:&isWritable isUnmountable:&isUnmountable description:&description type:&type];
        
        if( isRemovable && isWritable && isUnmountable)
            [array addObject: mediaPath];
    }
    
    return array;
}

- (void) saveOnVolume
{
    NSLog( @"Erase volume : %@", writeVolumePath);
    
    for( NSString *path in [[NSFileManager defaultManager] contentsOfDirectoryAtPath: writeVolumePath error: nil])
        [[NSFileManager defaultManager] removeItemAtPath: [writeVolumePath stringByAppendingPathComponent: path] error: nil];
    
    
    [[NSFileManager defaultManager] copyItemAtPath: [self folderToBurn] toPath: writeVolumePath byReplacingExisting: YES error: nil];
    
    NSString *newName = cdName;
    
    [[NSTask launchedTaskWithLaunchPath: @"/usr/sbin/diskutil" arguments: [NSArray arrayWithObjects: @"rename", writeVolumePath, newName, nil]] waitUntilExit];
    
    [NSThread sleepForTimeInterval: 1];
    
    //Did we succeed? Basic MS-DOS FAT support only CAPITAL letters and maximum of 10 characters...
    if( [[NSFileManager defaultManager] fileExistsAtPath: [[writeVolumePath stringByDeletingLastPathComponent] stringByAppendingPathComponent: newName]] == NO)
    {
        if( newName.length > 10)
            newName = [newName substringToIndex: 10];
        
        [[NSTask launchedTaskWithLaunchPath: @"/usr/sbin/diskutil" arguments: [NSArray arrayWithObjects: @"rename", writeVolumePath, [newName uppercaseString], nil]] waitUntilExit];
        [NSThread sleepForTimeInterval: 1];
        
        if( [[NSFileManager defaultManager] fileExistsAtPath: [[writeVolumePath stringByDeletingLastPathComponent] stringByAppendingPathComponent: newName]] == NO)
        {
            newName = @"DICOM";
            
            [[NSTask launchedTaskWithLaunchPath: @"/usr/sbin/diskutil" arguments: [NSArray arrayWithObjects: @"rename", writeVolumePath, newName, nil]] waitUntilExit];
            [NSThread sleepForTimeInterval: 1];
        }
    }
    
    [[NSWorkspace sharedWorkspace] unmountAndEjectDeviceAtPath: [[writeVolumePath stringByDeletingLastPathComponent] stringByAppendingPathComponent: newName]];
    
    NSLog( @"Ejecting new DICOM Volume: %@", newName);
}

- (void)burnCD:(id)object
{
    if( [NSThread isMainThread] == NO)
    {
        NSLog( @"******* THIS SHOULD BE ON THE MAIN THREAD: burnCD");
    }
    
    sizeInMb = [[self getSizeOfDirectory: [self folderToBurn]] intValue] / 1024;
    
	DRTrack* track = [DRTrack trackForRootFolder: [DRFolder folderWithPath: [self folderToBurn]]];
    
    if( track)
    {
        DRBurnSetupPanel *bsp = [DRBurnSetupPanel setupPanel];
        
        [bsp setDelegate: self];
        
        if( [bsp runSetupPanel] == NSOKButton)
        {
            DRBurnProgressPanel *bpp = [DRBurnProgressPanel progressPanel];
            [bpp setDelegate: self];
            [bpp beginProgressSheetForBurn:[bsp burnObject] layout:track modalForWindow: [self window]];
            
            return;
        }
	}
    
    self.buttonsDisabled = NO;
    runBurnAnimation = NO;
    burning = NO;
}

//------------------------------------------------------------------------------------------------------------------------------------
#pragma mark•

- (BOOL) validateMenuItem:(id)sender
{
	if( [sender action] == @selector(terminate:))
		return (burning == NO);		// No quitting while a burn is going on

	return YES;
}

- (BOOL) setupPanel:(DRSetupPanel*)aPanel deviceContainsSuitableMedia:(DRDevice*)device promptString:(NSString**)prompt;
{
	NSDictionary *status = [device status];
	
	int freeSpace = [[[status objectForKey: DRDeviceMediaInfoKey] objectForKey: DRDeviceMediaBlocksFreeKey] longLongValue] * 2UL / 1024UL;
	
	if( freeSpace > 0 && sizeInMb >= freeSpace)
	{
		*prompt = [NSString stringWithFormat: NSLocalizedString(@"The data to burn is larger than a media size (%d MB), you need a DVD to burn this amount of data (%d MB).", nil), freeSpace, sizeInMb];
        cancelled = YES;
		return NO;
	}
	else if( freeSpace > 0)
	{
		*prompt = [NSString stringWithFormat: NSLocalizedString(@"Data to burn: %d MB (Media size: %d MB), representing %2.2f %%.", nil), sizeInMb, freeSpace, (float) sizeInMb * 100. / (float) freeSpace];
	}
	
	return YES;

}

- (void) burnProgressPanelWillBegin:(NSNotification*)aNotification
{
	burnAnimationIndex = 0;
    runBurnAnimation = YES;
}

- (void) burnProgressPanelDidFinish:(NSNotification*)aNotification
{
    
}

- (BOOL) burnProgressPanel:(DRBurnProgressPanel*)theBurnPanel burnDidFinish:(DRBurn*)burn
{
	NSDictionary*	burnStatus = [burn status];
	NSString*		state = [burnStatus objectForKey:DRStatusStateKey];
	BOOL            succeed = NO;
    
	if( [state isEqualToString:DRStatusStateFailed])
	{
		NSDictionary*	errorStatus = [burnStatus objectForKey:DRErrorStatusKey];
		NSString*		errorString = [errorStatus objectForKey:DRErrorStatusErrorStringKey];
		
		NSRunCriticalAlertPanel( NSLocalizedString( @"Burning failed", nil), errorString, NSLocalizedString( @"OK", nil), nil, nil);
	}
	else
    {
        succeed = YES;
		[sizeField setStringValue: NSLocalizedString( @"Burning is finished !", nil)];
	}
    
    self.buttonsDisabled = NO;
    runBurnAnimation = NO;
    burning = NO;
    
    if( succeed)
        [[self window] performSelector: @selector( performClose:) withObject: nil afterDelay: 1];
	
	return YES;
}

- (void)windowWillClose:(NSNotification *)notification
{
    [irisAnimationTimer invalidate];
    [irisAnimationTimer release];
    irisAnimationTimer = nil;
    
    [burnAnimationTimer invalidate];
    [burnAnimationTimer release];
    burnAnimationTimer = nil;
    
	windowWillClose = YES;
	
	[[NSUserDefaults standardUserDefaults] setInteger: [compressionMode selectedTag] forKey:@"Compression Mode for Burning"];
	
	NSLog(@"Burner windowWillClose");
	
	[[self window] setDelegate: nil];
	
	isExtracting = NO;
	isSettingUpBurn = NO;
	burning = NO;
	runBurnAnimation = NO;
	
	[self autorelease];
}

- (BOOL)windowShouldClose:(id)sender
{
	NSLog(@"Burner windowShouldClose");
	
	if( (isExtracting || isSettingUpBurn || burning))
		return NO;
	else
	{
		[[NSFileManager defaultManager] removeFileAtPath: [self folderToBurn] handler:nil];
		[[NSFileManager defaultManager] removeFileAtPath: [NSString stringWithFormat:@"/tmp/burnAnonymized"] handler:nil];
		
		[filesToBurn release];
		filesToBurn = nil;
		[files release];
		files = nil;
		[anonymizedFiles release];
		anonymizedFiles = nil;
		
		NSLog(@"Burner windowShouldClose YES");
		
		return YES;
	}
}


//------------------------------------------------------------------------------------------------------------------------------------
#pragma mark•

- (BOOL)dicomCheck:(NSString *)filename{
	//DicomDecoder *dicomDecoder = [[[DicomDecoder alloc] init] autorelease];
	DCMObject *dcmObject = [DCMObject objectWithContentsOfFile:filename decodingPixelData:NO];
	return (dcmObject) ? YES : NO;
}

- (void)importFiles:(NSArray *)filenames{
}

- (NSString*) defaultTitle
{
	NSString *title = nil;
	
	if( [files count] > 0)
	{
		NSString *file = [files objectAtIndex:0];
		DCMObject *dcmObject = [DCMObject objectWithContentsOfFile:file decodingPixelData:NO];
		title = [dcmObject attributeValueWithName:@"PatientsName"];
	}
	else title = @"UNTITLED";
	
	return [[title uppercaseString] filenameString];
}

- (void)setup:(id)sender
{
	//NSLog(@"Set up burn");
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	runBurnAnimation = NO;
	[burnButton setEnabled:NO];
	isExtracting = YES;
	
	[self performSelectorOnMainThread:@selector(estimateFolderSize:) withObject:nil waitUntilDone:YES];
	isExtracting = NO;
    
    irisAnimationTimer = [[NSTimer timerWithTimeInterval: 0.07  target: self selector: @selector( irisAnimation:) userInfo: NO repeats: YES] retain];
    [[NSRunLoop currentRunLoop] addTimer: irisAnimationTimer forMode: NSModalPanelRunLoopMode];
    [[NSRunLoop currentRunLoop] addTimer: irisAnimationTimer forMode: NSDefaultRunLoopMode];
    
    
    burnAnimationTimer = [[NSTimer timerWithTimeInterval: 0.07  target: self selector: @selector( burnAnimation:) userInfo: NO repeats: YES] retain];
    
    [[NSRunLoop currentRunLoop] addTimer: burnAnimationTimer forMode: NSModalPanelRunLoopMode];
    [[NSRunLoop currentRunLoop] addTimer: burnAnimationTimer forMode: NSDefaultRunLoopMode];
    
	[burnButton setEnabled:YES];
	
	NSString *title = nil;
	
	if( _multiplePatients || [[NSUserDefaults standardUserDefaults] boolForKey:@"anonymizedBeforeBurning"])
	{
		NSDate *date = [NSDate date];
		title = [NSString stringWithFormat:@"Archive-%@",  [date descriptionWithCalendarFormat:@"%Y%m%d" timeZone:nil locale:nil]];
	}
	else title = [[self defaultTitle] uppercaseString];
	
	[self setCDTitle: title];
	[pool release];
}


//------------------------------------------------------------------------------------------------------------------------------------
#pragma mark•

/*+(void)image:(NSImage*)image writePGMToPath:(NSString*)ppmpath {
    NSSize scaledDownSize = [image sizeByScalingDownProportionallyToSize:NSMakeSize(128,128)];
    NSInteger width = scaledDownSize.width, height = scaledDownSize.height;
    
    static CGColorSpaceRef grayColorSpace = nil;
    if( !grayColorSpace) grayColorSpace = CGColorSpaceCreateDeviceGray();
    
    CGContextRef cgContext = CGBitmapContextCreate(NULL, width, height, 8, width, grayColorSpace, 0);
    uint8* data = CGBitmapContextGetData(cgContext);
    
    NSGraphicsContext* nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:cgContext flipped:NO];
    
    NSGraphicsContext* savedContext = [NSGraphicsContext currentContext];
    [NSGraphicsContext setCurrentContext:nsContext];
    [image drawInRect:NSMakeRect(0,0,width,height) fromRect:NSMakeRect(0,0,image.size.width,image.size.height) operation:NSCompositeCopy fraction:1];
    [NSGraphicsContext setCurrentContext:savedContext];
    
    NSMutableData* out = [NSMutableData data];
    
    [out appendData:[[NSString stringWithFormat:@"P5\n%d %d\n255\n", width, height] dataUsingEncoding:NSUTF8StringEncoding]];
    [out appendBytes:data length:width*height];
    
    [[NSFileManager defaultManager] confirmDirectoryAtPath:[ppmpath stringByDeletingLastPathComponent]];
    [out writeToFile:ppmpath atomically:YES];
    
    CGContextRelease(cgContext);
}*/

- (void)addDICOMDIRUsingDCMTK_forFilesAtPaths:(NSArray*/*NSString*/)paths dicomImages:(NSArray*/*DicomImage*/)dimages
{
    [DicomDir createDicomDirAtDir:[self folderToBurn]];
}

- (void) produceHtml:(NSString*) burnFolder
{
	//We want to create html only for the images, not for PR, and hidden DICOM SR
	NSMutableArray *images = [NSMutableArray arrayWithCapacity: [originalDbObjects count]];
	
	for( id obj in originalDbObjects)
	{
		if( [DicomStudy displaySeriesWithSOPClassUID: [obj valueForKeyPath:@"series.seriesSOPClassUID"] andSeriesDescription: [obj valueForKeyPath:@"series.name"]])
			[images addObject: obj];
	}
	
	[[BrowserController currentBrowser] exportQuicktimeInt: images :burnFolder :YES];
}

- (NSNumber*) getSizeOfDirectory: (NSString*) path
{
	if( [[NSFileManager defaultManager] fileExistsAtPath: path] == NO) return [NSNumber numberWithLong: 0];

	if( [[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:NO]fileType]!=NSFileTypeSymbolicLink || [[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:NO]fileType]!=NSFileTypeUnknown)
	{
		NSArray *args = nil;
		NSPipe *fromPipe = nil;
		NSFileHandle *fromDu = nil;
		NSData *duOutput = nil;
		NSString *size = nil;
		NSArray *stringComponents = nil;
		char aBuffer[ 300];

		args = [NSArray arrayWithObjects:@"-ks",path,nil];
		fromPipe =[NSPipe pipe];
		fromDu = [fromPipe fileHandleForWriting];
		NSTask *duTool = [[[NSTask alloc] init] autorelease];

		[duTool setLaunchPath:@"/usr/bin/du"];
		[duTool setStandardOutput:fromDu];
		[duTool setArguments:args];
		[duTool launch];
		[duTool waitUntilExit];
		
		duOutput = [[fromPipe fileHandleForReading] availableData];
		[duOutput getBytes:aBuffer];
		
		size = [NSString stringWithCString:aBuffer];
		stringComponents = [size pathComponents];
		
		size = [stringComponents objectAtIndex:0];
		size = [size substringToIndex:[size length]-1];
		
		return [NSNumber numberWithUnsignedLongLong:(unsigned long long)[size doubleValue]];
	}
	else return [NSNumber numberWithUnsignedLongLong:(unsigned long long)0];
}

- (IBAction) cancel:(id)sender
{
	[NSApp abortModal];
}

- (IBAction) ok:(id)sender
{
	[NSApp stopModal];
}

- (NSString*) cleanStringForFile: (NSString*) s
{
	s = [s stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
	s = [s stringByReplacingOccurrencesOfString:@":" withString:@"-"];
	
	return s;	
}

- (void) prepareCDContent
{
    NSThread* thread = [NSThread currentThread];
    
	[finalSizeField performSelectorOnMainThread:@selector(setStringValue:) withObject:@"" waitUntilDone:YES];
    
	@try
    {
        NSEnumerator *enumerator;
        if( anonymizedFiles) enumerator = [anonymizedFiles objectEnumerator];
        else enumerator = [files objectEnumerator];
        
        NSString *file;
        NSString *burnFolder = [self folderToBurn];
        NSString *dicomdirPath = [NSString stringWithFormat:@"%@/DICOMDIR",burnFolder];
        NSString *subFolder = [NSString stringWithFormat:@"%@/DICOM",burnFolder];
        NSFileManager *manager = [NSFileManager defaultManager];
        int i = 0;

        //create burn Folder and dicomdir.
        
        if( ![manager fileExistsAtPath:burnFolder])
            [manager createDirectoryAtPath:burnFolder attributes:nil];
        if( ![manager fileExistsAtPath:subFolder])
            [manager createDirectoryAtPath:subFolder attributes:nil];
        if( ![manager fileExistsAtPath:dicomdirPath])
            [manager copyPath:[[NSBundle mainBundle] pathForResource:@"DICOMDIR" ofType:nil] toPath:dicomdirPath handler:nil];
            
        NSMutableArray *newFiles = [NSMutableArray array];
        NSMutableArray *compressedArray = [NSMutableArray array];
        
        while((file = [enumerator nextObject]) && cancelled == NO)
        {
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            NSString *newPath = [NSString stringWithFormat:@"%@/%05d", subFolder, i++];
            DCMObject *dcmObject = [DCMObject objectWithContentsOfFile:file decodingPixelData:NO];
            //Don't want Big Endian, May not be readable
            if( [[dcmObject transferSyntax] isEqualToTransferSyntax:[DCMTransferSyntax ExplicitVRBigEndianTransferSyntax]])
                [dcmObject writeToFile:newPath withTransferSyntax:[DCMTransferSyntax ImplicitVRLittleEndianTransferSyntax] quality: DCMLosslessQuality atomically:YES];
            else
                [manager copyPath:file toPath:newPath handler:nil];
                
            if( dcmObject)	// <- it's a DICOM file
            {
                switch( [compressionMode selectedTag])
                {
                    case 0:
                    break;
                    
                    case 1:
                        [compressedArray addObject: newPath];
                    break;
                    
                    case 2:
                        [compressedArray addObject: newPath];
                    break;
                }
            }
            
            [newFiles addObject:newPath];
            [pool release];
        }
        
        if( [newFiles count] > 0 && cancelled == NO)
        {
            switch( [compressionMode selectedTag])
            {
                case 1:
                    [[BrowserController currentBrowser] decompressArrayOfFiles: compressedArray work: [NSNumber numberWithChar: 'C']];
                break;
                
                case 2:
                    [[BrowserController currentBrowser] decompressArrayOfFiles: compressedArray work: [NSNumber numberWithChar: 'D']];
                break;
            }
            
            thread.name = NSLocalizedString( @"Burning...", nil);
            thread.status = NSLocalizedString( @"Writing DICOMDIR...", nil);
            [self addDICOMDIRUsingDCMTK_forFilesAtPaths:newFiles dicomImages:dbObjects];
            
            if( [[NSUserDefaults standardUserDefaults] boolForKey: @"BurnWeasis"] && cancelled == NO)
            {
                thread.name = NSLocalizedString( @"Burning...", nil);
                thread.status = NSLocalizedString( @"Adding Weasis...", nil);
                NSString* weasisPath = [[AppController sharedAppController] weasisBasePath];
                for (NSString* subpath in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:weasisPath error:NULL])
                    [[NSFileManager defaultManager] copyItemAtPath:[weasisPath stringByAppendingPathComponent:subpath] toPath:[burnFolder stringByAppendingPathComponent:subpath] error:NULL];
            }
            
            if( [[NSUserDefaults standardUserDefaults] boolForKey: @"BurnOsirixApplication"] && cancelled == NO)
            {
                thread.name = NSLocalizedString( @"Burning...", nil);
                thread.status = NSLocalizedString( @"Adding OsiriX Lite...", nil);
                // unzip the file
                NSTask *unzipTask = [[NSTask alloc] init];
                [unzipTask setLaunchPath: @"/usr/bin/unzip"];
                [unzipTask setCurrentDirectoryPath: burnFolder];
                [unzipTask setArguments: [NSArray arrayWithObjects: @"-o", [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: @"OsiriX Launcher.zip"], nil]]; // -o to override existing report w/ same name
                [unzipTask launch];
                [unzipTask waitUntilExit];
                [unzipTask release];
            }
            
            if(  [[NSUserDefaults standardUserDefaults] boolForKey: @"BurnHtml"] == YES && [[NSUserDefaults standardUserDefaults] boolForKey:@"anonymizedBeforeBurning"] == NO && cancelled == NO)
            {
                thread.name = NSLocalizedString( @"Burning...", nil);
                thread.status = NSLocalizedString( @"Adding HTML pages...", nil);
                [self produceHtml: burnFolder];
            }
            
            if( [[NSUserDefaults standardUserDefaults] boolForKey: @"BurnSupplementaryFolder"] && cancelled == NO)
            {
                thread.name = NSLocalizedString( @"Burning...", nil);
                thread.status = NSLocalizedString( @"Adding Supplementary folder...", nil);
                NSString *supplementaryBurnPath = [[NSUserDefaults standardUserDefaults] stringForKey: @"SupplementaryBurnPath"];
                if( supplementaryBurnPath)
                {
                    supplementaryBurnPath = [supplementaryBurnPath stringByExpandingTildeInPath];
                    if( [manager fileExistsAtPath: supplementaryBurnPath])
                    {
                        NSEnumerator *enumerator = [manager enumeratorAtPath: supplementaryBurnPath];
                        while (file=[enumerator nextObject])
                        {
                            [manager copyPath: [NSString stringWithFormat:@"%@/%@", supplementaryBurnPath,file] toPath: [NSString stringWithFormat:@"%@/%@", burnFolder,file] handler:nil]; 
                        }
                    }
                }
            }
            
            if( [[NSUserDefaults standardUserDefaults] boolForKey: @"copyReportsToCD"] == YES && [[NSUserDefaults standardUserDefaults] boolForKey:@"anonymizedBeforeBurning"] == NO && cancelled == NO)
            {
                thread.name = NSLocalizedString( @"Burning...", nil);
                thread.status = NSLocalizedString( @"Adding Reports...", nil);
                
                NSMutableArray *studies = [NSMutableArray array];
                
                [idatabase lock];
                
                for( NSManagedObject *im in dbObjects)
                {
                    if( [im valueForKeyPath:@"series.study.reportURL"])
                    {
                        if( [studies containsObject: [im valueForKeyPath:@"series.study"]] == NO)
                            [studies addObject: [im valueForKeyPath:@"series.study"]];
                    }
                }
                
                for( DicomStudy *study in studies)
                {
                    if( [[study valueForKey: @"reportURL"] hasPrefix: @"http://"] || [[study valueForKey: @"reportURL"] hasPrefix: @"https://"])
                    {
                        NSString *urlContent = [NSString stringWithContentsOfURL: [NSURL URLWithString: [study valueForKey: @"reportURL"]]];
                        
                        [urlContent writeToFile: [NSString stringWithFormat:@"%@/Report-%@ %@.%@", burnFolder, [self cleanStringForFile: [study valueForKey:@"modality"]], [self cleanStringForFile: [BrowserController DateTimeWithSecondsFormat: [study valueForKey:@"date"]]], [self cleanStringForFile: [[study valueForKey:@"reportURL"] pathExtension]]] atomically: YES];
                    }
                    else
                    {
                        // Convert to PDF
                        
                        NSString *pdfPath = [study saveReportAsPdfInTmp];
                        
                        if( [manager fileExistsAtPath: pdfPath] == NO)
                            [manager copyPath: [study valueForKey:@"reportURL"] toPath: [NSString stringWithFormat:@"%@/Report-%@ %@.%@", burnFolder, [self cleanStringForFile: [study valueForKey:@"modality"]], [self cleanStringForFile: [BrowserController DateTimeWithSecondsFormat: [study valueForKey:@"date"]]], [self cleanStringForFile: [[study valueForKey:@"reportURL"] pathExtension]]] handler:nil]; 
                        else
                            [manager copyPath: pdfPath toPath: [NSString stringWithFormat:@"%@/Report-%@ %@.pdf", burnFolder, [self cleanStringForFile: [study valueForKey:@"modality"]], [self cleanStringForFile: [BrowserController DateTimeWithSecondsFormat: [study valueForKey:@"date"]]]] handler: nil];
                    }
                    
                    if( cancelled)
                        break;
                }
                
                [idatabase unlock];
            }
        }
        
        if( [[NSUserDefaults standardUserDefaults] boolForKey: @"EncryptCD"] && cancelled == NO)
        {
            if( cancelled == NO)
            {
                thread.name = NSLocalizedString( @"Burning...", nil);
                thread.status = NSLocalizedString( @"Encrypting...", nil);
                
                // ZIP method - zip test.zip /testFolder -r -e -P hello
                
                [BrowserController encryptFileOrFolder: burnFolder inZIPFile: [[burnFolder stringByDeletingLastPathComponent] stringByAppendingPathComponent: @"encryptedDICOM.zip"] password: self.password];
                self.password = @"";
                
                [[NSFileManager defaultManager] removeItemAtPath: burnFolder error: nil];
                [[NSFileManager defaultManager] createDirectoryAtPath: burnFolder attributes: nil];
                
                [[NSFileManager defaultManager] moveItemAtPath: [[burnFolder stringByDeletingLastPathComponent] stringByAppendingPathComponent: @"encryptedDICOM.zip"] toPath: [burnFolder stringByAppendingPathComponent: @"encryptedDICOM.zip"] error: nil];
                [[NSString stringWithString: NSLocalizedString( @"The images are encrypted with a password in this ZIP file: first, unzip this file to read the content. Use an Unzip application to extract the files.", nil)] writeToFile: [burnFolder stringByAppendingPathComponent: @"ReadMe.txt"] atomically: YES encoding: NSASCIIStringEncoding error: nil];
            }
        }
        
        thread.name = NSLocalizedString( @"Burning...", nil);
        thread.status = [NSString stringWithFormat: NSLocalizedString( @"Writing %3.2fMB...", nil), (float) ([[self getSizeOfDirectory: burnFolder] longLongValue] / 1024)];
        
        [finalSizeField performSelectorOnMainThread:@selector(setStringValue:) withObject:[NSString stringWithFormat:@"Final files size to burn: %3.2fMB", (float) ([[self getSizeOfDirectory: burnFolder] longLongValue] / 1024)] waitUntilDone:YES];
    }
    @catch( NSException * e)
    {
        NSLog(@"Exception while creating DICOMDIR: %@", e);
    }
}

- (IBAction) estimateFolderSize: (id) sender
{
	NSString				*file;
	long					size = 0;
	NSFileManager			*manager = [NSFileManager defaultManager];
	NSDictionary			*fattrs;
	
	for (file in files)
	{
		fattrs = [manager fileAttributesAtPath:file traverseLink:YES];
		size += [fattrs fileSize]/1024;
	}
	
	if( [[NSUserDefaults standardUserDefaults] boolForKey: @"BurnWeasis"])
	{
		size += 17 * 1024; // About 17MB
	}
	
	if( [[NSUserDefaults standardUserDefaults] boolForKey: @"BurnOsirixApplication"])
	{
		size += 8 * 1024; // About 8MB
	}
	
	if( [[NSUserDefaults standardUserDefaults] boolForKey: @"BurnSupplementaryFolder"])
	{
		size += [[self getSizeOfDirectory: [[NSUserDefaults standardUserDefaults] stringForKey: @"SupplementaryBurnPath"]] longLongValue];
	}
	
	[sizeField setStringValue:[NSString stringWithFormat:@"%@ %d  %@ %3.2fMB", NSLocalizedString(@"No of files:", nil), [files count], NSLocalizedString(@"Files size (without compression):", nil), size/1024.0]];
}


//------------------------------------------------------------------------------------------------------------------------------------
#pragma mark•

- (void)burnAnimation:(NSTimer *)timer
{
	if( windowWillClose)
		return;
	
    if( runBurnAnimation == NO)
        return;
    
    if( burnAnimationIndex > 11)
        burnAnimationIndex = 0;
    
    NSString *animation = [NSString stringWithFormat:@"burn_anim%02d.tif", burnAnimationIndex++];
    NSImage *image = [NSImage imageNamed: animation];
    [burnButton setImage:image];
}

-(void)irisAnimation:(NSTimer*) timer
{
    if( runBurnAnimation)
        return;
    
	if( irisAnimationIndex > 17)
        irisAnimationIndex = 0;
    
    NSString *animation = [NSString stringWithFormat:@"burn_iris%02d.tif", irisAnimationIndex++];
    NSImage *image = [NSImage imageNamed: animation];
    [burnButton setImage:image];
}
@end
