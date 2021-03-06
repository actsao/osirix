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

#import "OSI3DPreferencePane.h"

@implementation OSI3DPreferencePanePref

- (id) initWithBundle:(NSBundle *)bundle
{
	if( self = [super init])
	{
		NSNib *nib = [[NSNib alloc] initWithNibNamed: @"OSI3DPreferencePanePref" bundle: nil];
		[nib instantiateNibWithOwner:self topLevelObjects: nil];
		
		[self setMainView: [mainWindow contentView]];
		[self mainViewDidLoad];
	}
	
	return self;
}

- (void) dealloc
{
	NSLog(@"dealloc OSI3DPreferencePanePref");
	
	[super dealloc];
}

- (long) vramSize
{
	int					i = 0;
	short				MAXDISPLAYS = 8;
	io_service_t		dspPorts[MAXDISPLAYS];
	CGDirectDisplayID   displays[MAXDISPLAYS];
	CFTypeRef			typeCode;
	CGDisplayCount		displayCount = 0;
	
	// First we're going to grab the online displays
	CGGetOnlineDisplayList(MAXDISPLAYS, displays, &displayCount);
	
	// Now we iterate through them
	for(i = 0; i < displayCount; i++)
		dspPorts[i] = CGDisplayIOServicePort(displays[i]);

	// Ask for the physical size of VRAM of the primary display
	typeCode = IORegistryEntryCreateCFProperty(dspPorts[0], CFSTR("IOFBMemorySize"), kCFAllocatorDefault, kNilOptions);
	
	// Validate our data and make sure we're getting the right type
	if(typeCode && CFGetTypeID(typeCode) == CFNumberGetTypeID())
	{
		long vramStorage = 0;
		// Convert this to a useable number
		CFNumberGetValue(typeCode, kCFNumberSInt32Type, &vramStorage);
		
		CFRelease( typeCode);
		typeCode = nil;
		
		// If we get something other than 0, we'll use it
		if(vramStorage > 0)
			return vramStorage;
	}
	
	if( typeCode)
		CFRelease( typeCode);
	
	return 0;
}

- (void) willUnselect
{
	[[[self mainView] window] makeFirstResponder: nil];
}

- (void) mainViewDidLoad
{
//	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	

	
//	//setup GUI	
//	long vram = [self vramSize]  / (1024L * 1024L);
//	long with, without;
//	
//	if( vram >= 512)
//	{	
//		without = 256;
//		with = 128;
//	}
//	else if( vram >= 256)
//	{
//		without = 128;
//		with = 64;
//	}
//	else if( vram >= 128)
//	{
//		without = 128;
//		with = 32;
//	}
//	else
//	{
//		without = 32;
//		with = 32;
//	}
//	
//
//	
//	[bestRenderingSlider setFloatValue: 2.1 - [defaults floatForKey: @"BESTRENDERING"]];
//	[bestRenderingString setStringValue: [NSString stringWithFormat:@"%2.2f", [defaults floatForKey: @"BESTRENDERING"]]];
	
	
//	int i = [defaults integerForKey: @"MAX3DTEXTURE"], x = 1;
//	
//	while( i > 32)
//	{
//		i /= 2;
//		x++;
//	}
//	
//	[max3DTextureSlider setFloatValue: x];
//	[max3DTextureString setIntValue: [defaults integerForKey: @"MAX3DTEXTURE"]];
//	
//	i = [defaults integerForKey: @"MAX3DTEXTURESHADING"];
//	x = 1;
//	
//	while( i > 32)
//	{
//		i /= 2;
//		x++;
//	}
//	
//	[max3DTextureSliderShading setFloatValue: x];
//	[max3DTextureStringShading setIntValue: [defaults integerForKey: @"MAX3DTEXTURESHADING"]];
}

//- (IBAction) setBestRendering: (id) sender
//{
//	[[NSUserDefaults standardUserDefaults] setFloat: 2.1 - [sender floatValue] forKey: @"BESTRENDERING"];
//	[bestRenderingString setStringValue: [NSString stringWithFormat:@"%2.2f", [[NSUserDefaults standardUserDefaults] floatForKey: @"BESTRENDERING"]]];
//	NSLog(@"Rendering resolution: %f", [[NSUserDefaults standardUserDefaults] floatForKey:@"BESTRENDERING"] );
//}

//- (IBAction) setMax3DTexture: (id) sender
//{
//	int i = [sender intValue], x = 32;
//	
//	while( i > 1)
//	{
//		x *= 2;
//		i--;
//	}
//	
//	[[NSUserDefaults standardUserDefaults] setInteger: x forKey: @"MAX3DTEXTURE"];
//	[max3DTextureString setIntValue: [[NSUserDefaults standardUserDefaults] integerForKey:@"MAX3DTEXTURE"]];
//	NSLog(@"MAX3DTEXTURE: %d", [[NSUserDefaults standardUserDefaults] integerForKey:@"MAX3DTEXTURE"] );
//}
//
//- (IBAction) setMax3DTextureShading: (id) sender
//{
//	int i = [sender intValue], x = 32;
//	
//	while( i > 1)
//	{
//		x *= 2;
//		i--;
//	}
//	
//	[[NSUserDefaults standardUserDefaults] setInteger: x forKey: @"MAX3DTEXTURESHADING"];
//	[max3DTextureStringShading setIntValue: [[NSUserDefaults standardUserDefaults] integerForKey:@"MAX3DTEXTURESHADING"]];
//	NSLog(@"MAX3DTEXTURESHADING: %d", [[NSUserDefaults standardUserDefaults] integerForKey:@"MAX3DTEXTURESHADING"] );
//	
//	// No shading value is at least equal
//	
//	if( [[NSUserDefaults standardUserDefaults] integerForKey: @"MAX3DTEXTURESHADING"] > [[NSUserDefaults standardUserDefaults] integerForKey: @"MAX3DTEXTURE"])
//	{
//		[[NSUserDefaults standardUserDefaults] setInteger: x forKey: @"MAX3DTEXTURE"];
//		[self mainViewDidLoad];
//	}
//}


@end
