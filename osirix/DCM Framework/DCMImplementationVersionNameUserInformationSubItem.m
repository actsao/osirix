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

/*************
The networking code of the DCMFramework is predominantly a port of the 11/4/04 version of the java pixelmed toolkit by David Clunie.
htt://www.pixelmed.com   
**************/

#import "DCMImplementationVersionNameUserInformationSubItem.h"


@implementation DCMImplementationVersionNameUserInformationSubItem

+ (id)implementationVersionNameUserInformationSubItemWithType:(unsigned char)aType length:(int)theLength implementationVersionName:(NSString *)implementationName{
	return [[[DCMImplementationVersionNameUserInformationSubItem alloc] initWithType:aType length:theLength implementationVersionName:implementationName] autorelease];
}

- (id)initWithType:(unsigned char)aType length:(int)theLength implementationVersionName:(NSString *)implementationName{
	if (self = [super initWithType:aType length:theLength])
		implementationVersionName = [implementationName retain];
	return self;
}

- (void)dealloc{
	[implementationVersionName release];
	[super dealloc];
}

- (NSString *)implementationVersionName{
	return implementationVersionName;
}

@end
