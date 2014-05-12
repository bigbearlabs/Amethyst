// IMPL remove tracking window when window closed or hidden.
// FIXME on screen change, need to hide tracking windows for non-focused windows.
// IMPL hide tracking window when window being moved.
// -- later
// IMPL display float status in control.
// IMPL make window transparent.
// IMPL restore original window size when float off.
// IMPL persist window info hash.


#import "BBLTrackingWindow.h"
#import "SIWindow.h"

@implementation BBLTrackingWindow
{
	NSViewController* vc;
}

-(BBLTrackingWindow*) initWithWindow:(SIWindow*)window viewController:(NSViewController*)viewController {
	
	self = [super initWithContentRect:NSZeroRect
														styleMask:NSBorderlessWindowMask|NSNonactivatingPanelMask
															backing:NSBackingStoreBuffered
																defer:YES];
	
	if (self) {
    [self setHasShadow:NO];
		
		vc = viewController;
    [self.contentView addSubview:vc.view];
    
		[self setLevel:NSFloatingWindowLevel];
		
		[self updateForWindow:window];
		
    if ([[SIWindow focusedWindow] isEqual:window])
      [self show];
    else
      [self hide];
	}
  
	return self;
}

-(void) updateForWindow:(SIWindow*)window {
	NSView* view = [self.contentView subviews][0];
	CGFloat w = view.frame.size.width;
	CGFloat h = view.frame.size.height;
	
	CGFloat offset = 70;
	CGFloat x = window.frame.origin.x + offset;

	// siwindow has top-left coordindate system, so convert to bottom-left.
	CGFloat y = window.screen.frame.size.height + window.screen.frame.origin.y - window.frame.origin.y - h;
	
  NSRect frame = NSMakeRect(x, y, w, h);

	[self setFrame:frame display:YES];
	
  // set the view frame.
	view.frame = NSMakeRect(0, 0, w, h);
	
  // TODO update button state.
}

-(void) show {
	[self orderFrontRegardless];
}

-(void) hide {
	[self orderOut:self];
}

@end
