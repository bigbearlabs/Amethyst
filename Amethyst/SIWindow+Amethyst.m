//
//  SIWindow+Amethyst.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 10/5/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "SIWindow+Amethyst.h"
#import "AMConfiguration.h"

#import <objc/runtime.h>
#include <ApplicationServices/ApplicationServices.h>

#import "NSObject+AssociatedDictionary.h"
#import "BBLTrackingWindow.h"
#import "AMAppDelegate.h"

static void *SIWindowFloatingKey = &SIWindowFloatingKey;



@implementation SIWindow (Amethyst)

- (BOOL)shouldBeManaged {
    if (!self.isResizable && !self.isMovable) {
        return NO;
    }

    NSString *subrole = [self stringForKey:kAXSubroleAttribute];

    if (!subrole) return YES;
    if ([subrole isEqualToString:(__bridge NSString *)kAXStandardWindowSubrole]) return YES;

    return NO;
}

- (BOOL)floating {
    return [objc_getAssociatedObject(self, SIWindowFloatingKey) boolValue];
}

- (void)setFloating:(BOOL)floating {
    objc_setAssociatedObject(self, SIWindowFloatingKey, @(floating), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)am_focusWindow {
    if (![self focusWindow]) return NO;

    if ([[AMConfiguration sharedConfiguration] mouseFollowsFocus]) {
        NSRect windowFrame = [self frame];
        NSPoint mouseCursorPoint = NSMakePoint(NSMidX(windowFrame), NSMidY(windowFrame));
        CGEventRef mouseMoveEvent = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, mouseCursorPoint, kCGMouseButtonLeft);
        CGEventSetFlags(mouseMoveEvent, 0);
        CGEventPost(kCGHIDEventTap, mouseMoveEvent);
        CFRelease(mouseMoveEvent);
    }

    return YES;
}

// TODO memoise results.
- (NSNumber*) windowId {
  NSNumber* windowId = nil;
  
  CFArrayRef windowDescriptions = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
  pid_t processIdentifier = self.processIdentifier;
  for (NSDictionary *dictionary in (__bridge NSArray *)windowDescriptions) {
    pid_t windowOwnerProcessIdentifier = [dictionary[(__bridge NSString *)kCGWindowOwnerPID] intValue];
    if (windowOwnerProcessIdentifier != processIdentifier) continue;
    
    CGRect windowFrame;
    NSDictionary *boundsDictionary = dictionary[(__bridge NSString *)kCGWindowBounds];
    CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)boundsDictionary, &windowFrame);
    if (!CGRectEqualToRect(windowFrame, self.frame)) continue;
    
    NSString* title = self.title;
    
    NSString *windowTitle = dictionary[(__bridge NSString *)kCGWindowName];
    if (![windowTitle isEqualToString:title]) continue;
    
    windowId = [dictionary[(__bridge NSString*)kCGWindowNumber] copy];
//    windowId = CFDictionaryGetValue((__bridge CFDictionaryRef)dictionary, kCGWindowNumber);
    
    break;
  }
  
  //    debug
  if ( ! windowId) {
    NSLog(@"couldn't get window id for %@. frame: %@", self, [NSValue valueWithRect:self.frame]);
  }
  
  CFRelease(windowDescriptions);
  
  return [windowId copy];
}


- (BOOL)isZoomed {
  return [[[[NSApp delegate] associatedDictionary][@"zoomed_frames"] allKeys] containsObject:self.windowId];
}


- (CGRect)unzoomedFrame {
  NSMutableDictionary* unzoomedFrames = [[NSApp delegate] associatedDictionary][@"unzoomed_frames"];
  return [unzoomedFrames[self.windowId] rectValue];
}

- (void)saveUnzoomedFrame:(CGRect)frame {
  NSMutableDictionary* unzoomedFrames = [[NSApp delegate] associatedDictionary][@"unzoomed_frames"];
  if ( ! unzoomedFrames) {
    unzoomedFrames = [@{} mutableCopy];
    [[NSApp delegate] associatedDictionary][@"unzoomed_frames"] = unzoomedFrames;
  }
  
  unzoomedFrames[self.windowId] = [NSValue valueWithRect:frame];
}


- (CGRect) zoomedFrame {
  return [[[NSApp delegate] associatedDictionary][@"zoomed_frames"][self.windowId] rectValue];
}

- (void) saveZoomedFrame:(CGRect)frame {
  NSMutableDictionary* frames = [[NSApp delegate] associatedDictionary][@"zoomed_frames"];
  if ( ! frames) {
    frames = [@{} mutableCopy];
    [[NSApp delegate] associatedDictionary][@"zoomed_frames"] = frames;
  }
  
  frames[self.windowId] = [NSValue valueWithRect:frame];
}


// SIWindows are not guaranteed to be unique. Work around by storing state in a global associated dictionary.
- (BBLTrackingWindow*) overlay {
  NSMutableDictionary* overlays = [[NSApp delegate] associatedDictionary][@"overlays"];
  if ( ! overlays ) {
    overlays = [@{} mutableCopy];
    [[NSApp delegate] associatedDictionary][@"overlays"] = overlays;
  }
  
  id windowId = self.windowId;
  
  // windowId relies on matching frames, so will return nil when window is moving or resizing. ignore in that case.
  if ( ! windowId ) return nil;
  
  BBLTrackingWindow* overlay = overlays[windowId];
  if ( ! overlay ) {
    overlay = [[BBLTrackingWindow alloc] initWithWindow:self windowManager:[(AMAppDelegate*)[NSApp delegate] performSelector:@selector(windowManager)]];
    overlays[windowId] = overlay;
  }

  return overlay;
}

- (void) updateOverlay {
  [[self.class visibleOverlay] hide];
  if (self.isNormalWindow) {
    [self.overlay show];
  
    // update overlay tracking frame.
    [self.overlay updateForWindow:self];
  }
}


+ (BBLTrackingWindow*) visibleOverlay {
  for (BBLTrackingWindow* overlay in [[[NSApp delegate] associatedDictionary][@"overlays"] allValues]) {
    if ( overlay.isVisible ) {
      return overlay;
    }
  }
  return nil;
}

@end
