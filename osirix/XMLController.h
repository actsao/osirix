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



#import <Cocoa/Cocoa.h>

@interface XMLController : NSWindowController
{
    IBOutlet NSOutlineView		*table;
	IBOutlet NSScrollView		*tableScrollView;
    IBOutlet NSSearchField		*search;
    IBOutlet NSView				*searchView;
	
	IBOutlet NSWindow			*levelSelection;
	IBOutlet NSMatrix			*levelMatrix;
	
    NSMutableArray          *xmlDcmData;    
    NSData                  *xmlData;    
    NSToolbar               *toolbar;	
	NSString				*srcFile;
	NSXMLDocument			*xmlDocument;
	NSManagedObject			*imObj;
	
	BOOL					isDICOM;
}

- (id) initWithImage:(NSManagedObject*) image windowName:(NSString*) name;
- (void) setupToolbar;

- (void) expandAllItems: (id) sender;
- (void) deepExpandAllItems: (id) sender;
- (void) expandAll: (BOOL) deep;
- (void) collapseAllItems: (id) sender;
- (void) deepCollapseAllItems: (id) sender;
- (void) collapseAll: (BOOL) deep;
- (IBAction) setSearchString:(id) sender;

- (NSString*) stringsSeparatedForNode:(NSXMLNode*) node;
- (void) traverse: (NSXMLNode*) node string:(NSMutableString*) string;

@end
