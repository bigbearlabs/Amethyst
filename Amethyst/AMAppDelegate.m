//
//  AMAppDelegate.m
//  Amethyst
//
//  Created by Ian on 5/14/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMAppDelegate.h"

#import "AMConfiguration.h"
#import "AMHotKeyManager.h"
#import "AMWindowManager.h"

#import <CocoaLumberjack/DDASLLogger.h>
#import <CocoaLumberjack/DDTTYLogger.h>
#import <CoreServices/CoreServices.h>
#import <IYLoginItem/NSBundle+LoginItem.h>

@interface AMAppDelegate ()
@property (nonatomic, strong) AMWindowManager *windowManager;
@property (nonatomic, strong) AMHotKeyManager *hotKeyManager;

@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) IBOutlet NSMenu *statusItemMenu;
@property (nonatomic, strong) IBOutlet NSMenuItem *startAtLoginMenuItem;

- (IBAction)toggleStartAtLogin:(id)sender;
- (IBAction)relaunch:(id)sender;
@end

@interface NSArray (functional)
-(NSArray*) map:(id(^)(id))mapperBlock;
@end

@implementation NSArray (functional)

-(NSArray*) map:(id(^)(id elem))mapperBlock {
  NSMutableArray* mapped = [NSMutableArray array];  // TODO optimise with array size
  for (id element in self) {
    id result = mapperBlock(element);
    [mapped addObject:result];
  }
  return mapped;
}
@end


@implementation AMAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [DDLog addLogger:DDASLLogger.sharedInstance];
    [DDLog addLogger:DDTTYLogger.sharedInstance];

    [AMConfiguration.sharedConfiguration loadConfiguration];

    RAC(self, statusItem.image) = [RACObserve(AMConfiguration.sharedConfiguration, tilingEnabled) map:^id(NSNumber *tilingEnabled) {
        if (tilingEnabled.boolValue) {
            return [NSImage imageNamed:@"icon-statusitem"];
        }
        return [NSImage imageNamed:@"icon-statusitem-disabled"];
    }];

    self.windowManager = [[AMWindowManager alloc] init];
    self.hotKeyManager = [[AMHotKeyManager alloc] init];

    [AMConfiguration.sharedConfiguration setUpWithHotKeyManager:self.hotKeyManager windowManager:self.windowManager];
}

- (void)awakeFromNib {
    [super awakeFromNib];

    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.image = [NSImage imageNamed:@"icon-statusitem"];
    self.statusItem.menu = self.statusItemMenu;
    self.statusItem.highlightMode = YES;

    self.startAtLoginMenuItem.state = (NSBundle.mainBundle.isLoginItem ? NSOnState : NSOffState);
}

- (IBAction)toggleStartAtLogin:(id)sender {
    if (self.startAtLoginMenuItem.state == NSOffState) {
        [NSBundle.mainBundle addToLoginItems];
    } else {
        [NSBundle.mainBundle removeFromLoginItems];
    }
    self.startAtLoginMenuItem.state = (NSBundle.mainBundle.isLoginItem ? NSOnState : NSOffState);
}

- (IBAction)relaunch:(id)sender {
    NSString *myPath = [NSString stringWithFormat:@"%s", [[[NSBundle mainBundle] executablePath] fileSystemRepresentation]];
    [NSTask launchedTaskWithLaunchPath:myPath arguments:@[]];
    [NSApp terminate:self];
}

#pragma windows menu

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
  NSLog(@"menu activated");
  if (menuItem.menu == self.statusItemMenu) {
    [self buildWindowsMenu];
  }
  
  return YES;
}

// TODO instantiate / populate lazily.
-(void) buildWindowsMenu {
  
  //  [[NSClassFromString(@"RubyMotionAdapter") instance] update_menu:[self windowsForScreen:[NSScreen mainScreen]]];
  
  NSArray* windows = [self.windowManager windowsForScreen:NSScreen.mainScreen];
  id menuItems = [windows map:^id(SIWindow* window) {
    id title = [NSString stringWithFormat:@"%@ (%@)", window.title, window.app.title, nil];
    SEL sel = @selector(menuItemSelected:);
    id key = @"";
    NSMenuItem* menuItem = [[NSMenuItem alloc] initWithTitle:title action:sel keyEquivalent:key];
    menuItem.target = self;
    menuItem.representedObject = window;
    menuItem.state = window.floating ? NSOffState : NSOnState;  // TODO replace with binding.
    return menuItem;
  }];
  
  NSMenu* menu = [[NSMenu alloc] initWithTitle:@"Windows"];
  for (NSMenuItem* item in menuItems) {
    [menu addItem:item];
  }
  
  [[self.statusItemMenu itemWithTag:701] setSubmenu:menu];
}

-(IBAction)menuItemSelected:(NSMenuItem*)sender {
  SIWindow* window = sender.representedObject;
  window.floating = ! window.floating;
  
  [self.windowManager markAllScreensForReflow];
}

@end
