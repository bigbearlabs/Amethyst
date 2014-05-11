//
//  AMWidescreenTallLayout.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 4/6/14.
//  Copyright (c) 2014 Ian Ynda-Hummel. All rights reserved.
//

#import "AMWidescreenTallLayout.h"

#import "SIWindow+Amethyst.h"
#import "NSObject+AssociatedDictionary.h"

@interface AMWidescreenTallLayout ()
// Ratio of screen width taken up by main pane
@property (nonatomic, assign) CGFloat mainPaneRatio;
// The number of windows that should be displayed in the main pane.
@property (nonatomic, assign) NSInteger mainPaneCount;
@end

@implementation AMWidescreenTallLayout

- (id)init {
    self = [super init];
    if (self) {
        self.mainPaneCount = 1;
        self.mainPaneRatio = 0.5;
    }
    return self;
}

#pragma mark AMLayout

+ (NSString *)layoutName {
    return @"Widescreen Tall";
}

- (void)reflowScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    if (windows.count == 0) return;
  
    NSUInteger mainPaneCount = MIN(windows.count, self.mainPaneCount);

    NSInteger secondaryPaneCount = windows.count - mainPaneCount;
    BOOL hasSecondaryPane = (secondaryPaneCount > 0);

    CGRect screenFrame = [self adjustedFrameForLayout:screen];

    CGFloat mainPaneWindowHeight = screenFrame.size.height;
    CGFloat secondaryPaneWindowHeight = (hasSecondaryPane ? round(screenFrame.size.height / secondaryPaneCount) : 0.0);

    CGFloat margin = 30.0;  // horizontal margin to act as 'gutter'
    CGFloat marginAppliedWidth = screenFrame.size.width - margin;

    CGFloat mainPaneWindowWidth = round((marginAppliedWidth * (hasSecondaryPane ? self.mainPaneRatio : 1)) / mainPaneCount);
    CGFloat secondaryPaneWindowWidth = marginAppliedWidth - mainPaneWindowWidth * mainPaneCount;

    SIWindow *focusedWindow = [SIWindow focusedWindow];

    for (NSUInteger windowIndex = 0; windowIndex < windows.count; ++windowIndex) {
        SIWindow *window = windows[windowIndex];

        CGRect windowFrame;

        // - if zoom on, resize to zoomed frame.
        if ([window isEqual:focusedWindow] && [window isZoomed]) {
          windowFrame = [window zoomedFrame];
        } else {
          if (windowIndex < mainPaneCount) {
              windowFrame.origin.x = screenFrame.origin.x + mainPaneWindowWidth * windowIndex;
              windowFrame.origin.y = screenFrame.origin.y;
              windowFrame.size.width = mainPaneWindowWidth;
              windowFrame.size.height = mainPaneWindowHeight;
          } else {
              windowFrame.origin.x = screenFrame.origin.x + mainPaneWindowWidth * mainPaneCount;
              windowFrame.origin.y = screenFrame.origin.y + (secondaryPaneWindowHeight * (windowIndex - mainPaneCount));
              windowFrame.size.width = secondaryPaneWindowWidth;
              windowFrame.size.height = secondaryPaneWindowHeight;
          }
          
          // save unzoomed frame for later reference.
          [window saveUnzoomedFrame:windowFrame];
        }
      
        // - if focused window is e.g. popup, don't resize / reflow anything.
        if ([focusedWindow isNormalWindow]) {
          [self assignFrame:windowFrame toWindow:window focused:[window isEqualTo:focusedWindow] screenFrame:screenFrame];
        }
    }
}

- (void)expandMainPane {
    self.mainPaneRatio = MIN(1, self.mainPaneRatio + 0.05);
}

- (void)shrinkMainPane {
    self.mainPaneRatio = MAX(0, self.mainPaneRatio - 0.05);
}

- (void)increaseMainPaneCount {
    self.mainPaneCount = self.mainPaneCount + 1;
}

- (void)decreaseMainPaneCount {
    self.mainPaneCount = MAX(1, self.mainPaneCount - 1);
}

@end
