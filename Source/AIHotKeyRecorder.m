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
	}
	return self;
}

- (void)dealloc
{
	[self _stopRecording];
}

#pragma mark - Display

- (void)_updateDisplay
{
	[self setNeedsDisplay:YES];
}

- (NSString *)keyComboString
{
	return [self.hotKey shortcutDisplayString];
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

#pragma mark - Recording

- (void)_startRecording
{
	_recording = YES;
	[self _updateDisplay];

	__unsafe_unretained AIHotKeyRecorder *weakSelf = self;
	_localMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
														 handler:^NSEvent *(NSEvent *event) {
															 AIHotKeyRecorder *strongSelf = weakSelf;
															 if (!strongSelf) return event;

															 id del = strongSelf.delegate;
															 if ([del respondsToSelector:@selector(hotKeyRecorder:shouldCaptureKeyCode:modifierFlags:)]) {
																 if (![del hotKeyRecorder:strongSelf
																	 shouldCaptureKeyCode:event.keyCode
																			modifierFlags:event.modifierFlags]) {
																	 return event;
																 }
															 }

															 AIHotKey *newHotKey = [[AIHotKey alloc] initWithIdentifier:nil
																												  keyCode:event.keyCode
																											modifierFlags:event.modifierFlags
																												   target:nil
																												   action:nil];
															 strongSelf.hotKey = newHotKey;

															 [strongSelf _stopRecording];

															 if ([del respondsToSelector:@selector(hotKeyRecorder:keyComboDidChange:)]) {
																 [del hotKeyRecorder:strongSelf keyComboDidChange:newHotKey];
															 }

															 return nil; // consume the event
														 }];
}

- (void)_stopRecording
{
	if (_localMonitor) {
		[NSEvent removeMonitor:_localMonitor];
		_localMonitor = nil;
	}
	_recording = NO;
	[self _updateDisplay];
}

- (void)_clearHotKey:(id)sender
{
	self.hotKey = [[AIHotKey alloc] initWithIdentifier:nil keyCode:0 modifierFlags:0];
	[self _updateDisplay];

	if ([delegate respondsToSelector:@selector(hotKeyRecorder:keyComboDidChange:)]) {
		[delegate hotKeyRecorder:self keyComboDidChange:self.hotKey];
	}
}

@end
