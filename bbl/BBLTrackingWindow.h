//
//  BBLTrackingWindow.h
//  Amethyst
//
//  Created by ilo-robbie on 25/03/2014.
//  Copyright (c) 2014 Ian Ynda-Hummel. All rights reserved.
//

#import <Foundation/Foundation.h>
@class AMWindowManager;

@interface BBLTrackingWindow : NSPanel

-(BBLTrackingWindow*) initWithWindow:(SIWindow*)window windowManager:(AMWindowManager*)windowManager;

-(void) updateFrame:(SIWindow*)window;

-(void) hide;

-(void) show;

@property(weak) SIWindow* originalWindow;

@end
