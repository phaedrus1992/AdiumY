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
	if ((self = 
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