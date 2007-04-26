//
//  OSIPoint3D.h
//  OsiriX
//
//  Created by Lance Pysher on 4/26/07.
/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - GPL
  
  See http://homepage.mac.com/rossetantoine/osirix/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/

// This class represents a 3D point;

#import <Cocoa/Cocoa.h>


@interface OSIPoint3D : NSObject {
	float _x;
	float _y;
	float _z;
}

- (float)x;
- (float)y;
- (float)z;

- (void)setX:(float)x;
- (void)setY:(float)y;
- (void)setZ:(float)z;

// init with x, y, and z
- (id)initWithX:(float)x  y:(float)y  z:(float)z;
// init with the point and the slice
- (id)initWithPoint:(NSPoint)point  slice:(long)slice;

+ (id)pointWithX:(float)x  y:(float)y  z:(float)z;
+ (id)pointWithNSPoint:(NSPoint)point  slice:(long)slice;

@end
