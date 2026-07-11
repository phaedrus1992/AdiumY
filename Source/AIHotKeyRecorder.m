//
//  AIHotKeyRecorder.m
//  Adium
//
//  Minimal replacement for SRRecorderControl.
//

#import "AIHotKeyRecorder.h"
#import "AIHotKey.h"

@interface AIHotKeyRecorder () {
	BOOL _recording;
	NSTrackingArea *_trackingArea;
	id _localMonitor;
}

- (void)_startRecording;
- (void)_stopRecording;
- (void)_updateDisplay;
- (void)_clearHotKey:(id)sender;

@end

@implementation AIHotKeyRecorder

@synthesize delegate;
@synthesize hotKey = _hotKey;

- (id)initWithFrame:(NSRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		_recording = NO;
		[self setTarget:self];
		[self setAction:@selector(_startRecording)];
	}
	return self;
}

- (void)dealloc
{
	if (_localMonitor) {
		[NSEvent removeMonitor:_localMonitor];
		[_localMonitor release];
	}
	[_trackingArea release];
	[_hotKey release];
	[super dealloc];
}

- (void)setHotKey:(AIHotKey *)hotKey
{
	if (_hotKey != hotKey) {
		[_hotKey release];
		_hotKey = [hotKey retain];
	}
	[self _stopRecording];
	[self _updateDisplay];
}

- (AIHotKey *)hotKey
{
	return _hotKey;
}

- (NSString *)keyComboString
{
	return [_hotKey shortcutDisplayString];
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect
{
	NSRect bounds = [self bounds];

	// Draw rounded rect background
	NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:4.0 yRadius:4.0];

	if (_recording) {
		// Highlighted background when recording
		[[NSColor keyboardFocusIndicatorColor] setFill];
	} else {
		NSColor *bgColor = [NSColor colorWithCalibratedWhite:0.95 alpha:1.0];
		[bgColor setFill];
	}
	[path fill];

	// Draw border
	if (_recording) {
		[[NSColor keyboardFocusIndicatorColor] setStroke];
	} else {
		[[NSColor colorWithCalibratedWhite:0.7 alpha:1.0] setStroke];
	}
	[path setLineWidth:1.0];
	[path stroke];

	// Draw text
	NSString *displayString;
	NSColor *textColor;

	if (_recording) {
		displayString = NSLocalizedString(@"Type shortcut…", @"Hot key recorder: prompt when recording");
		textColor = [NSColor grayColor];
	} else if (self.hotKey && [self.hotKey isValidCombo]) {
		displayString = [self keyComboString];
		textColor = [NSColor blackColor];
	} else {
		displayString = NSLocalizedString(@"(None)", @"Hot Keys: Key Combo text for 'empty' combo");
		textColor = [NSColor grayColor];
	}

	NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:textColor, NSForegroundColorAttributeName,
																	 [NSFont systemFontOfSize:[NSFont systemFontSize]],
																	 NSFontAttributeName, nil];

	NSSize stringSize = [displayString sizeWithAttributes:attrs];
	NSPoint drawPoint = NSMakePoint(NSMidX(bounds) - stringSize.width / 2.0, NSMidY(bounds) - stringSize.height / 2.0);
	[displayString drawAtPoint:drawPoint withAttributes:attrs];

	// Draw clear button when we have a valid combo
	if (self.hotKey && [self.hotKey isValidCombo] && !_recording) {
		NSString *clearText = @"✕";
		NSDictionary *clearAttrs =
			[NSDictionary dictionaryWithObjectsAndKeys:[NSColor grayColor], NSForegroundColorAttributeName,
													   [NSFont systemFontOfSize:10.0], NSFontAttributeName, nil];
		NSSize clearSize = [clearText sizeWithAttributes:clearAttrs];
		NSPoint clearPoint =
			NSMakePoint(NSMaxX(bounds) - clearSize.width - 4.0, NSMidY(bounds) - clearSize.height / 2.0);
		[clearText drawAtPoint:clearPoint withAttributes:clearAttrs];
	}
}

- (void)updateTrackingAreas
{
	[super updateTrackingAreas];
	if (_trackingArea) {
		[self removeTrackingArea:_trackingArea];
		[_trackingArea release];
	}

	_trackingArea = [[NSTrackingArea alloc] initWithRect:[self bounds]
												 options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInActiveApp
												   owner:self
												userInfo:nil];
	[self addTrackingArea:_trackingArea];
}

#pragma mark - Mouse tracking

- (void)mouseEntered:(NSEvent *)event
{
	[[NSCursor pointingHandCursor] set];
}

