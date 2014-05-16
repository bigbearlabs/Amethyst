//
//  AMWindowManager.m
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMWindowManager.h"

#import "NSRunningApplication+Manageable.h"
#import "SIAccessibilityElement.h"
#import "NSObject+AssociatedDictionary.h"
#import "BBLTrackingWindow.h"
#import "SIApplication.h"
#import "SIWindow.h"
#import "EXTSelectorChecking.h"
#import "SIWindow+Amethyst.h"

@interface AMWindowManager ()
@property (nonatomic, strong) NSMutableArray *applications;
@property (nonatomic, strong) NSMutableArray *windows;

@property (nonatomic, strong) NSArray *screenManagers;

- (void)applicationDidLaunch:(NSNotification *)notification;
- (void)applicationDidTerminate:(NSNotification *)notification;
- (void)applicationDidHide:(NSNotification *)notification;
- (void)applicationDidUnhide:(NSNotification *)notification;
- (void)activeSpaceDidChange:(NSNotification *)notification;
- (void)screenParametersDidChange:(NSNotification *)notification;

- (SIApplication *)applicationWithProcessIdentifier:(pid_t)processIdentifier;
- (void)addApplication:(SIApplication *)application;
- (void)removeApplication:(SIApplication *)application;
- (void)activateApplication:(SIApplication *)application;
- (void)deactivateApplication:(SIApplication *)application;

- (void)addWindow:(SIWindow *)window;
- (void)removeWindow:(SIWindow *)window;

@end

@implementation AMWindowManager

- (id)init {
    self = [super init];
    if (self) {
        self.applications = [NSMutableArray array];
        self.windows = [NSMutableArray array];

        for (NSRunningApplication *runningApplication in NSWorkspace.sharedWorkspace.runningApplications) {
            if (!runningApplication.isManageable) continue;

            SIApplication *application = [SIApplication applicationWithRunningApplication:runningApplication];
            [self addApplication:application];
        }

        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                               selector:@checkselector(self, applicationDidLaunch:)
                                                                   name:NSWorkspaceDidLaunchApplicationNotification
                                                                 object:nil];
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                               selector:@checkselector(self, applicationDidTerminate:)
                                                                   name:NSWorkspaceDidTerminateApplicationNotification
                                                                 object:nil];
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                               selector:@checkselector(self, applicationDidHide:)
                                                                   name:NSWorkspaceDidHideApplicationNotification
                                                                 object:nil];
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                               selector:@checkselector(self, applicationDidUnhide:)
                                                                   name:NSWorkspaceDidUnhideApplicationNotification
                                                                 object:nil];
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                               selector:@checkselector(self, activeSpaceDidChange:)
                                                                   name:NSWorkspaceActiveSpaceDidChangeNotification
                                                                 object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@checkselector(self, screenParametersDidChange:)
                                                     name:NSApplicationDidChangeScreenParametersNotification
                                                   object:nil];

    }
    return self;
}

