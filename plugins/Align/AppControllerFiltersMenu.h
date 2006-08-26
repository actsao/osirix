//
//  AppControllerFiltersMenu.h
//  OsiriX
//
//  Created by Joël Spaltenstein on 3/19/06.
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

#import <AppController.h>

@interface AppController (filtersMenu)

-(NSMenu *) filtersMenu;
-(NSMenu *) roisMenu;

@end
