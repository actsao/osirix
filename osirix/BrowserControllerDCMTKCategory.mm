/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - GPL
  
  See http://www.osirix-viewer.com/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/

#import "BrowserControllerDCMTKCategory.h"
#import <OsiriX/DCMObject.h>
#import <OsiriX/DCMTransferSyntax.h>
#import "AppController.h"

#undef verify
#include "osconfig.h" /* make sure OS specific configuration is included first */
#include "djdecode.h"  /* for dcmjpeg decoders */
#include "djencode.h"  /* for dcmjpeg encoders */
#include "dcrledrg.h"  /* for DcmRLEDecoderRegistration */
#include "dcrleerg.h"  /* for DcmRLEEncoderRegistration */
#include "djrploss.h"
#include "djrplol.h"
#include "dcpixel.h"
#include "dcrlerp.h"

#include "dcdatset.h"
#include "dcmetinf.h"
#include "dcfilefo.h"
#include "dcdebug.h"
#include "dcuid.h"
#include "dcdict.h"
#include "dcdeftag.h"

@implementation BrowserController (BrowserControllerDCMTKCategory)

- (BOOL)compressDICOMWithJPEG:(NSString *)path
{
	NSTask *theTask = [[NSTask alloc] init];
	
	[theTask setArguments: [NSArray arrayWithObjects:path, @"compress", 0L]];
	[theTask setLaunchPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"/Decompress"]];
	[theTask launch];
	if( [NSThread currentThread] == [AppController mainThread]) [theTask waitUntilExit];	//<- The problem with this: it calls the current running loop.... problems with current Lock !
	else while( [theTask isRunning]) [NSThread sleepForTimeInterval: 0.01];
	[theTask release];

	return YES;

}

- (BOOL)decompressDICOM:(NSString *)path to:(NSString*) dest deleteOriginal:(BOOL) deleteOriginal
{
	NSTask *theTask = [[NSTask alloc] init];
	
	[theTask setArguments: [NSArray arrayWithObjects:path, @"decompress", dest,  0L]];
	[theTask setLaunchPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"/Decompress"]];
	[theTask launch];
	if( [NSThread currentThread] == [AppController mainThread]) [theTask waitUntilExit];	//<- The problem with this: it calls the current running loop.... problems with current Lock !
	else while( [theTask isRunning]) [NSThread sleepForTimeInterval: 0.01];
	[theTask release];

	if( dest && [dest isEqualToString:path] == NO)
	{
		if( deleteOriginal) [[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
	}
	
	return YES;
}

- (BOOL)decompressDICOM:(NSString *)path to:(NSString*) dest
{
	[self decompressDICOM: path to: dest deleteOriginal:YES];
}
@end
