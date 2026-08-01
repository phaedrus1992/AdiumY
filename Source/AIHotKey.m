//
//  AIHotKey.m
//  Adium
//
//  Modern replacement for SGHotKey/SGKeyCombo.
//

#import "AIHotKey.h"
#import <Carbon/Carbon.h> // For modifier constants when reading legacy plist format

NSString *const AIHotKeyKeyCodeKey = @"keyCode";
NSString *const AIHotKeyModifiersKey = @"modifiers";

// Unicode glyphs for modifier symbols
static NSString *const kCommandGlyph = @"⌘";
static NSString *const kControlGlyph = @"⌃";
static NSString *const kOptionGlyph = @"⌥";
static NSString *const kShiftGlyph = @"⇧";

@implementation AIHotKey

@synthesize identifier;
@synthesize name;
@synthesize keyCode;
@synthesize modifierFlags;
@synthesize target;
@synthesize action;

- (id)initWithIdentifier:(NSString *)theIdentifier
				 keyCode:(unsigned short)theKeyCode
		   modifierFlags:(NSUInteger)theModifierFlags
				  target:(id)theTarget
				  action:(SEL)theAction
{
	if ((self = [super init])) {
		identifier = [theIdentifier copy];
		keyCode = theKeyCode;
		modifierFlags = theModifierFlags;
		target = theTarget;
		action = theAction;
	}
	return self;
}

- (id)initWithIdentifier:(NSString *)theIdentifier
				 keyCode:(unsigned short)theKeyCode
		   modifierFlags:(NSUInteger)theModifierFlags
{
	return [self initWithIdentifier:theIdentifier
							keyCode:theKeyCode
					  modifierFlags:theModifierFlags
							 target:nil
							 action:NULL];
}

- (BOOL)isClearCombo
{
	return (self.keyCode == 0 && self.modifierFlags == 0);
}

- (BOOL)isValidCombo
{
	return (self.keyCode != 0 || self.modifierFlags != 0);
}

- (NSString *)modifierFlagsString
{
	NSMutableString *modifierString = [NSMutableString string];
	if (self.modifierFlags & NSEventModifierFlagControl)
		[modifierString appendString:kControlGlyph];
	if (self.modifierFlags & NSEventModifierFlagOption)
		[modifierString appendString:kOptionGlyph];
	if (self.modifierFlags & NSEventModifierFlagShift)
		[modifierString appendString:kShiftGlyph];
	if (self.modifierFlags & NSEventModifierFlagCommand)
		[modifierString appendString:kCommandGlyph];
	return modifierString;
}

- (NSString *)keyCodeString
{
	if ([self isClearCombo]) {
		return @"";
	}

	// Map common key codes to display names
	switch (self.keyCode) {
	case 49:
		return @"Space";
	case 36:
		return @"Return";
	case 76:
		return @"Enter";
	case 48:
		return @"Tab";
	case 53:
		return @"Esc";
	case 51:
		return @"⌫"; // Delete (left)
	case 117:
		return @"⌦"; // Delete (right)
	case 123:
		return @"←"; // Left arrow
	case 124:
		return @"→"; // Right arrow
	case 125:
		return @"↓"; // Down arrow
	case 126:
		return @"↑"; // Up arrow
	case 116:
		return @"⇞"; // Page Up
	case 121:
		return @"⇟"; // Page Down
	case 115:
		return @"↖"; // Home
	case 119:
		return @"↘"; // End
	case 71:
		return @"Clear";
	case 114:
		return @"Help";
		// Function keys
	case 122:
		return @"F1";
	case 120:
		return @"F2";
	case 99:
		return @"F3";
	case 118:
		return @"F4";
	case 96:
		return @"F5";
	case 97:
		return @"F6";
	case 98:
		return @"F7";
	case 100:
		return @"F8";
	case 101:
		return @"F9";
	case 109:
		return @"F10";
	case 103:
		return @"F11";
	case 111:
		return @"F12";
	case 105:
		return @"F13";
	case 107:
		return @"F14";
	case 113:
		return @"F15";
	case 106:
		return @"F16";
	case 64:
		return @"F17";
	case 79:
		return @"F18";
	case 80:
		return @"F19";
	}

	// For letter keys, attempt to derive the character
	if (self.keyCode >= 0 && self.keyCode <= 0x7F) {
		// Try to get the character from current keyboard layout
		TISInputSourceRef source = TISCopyCurrentKeyboardLayoutInputSource();
		if (source) {
			CFDataRef layoutData = (CFDataRef)TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData);
			if (layoutData) {
				const UCKeyboardLayout *layout = (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
				if (layout) {
					UniChar chars[4] = {0};
					UniCharCount actualLength = 0;
					UInt32 deadKeyState = 0;

					OSStatus err = UCKeyTranslate(layout, self.keyCode, kUCKeyActionDisplay, 0, LMGetKbdType(),
												  kUCKeyTranslateNoDeadKeysBit, &deadKeyState,
												  sizeof(chars) / sizeof(chars[0]), &actualLength, chars);
					if (err == noErr && actualLength > 0) {
						NSString *result = [NSString stringWithCharacters:chars length:1];
						CFRelease(source);
						return result;
					}
				}
			}
			CFRelease(source);
		}
	}

	return [NSString stringWithFormat:@"%hu", self.keyCode];
}

