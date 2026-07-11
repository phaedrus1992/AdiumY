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
		sharedCenter = [[self alloc] init];
	});
	return sharedCenter;
}

- (id)init
{
	if ((self = [super init])) {
		_hotKeys = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)dealloc
{
	if (_globalMonitor) {
		[NSEvent removeMonitor:_globalMonitor];
		[_globalMonitor release];
	}
	[_hotKeys release];
	[super dealloc];
}

- (BOOL)registerHotKey:(AIHotKey *)theHotKey
{
	if (!theHotKey || ![theHotKey isValidCombo]) {
		return YES; // Not an error; just ignore invalid combos
	}

	// Remove existing registration with same identifier
	AIHotKey *existing = [self hotKeyWithIdentifier:theHotKey.identifier];
	if (existing) {
		[self unregisterHotKey:existing];
	}

	[_hotKeys addObject:theHotKey];
	[self _updateMonitor];

	return YES;
}

- (void)unregisterHotKey:(AIHotKey *)theHotKey
{
	if (!theHotKey)
		return;

	[_hotKeys removeObject:theHotKey];
	[self _updateMonitor];
}

- (NSArray *)allHotKeys
{
	return [[_hotKeys copy] autorelease];
}

- (AIHotKey *)hotKeyWithIdentifier:(NSString *)theIdentifier
{
	if (!theIdentifier)
		return nil;

	for (AIHotKey *hotKey in _hotKeys) {
		if ([[hotKey identifier] isEqualToString:theIdentifier]) {
			return hotKey;
		}
	}
	return nil;
}

#pragma mark - Monitor management

// The global monitor only fires when the app is not active.
// A local monitor (not used) would fire when the app is active.
- (void)_updateMonitor
{
	// Remove old monitor if any
	if (_globalMonitor) {
		[NSEvent removeMonitor:_globalMonitor];
		[_globalMonitor release];
		_globalMonitor = nil;
	}

	// Only create a monitor if we have registered hotkeys
	if ([_hotKeys count] == 0) {
		return;
	}

	AIHotKeyCenter *__unsafe_unretained weakSelf = self;
	_globalMonitor = [[NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskKeyDown
															 handler:^(NSEvent *event) {
																 AIHotKeyCenter *strongSelf = weakSelf;
																 if (strongSelf) {
																	 [strongSelf _handleKeyDown:event];
																 }
															 }] retain];

	if (!_globalMonitor) {
		AILogWithSignature(@"Failed to create global event monitor — hotkeys will not work. "
						   @"The app may lack accessibility permissions.");
	}
}

- (void)_handleKeyDown:(NSEvent *)event
{
	// Snapshot to prevent mutation-during-enumeration if a hotkey action
	// callback calls registerHotKey: or unregisterHotKey:.
	NSArray *snapshot = [[_hotKeys copy] autorelease];
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