- (void)dealloc {
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark Notification Handlers

- (void)applicationDidLaunch:(NSNotification *)notification {
    NSRunningApplication *launchedApplication = notification.userInfo[NSWorkspaceApplicationKey];
    SIApplication *application = [SIApplication applicationWithRunningApplication:launchedApplication];
    [self addApplication:application];
}

- (void)applicationDidTerminate:(NSNotification *)notification {
    NSRunningApplication *terminatedApplication = notification.userInfo[NSWorkspaceApplicationKey];
    SIApplication *application = [self applicationWithProcessIdentifier:[terminatedApplication processIdentifier]];
    [self removeApplication:application];
}

- (void)applicationDidHide:(NSNotification *)notification {
    NSRunningApplication *hiddenApplication = notification.userInfo[NSWorkspaceApplicationKey];
    SIApplication *application = [self applicationWithProcessIdentifier:[hiddenApplication processIdentifier]];
    [self deactivateApplication:application];
}

- (void)applicationDidUnhide:(NSNotification *)notification {
    NSRunningApplication *unhiddenApplication = notification.userInfo[NSWorkspaceApplicationKey];
    SIApplication *application = [self applicationWithProcessIdentifier:[unhiddenApplication processIdentifier]];
    [self activateApplication:application];
}

- (void)activeSpaceDidChange:(NSNotification *)notification {
    for (NSRunningApplication *runningApplication in [[NSWorkspace sharedWorkspace] runningApplications]) {
        if (!runningApplication.isManageable) continue;

        pid_t processIdentifier = runningApplication.processIdentifier;
        SIApplication *application = [self applicationWithProcessIdentifier:processIdentifier];
        if (application) {
            [application dropWindowsCache];

            for (SIWindow *window in application.windows) {
                [self addWindow:window];
            }
        }
    }
}

- (void)screenParametersDidChange:(NSNotification *)notification {
//    [self updateScreenManagers];
}

#pragma mark Applications Management

- (SIApplication *)applicationWithProcessIdentifier:(pid_t)processIdentifier {
    for (SIApplication *application in self.applications) {
        if (application.processIdentifier == processIdentifier) {
            return application;
        }
    }

    return nil;
}

- (void)addApplication:(SIApplication *)application {
    if ([self.applications containsObject:application]) return;

    [self.applications addObject:application];

    for (SIWindow *window in application.windows) {
        [self addWindow:window];
    }

//    BOOL floating = application.floating;

    [application observeNotification:kAXWindowCreatedNotification
                         withElement:application
                            handler:^(SIAccessibilityElement *accessibilityElement) {
                                [[NSUserDefaults standardUserDefaults] addSuiteNamed:@"com.apple.spaces"];
                                SIWindow *window = (SIWindow *)accessibilityElement;
//                                window.floating = floating;
                                [self addWindow:window];
                            }];
    [application observeNotification:kAXFocusedWindowChangedNotification
                         withElement:application
                             handler:^(SIAccessibilityElement *accessibilityElement) {
                                 SIWindow *focusedWindow = [SIWindow focusedWindow];
//                                 [self markScreenForReflow:focusedWindow.screen];
                               
                                 [self updateOverlayForWindow:focusedWindow];

                             }];
    [application observeNotification:kAXApplicationActivatedNotification
                         withElement:application
                             handler:^(SIAccessibilityElement *accessibilityElement) {
																 NSLog(@"application activated: %@", application);
                                 [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                                          selector:@checkselector(self, applicationActivated:)
                                                                            object:nil];
                                 [self performSelector:@checkselector(self, applicationActivated:) withObject:nil afterDelay:0.1];
															 
                               id focusedWindow = SIWindow.focusedWindow;
                               [self updateOverlayForWindow:focusedWindow];
                             }];
}

- (void)applicationActivated:(id)sender {
    SIWindow *focusedWindow = [SIWindow focusedWindow];
    if (!focusedWindow.isFullScreen) {
//        [self markScreenForReflow:focusedWindow.screen];
    }
}

- (void)removeApplication:(SIApplication *)application {
    for (SIWindow *window in application.windows) {
        [self removeWindow:window];
    }
    [self.applications removeObject:application];
}

- (void)activateApplication:(SIApplication *)application {
    pid_t processIdentifier = application.processIdentifier;
    for (SIWindow *window in [self.windows copy]) {
        if (window.processIdentifier == processIdentifier) {
//            [self markScreenForReflow:window.screen];
        }
    }
}

- (void)deactivateApplication:(SIApplication *)application {
    pid_t processIdentifier = application.processIdentifier;
    for (SIWindow *window in [self.windows copy]) {
        if (window.processIdentifier == processIdentifier) {
//            [self markScreenForReflow:window.screen];
        }
    }
}

#pragma mark Windows Management

- (void)addWindow:(SIWindow *)window {
    if ([self.windows containsObject:window]) return;

    if (!window.shouldBeManaged) return;

    [self.windows addObject:window];
//    [self markScreenForReflow:window.screen];

    SIApplication *application = [self applicationWithProcessIdentifier:window.processIdentifier];

//    window.floating = application.floating;
//    if (window.frame.size.width < 500 && window.frame.size.height < 500) {
//        window.floating = YES;
//    }

		// AP default floating to true, so we can use a button to opt-in window management.
		window.floating = YES;
	
    if ( ! window.overlay )
      [self setupOverlayForWindow:window];
  
    [application observeNotification:kAXUIElementDestroyedNotification
                         withElement:window
                            handler:^(SIAccessibilityElement *accessibilityElement) {
                                [self removeWindow:window];
                            }];
    [application observeNotification:kAXWindowMiniaturizedNotification
                         withElement:window
                            handler:^(SIAccessibilityElement *accessibilityElement) {
//                                [self markScreenForReflow:window.screen];
                            }];
    [application observeNotification:kAXWindowDeminiaturizedNotification
                         withElement:window
                            handler:^(SIAccessibilityElement *accessibilityElement) {
//                                [self markScreenForReflow:window.screen];
                            }];
    [application observeNotification:kAXWindowMovedNotification
                         withElement:window
                             handler:^(SIAccessibilityElement *accessibilityElement) {
                               
                               [self saveSizeForWindow:window forState:1];
                               
                               if ([window isEqual:[SIWindow focusedWindow]]) {
                                 [window updateOverlay];
                               }
                             }];
  [application observeNotification:kAXWindowResizedNotification
                       withElement:window
                           handler:^(SIAccessibilityElement *accessibilityElement) {
                             [self saveSizeForWindow:window forState:1];
                             
                             if ([window isEqual:[SIWindow focusedWindow]]) {
                               [window updateOverlay];
                             }
                           }];

}

- (void)removeWindow:(SIWindow *)window {
//    [self markAllScreensForReflow];

    SIApplication *application = [self applicationWithProcessIdentifier:window.processIdentifier];
    [application unobserveNotification:kAXUIElementDestroyedNotification withElement:window];
    [application unobserveNotification:kAXWindowMiniaturizedNotification withElement:window];
    [application unobserveNotification:kAXWindowDeminiaturizedNotification withElement:window];

    [self.windows removeObject:window];
}

- (NSArray *)windowsForScreen:(NSScreen *)screen {
    return [self.windows filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        SIWindow *window = (SIWindow *)evaluatedObject;
        return [window.screen isEqual:screen] && window.isActive;
    }]];
}

