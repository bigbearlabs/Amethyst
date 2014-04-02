// IMPL remove tracking window when window closed or hidden.
// FIXME on screen change, need to hide tracking windows for non-focused windows.
// IMPL hide tracking window when window being moved.
// -- later
// IMPL display float status in control.
// IMPL make window transparent.
// IMPL restore original window size when float off.
// IMPL persist window info hash.


#import "BBLTrackingWindow.h"
#import "AMWindowManager.h"

@implementation BBLTrackingWindow
{
	NSViewController* vc;
}

-(BBLTrackingWindow*) initWithWindow:(SIWindow*)window windowManager:(AMWindowManager*)windowManager {
	
	self = [super initWithContentRect:NSZeroRect
														styleMask:NSBorderlessWindowMask|NSNonactivatingPanelMask
															backing:NSBackingStoreBuffered
																defer:YES];
	
	if (self) {
    [self setHasShadow:NO];
    
		self.originalWindow = window;
		
//				show simple poc view.
		
		vc = [[NSViewController alloc] initWithNibName:@"TrackingWindowView" bundle:nil];
		[self.contentView addSubview:vc.view];


		NSButton* button = [vc.view viewWithTag:101];
		button.target = windowManager;
		button.action = @selector(toggleFloat:);
			
		
		[self setLevel:NSFloatingWindowLevel];
		
		[self updateFrame:window];
		

//		show
		[self orderFrontRegardless];
	}
	return self;
}

-(void) updateFrame:(SIWindow*)window {
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
	
}

-(void) show {
	[self orderFrontRegardless];
}

-(void) hide {
	[self orderOut:self];
}

@end


@implementation AMWindowManager (BBL_additions)

-(IBAction)toggleFloat:(id)sender {
//	TODO assert focused window is my window.
	[self toggleFloatForFocusedWindow];
}

@end