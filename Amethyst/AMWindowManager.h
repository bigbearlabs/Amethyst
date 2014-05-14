//
//  AMWindowManager.h
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import <Foundation/Foundation.h>


// Object for managing the windows across all screens and spaces.
@interface AMWindowManager : NSObject

- (void)toggleFloatForFocusedWindow;

- (NSArray *)windowsForScreen:(NSScreen *)screen;

@end