- (void)mouseExited:(NSEvent *)event
{
	[[NSCursor arrowCursor] set];
}

- (NSView *)hitTest:(NSPoint)aPoint
{
	// Check if click is on the "clear" area (right side)
	// aPoint is already in self's coordinate system when hitTest: is called.
	if (self.hotKey && [self.hotKey isValidCombo] && !_recording) {
		NSPoint localPoint = aPoint;
		NSRect bounds = [self bounds];
		NSRect clearRect = NSMakeRect(NSMaxX(bounds) - 22.0, NSMinY(bounds), 22.0, NSHeight(bounds));
		if (NSPointInRect(localPoint, clearRect)) {
			[self _clearHotKey:nil];
			return nil; // Don't start recording
		}
	}
	return self;
}

#pragma mark - Recording

- (void)_startRecording
{
	if (_recording)
		return;

	_recording = YES;
	[self.window makeFirstResponder:self];

	// Show prompt statically while recording
	// Local monitor to capture key combo
	AIHotKeyRecorder *__unsafe_unretained weakSelf = self;
	_localMonitor = [[NSEvent
		addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
									 handler:^NSEvent *(NSEvent *event) {
										 AIHotKeyRecorder *strongSelf = weakSelf;
										 if (!strongSelf)
											 return event;

										 // Escape cancels recording
										 if ([event keyCode] == 53) {
											 [strongSelf _stopRecording];
											 return nil;
										 }

										 // Require at least one modifier key for valid shortcut
										 NSUInteger modifiers =
											 [event modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask;
										 BOOL hasModifier = (modifiers & (NSCommandKeyMask | NSAlternateKeyMask |
																		  NSControlKeyMask | NSShiftKeyMask)) != 0;

										 if (!hasModifier) {
											 NSBeep();
											 return nil;
										 }

										 // Check delegate permission
										 BOOL shouldCapture = YES;
										 if ([strongSelf->delegate
												 respondsToSelector:
													 @selector(hotKeyRecorder:shouldCaptureKeyCode:modifierFlags:)]) {
											 shouldCapture = [strongSelf->delegate hotKeyRecorder:strongSelf
																			 shouldCaptureKeyCode:[event keyCode]
																					modifierFlags:modifiers];
										 }

										 if (shouldCapture) {
											 AIHotKey *newHotKey = [[AIHotKey alloc] initWithIdentifier:nil
																								keyCode:[event keyCode]
																						  modifierFlags:modifiers];

											 if (strongSelf->_hotKey) {
												 newHotKey.identifier =
													 [[strongSelf->_hotKey.identifier copy] autorelease];
												 newHotKey.target = strongSelf->_hotKey.target;
												 newHotKey.action = strongSelf->_hotKey.action;
											 }

											 [strongSelf setHotKey:newHotKey];
											 [newHotKey release];

											 // Notify delegate
											 if ([strongSelf->delegate
													 respondsToSelector:@selector(hotKeyRecorder:keyComboDidChange:)]) {
												 [strongSelf->delegate hotKeyRecorder:strongSelf
																	keyComboDidChange:strongSelf->_hotKey];
											 }
										 }

										 [strongSelf _stopRecording];
										 return nil;
									 }] retain];

	if (!_localMonitor) {
		AILogWithSignature(@"Failed to create local event monitor — key capture disabled.");
		[self _stopRecording];
	}

	[self _updateDisplay];
}

- (void)_stopRecording
{
	_recording = NO;

	if (_localMonitor) {
		[NSEvent removeMonitor:_localMonitor];
		[_localMonitor release];
		_localMonitor = nil;
	}

	[self _updateDisplay];
}

#pragma mark - Actions

- (void)_clearHotKey:(id)sender
{
	AIHotKey *clearHotKey = [[AIHotKey alloc] initWithIdentifier:_hotKey.identifier keyCode:0 modifierFlags:0];
	clearHotKey.target = _hotKey.target;
	clearHotKey.action = _hotKey.action;
	[self setHotKey:clearHotKey];
	[clearHotKey release];

	if ([delegate respondsToSelector:@selector(hotKeyRecorder:keyComboDidChange:)]) {
		[delegate hotKeyRecorder:self keyComboDidChange:self.hotKey];
	}
}

#pragma mark - Display

- (void)_updateDisplay
{
	[self setNeedsDisplay:YES];
}

#pragma mark - First responder

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (BOOL)resignFirstResponder
{
	if (_recording) {
		[self _stopRecording];
	}
	return YES;
}

@end