- (NSString *)shortcutDisplayString
{
	if ([self isClearCombo] || ![self isValidCombo]) {
		return NSLocalizedString(@"(None)", @"Hot Keys: Key Combo text for 'empty' combo");
	}

	return [NSString stringWithFormat:@"%@%@", [self modifierFlagsString], [self keyCodeString]];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@: %@, %@>", NSStringFromClass([self class]), self.identifier,
									  [self shortcutDisplayString]];
}

#pragma mark - Modifier flag conversion (SGKeyCombo plist backward compat)

- (id)initWithDictionary:(NSDictionary *)dict
{
	id keyCodeValue = [dict objectForKey:AIHotKeyKeyCodeKey];
	id modifiersValue = [dict objectForKey:AIHotKeyModifiersKey];
	unsigned short theKeyCode = (keyCodeValue ? [keyCodeValue unsignedShortValue] : 0);
	NSUInteger carbonModifiers = (modifiersValue ? [modifiersValue unsignedIntegerValue] : 0);

	return [self initWithIdentifier:nil keyCode:theKeyCode modifierFlags:[self _carbonToCocoaFlags:carbonModifiers]];
}

- (NSDictionary *)dictionaryRepresentation
{
	return [NSDictionary
		dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedShort:self.keyCode], AIHotKeyKeyCodeKey,
									 [NSNumber numberWithUnsignedInteger:[self _cocoaToCarbonFlags:self.modifierFlags]],
									 AIHotKeyModifiersKey, nil];
}

- (NSUInteger)_carbonToCocoaFlags:(NSUInteger)carbonFlags
{
	NSUInteger cocoaFlags = 0;
	if (carbonFlags & cmdKey)
		cocoaFlags |= NSEventModifierFlagCommand;
	if (carbonFlags & optionKey)
		cocoaFlags |= NSEventModifierFlagOption;
	if (carbonFlags & controlKey)
		cocoaFlags |= NSEventModifierFlagControl;
	if (carbonFlags & shiftKey)
		cocoaFlags |= NSEventModifierFlagShift;
	return cocoaFlags;
}

- (NSUInteger)_cocoaToCarbonFlags:(NSUInteger)cocoaFlags
{
	NSUInteger carbonFlags = 0;
	if (cocoaFlags & NSEventModifierFlagCommand)
		carbonFlags |= cmdKey;
	if (cocoaFlags & NSEventModifierFlagOption)
		carbonFlags |= optionKey;
	if (cocoaFlags & NSEventModifierFlagControl)
		carbonFlags |= controlKey;
	if (cocoaFlags & NSEventModifierFlagShift)
		carbonFlags |= shiftKey;
	return carbonFlags;
}

@end