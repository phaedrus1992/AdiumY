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
- (void)_handleKeyEvent:(NSEvent *)event;
@end

@implementation AIHotKeyCenter

+ (AIHotKeyCenter *)sharedCenter
{
	static AIHotKeyCenter *sharedCenter = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedCenter = [[self alloc] init];
	});

	return sharedCenter;
}

- (instancetype)init
{
	if ((self = [super init])) {
		_hotKeys = [[NSMutableArray alloc] init];
	}
	return self;
}

#pragma mark - Registration

- (BOOL)registerHotKey:(AIHotKey *)theHotKey
{
	for (AIHotKey *existing in _hotKeys) {
		if ([existing.identifier isEqualToString:theHotKey.identifier]) {
			return NO;
		}
	}

	[_hotKeys addObject:theHotKey];
	[self _updateMonitor];
	return YES;
}

- (void)unregisterHotKey:(AIHotKey *)theHotKey
{
	[_hotKeys removeObject:theHotKey];
	[self _updateMonitor];
}

- (NSArray *)allHotKeys
{
	return [_hotKeys copy];
}

- (AIHotKey *)hotKeyWithIdentifier:(NSString *)theIdentifier
{
	for (AIHotKey *hotKey in _hotKeys) {
		if ([hotKey.identifier isEqualToString:theIdentifier]) {
			return hotKey;
		}
	}
	return nil;
}

#pragma mark - Monitor

- (void)_updateMonitor
{
	if (_globalMonitor) {
		[NSEvent removeMonitor:_globalMonitor];
		_globalMonitor = nil;
	}

	if ([_hotKeys count] > 0) {
		_globalMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskKeyDown
															   handler:^(NSEvent *event) {
																   [self _handleKeyEvent:event];
															   }];
	}
}

- (void)_handleKeyEvent:(NSEvent *)event
{
	NSArray *snapshot = [self allHotKeys];
	for (AIHotKey *hotKey in snapshot) {
		if ([hotKey isValidCombo] && [self _hotKey:hotKey matchesEvent:event]) {
			[self _invokeHotKey:hotKey];
			return;
		}
	}
}

#pragma mark - Matching & invocation

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
		#pragma clang diagnostic push

		#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

		[target performSelector:action withObject:hotKey];
		#pragma clang diagnostic pop

	}
}

@end