- (NSArray *)activeWindowsForScreen:(NSScreen *)screen {
    return [self.windows filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        SIWindow *window = (SIWindow *)evaluatedObject;
        return [window.screen isEqual:screen] && window.isActive && window.shouldBeManaged && !window.floating;
    }]];
}

- (void)toggleFloatForFocusedWindow {
    SIWindow *focusedWindow = [SIWindow focusedWindow];

    for (SIWindow *window in self.windows) {
        if ([window isEqual:focusedWindow]) {
            window.floating = !window.floating;
//            [self markScreenForReflow:window.screen];
            return;
        }
    }

    [self addWindow:focusedWindow];
    focusedWindow.floating = NO;
//    [self markScreenForReflow:focusedWindow.screen];
}

#pragma mark - 

-(void) setupOverlayForWindow:(SIWindow*)window {
  NSViewController* vc = [[NSViewController alloc] initWithNibName:@"TrackingWindowView" bundle:nil];

  NSButton* button = [vc.view viewWithTag:101];
  button.target = self;
  button.action = @selector(toggleFloat:);

  [window setupOverlayWithViewController:vc];
}

-(void) updateOverlayForWindow:(SIWindow*)window {
  if ( ! window.overlay )
    [self setupOverlayForWindow:window];
  
  [window updateOverlay];
}

-(IBAction)toggleFloat:(id)sender {
  //	TODO assert focused window is my window.
	[self toggleFloatForFocusedWindow];
}


-(void) saveSizeForWindow:(SIWindow*)window forState:(NSUInteger)state {
  
  if ( ! [window isEqual:[SIWindow focusedWindow]]) return;
  
  if (window.floating) return;

  NSNumber* windowId = window.windowId;
  // let's just try 1 more time.
  if ( ! windowId) windowId = window.windowId;
  
  if (windowId) {
    CGRect frame = [window frame];
    if ( ! CGRectEqualToRect(frame, [window unzoomedFrame])) {
      // frame is altered from unzoomed state: save.
      [window saveZoomedFrame:frame];
      
      NSLog(@"saved frame for window %@", windowId);
    }
  }
  else {
    NSLog(@"WOOPS nil windowId for %@", window);
  }
}

@end
