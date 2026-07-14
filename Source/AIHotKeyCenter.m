//
//  AIHotKeyCenter.m
//  Adium
//
//  Modern replacement for SGHotKeyCenter.
//  Uses NSEvent global monitors instead of Carbon RegisterEventHotKey.
//

#import "AIHotKeyCenter.h"
#import "AIHotKey.h"

@interface AIHotKeyCenter () {
	NSMutableArray *_hotKeys;
	id _globalMonitor;
}
- (void)_updateMonitor;
- (BOOL)_hotKey:(AIHotKey *)hotKey matchesEvent:(NSEvent *)event;
@end

@implementation AIHotKeyCenter

+ (AIHotKeyCenter *)sharedCenter
{
	static AIHotKeyCenter *sharedCenter = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedCenter = _globalMonitor = nil;
	}

	// Only create a monitor if we have registered hotkeys
	if (
	for (AIHotKey *hotKey in snapshot) {
		if ([hotKey isValidCombo] && [self _hotKey:hotKey matchesEvent:event]) {
			[self _invokeHotKey:hotKey];
			return;
		}
	}
}

- (BOOL)_hotKey:(AIHotKey *)hotKey matchesEvent:(NSEvent *)event
{
	// Compare key code
	if (hotKey.keyCode != [event keyCode]) {
		return NO;
	}

	// Compare modifier flags (only the relevant modifier bits)
	NSUInteger eventModifiers = [event modifierFlags] & (NSEventModifierFlagDeviceIndependentFlagsMask);
	NSUInteger hotKeyModifiers = hotKey.modifierFlags & (NSEventModifierFlagDeviceIndependentFlagsMask);

	return eventModifiers == hotKeyModifiers;
}

- (void)_invokeHotKey:(AIHotKey *)hotKey
{
	id target = hotKey.target;
	SEL action = hotKey.action;

	if (target && action && [target respondsToSelector:action]) {
		[target performSelector:action withObject:hotKey];
	}
}

@end