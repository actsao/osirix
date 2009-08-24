//
//  ArthroplastyTemplatingSplitView.m
//  Arthroplasty Templating II
//
//  Created by Alessandro Volz on 6/10/09.
//  Copyright 2009 HUG. All rights reserved.
//

#import "ArthroplastyTemplatingSplitView.h"
#include <algorithm>

@implementation ArthroplastyTemplatingSplitView


-(void)awakeFromNib {
	[self setDelegate:self];
}

// keep the right subview's size constant
-(void)splitView:(NSSplitView*)sender resizeSubviewsWithOldSize:(NSSize)oldSize {
	NSView* left = (NSView*)[[sender subviews] objectAtIndex:0];
	NSView* right = (NSView*)[[sender subviews] objectAtIndex:1];
	
	NSRect splitFrame = [sender frame];
	CGFloat dividerThickness = [sender dividerThickness];
	CGFloat availableWidth = splitFrame.size.width - dividerThickness;
	
	NSRect leftFrame = [left frame];
	NSRect rightFrame = [right frame];
	
	leftFrame.size.height = splitFrame.size.height;
	leftFrame.size.width = std::max(availableWidth - rightFrame.size.width, 100.f);
	[left setFrame:leftFrame];	
	
	rightFrame.size.height = splitFrame.size.height;
	rightFrame.origin.x = leftFrame.size.width + dividerThickness;
	rightFrame.size.width = availableWidth - leftFrame.size.width;
	[right setFrame:rightFrame];
}

@end
