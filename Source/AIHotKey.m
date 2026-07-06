//
//  AIHotKey.m
//  Adium
//
//  Modern replacement for SGHotKey/SGKeyCombo.
//

#import "AIHotKey.h"
#import <Carbon/Carbon.h> // For modifier constants when reading legacy plist format

NSString * const AIHotKeyKeyCodeKey = @"keyCode";
NSString * const AIHotKeyModifiersKey = @"modifiers";

// Unicode glyphs for modifier symbols
static NSString * const kCommandGlyph = @"⌘";
static NSString * const kControlGlyph = @"⌃";
static NSString * const kOptionGlyph  = @"⌥";
static NSString * const kShiftGlyph   = @"⇧";

@implementation AIHotKey

@synthesize identifier;
@synthesize name;
@synthesize keyCode;
@synthesize modifierFlags;
@synthesize target;
@synthesize action;

- (void)dealloc {
    [identifier release];
    [name release];
    [super dealloc];
}

- (id)init {
    return [self initWithIdentifier:nil keyCode:0 modifierFlags:0];
}

- (id)initWithIdentifier:(NSString *)theIdentifier
                 keyCode:(unsigned short)theKeyCode
           modifierFlags:(NSUInteger)theModifierFlags {
    if ((self = [super init])) {
        self.identifier = theIdentifier;
        self.keyCode = theKeyCode;
        self.modifierFlags = theModifierFlags;
    }
    return self;
}

- (id)initWithIdentifier:(NSString *)theIdentifier
                 keyCode:(unsigned short)theKeyCode
           modifierFlags:(NSUInteger)theModifierFlags
                  target:(id)theTarget
                  action:(SEL)theAction {
    if ((self = [super init])) {
        self.identifier = theIdentifier;
        self.keyCode = theKeyCode;
        self.modifierFlags = theModifierFlags;
        self.target = theTarget;
        self.action = theAction;
    }
    return self;
}

#pragma mark - Plist persistence (SGKeyCombo-compatible format)

- (id)initWithDictionary:(NSDictionary *)dict {
    if (!dict || ![dict count]) {
        return [self initWithIdentifier:nil keyCode:0 modifierFlags:0];
    }

    NSInteger theKeyCode = [[dict objectForKey:AIHotKeyKeyCodeKey] integerValue];
    NSUInteger theModifiers = [[dict objectForKey:AIHotKeyModifiersKey] unsignedIntegerValue];

    // Convert Carbon modifiers to Cocoa modifiers if needed
    NSUInteger cocoaFlags = [self _carbonToCocoaFlags:theModifiers];

    // -1 in the plist means "clear combo"
    if (theKeyCode < 0) {
        return [self initWithIdentifier:nil keyCode:0 modifierFlags:0];
    }

    return [self initWithIdentifier:nil keyCode:(unsigned short)theKeyCode modifierFlags:cocoaFlags];
}

- (NSDictionary *)dictionaryRepresentation {
    NSUInteger carbonFlags = [self _cocoaToCarbonFlags:self.modifierFlags];
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedInteger:self.keyCode], AIHotKeyKeyCodeKey,
            [NSNumber numberWithUnsignedInteger:carbonFlags], AIHotKeyModifiersKey,
            nil];
}

#pragma mark - State queries

- (BOOL)isClearCombo {
    return self.keyCode == 0 && self.modifierFlags == 0;
}

- (BOOL)isValidCombo {
    return self.modifierFlags > 0;
}

#pragma mark - Display

- (NSString *)modifierFlagsString {
    if ([self isClearCombo]) {
        return @"";
    }

    NSMutableString *string = [NSMutableString string];
    if (self.modifierFlags & NSControlKeyMask) {
        [string appendString:kControlGlyph];
    }
    if (self.modifierFlags & NSAlternateKeyMask) {
        [string appendString:kOptionGlyph];
    }
    if (self.modifierFlags & NSShiftKeyMask) {
        [string appendString:kShiftGlyph];
    }
    if (self.modifierFlags & NSCommandKeyMask) {
        [string appendString:kCommandGlyph];
    }

    return [[string copy] autorelease];
}

- (NSString *)keyCodeString {
    if ([self isClearCombo]) {
        return @"";
    }

    // Map common key codes to display names
    switch (self.keyCode) {
        case 49: return @"Space";
        case 36: return @"Return";
        case 76: return @"Enter";
        case 48: return @"Tab";
        case 53: return @"Esc";
        case 51: return @"⌫"; // Delete (left)
        case 117: return @"⌦"; // Delete (right)
        case 123: return @"←"; // Left arrow
        case 124: return @"→"; // Right arrow
        case 125: return @"↓"; // Down arrow
        case 126: return @"↑"; // Up arrow
        case 116: return @"⇞"; // Page Up
        case 121: return @"⇟"; // Page Down
        case 115: return @"↖"; // Home
        case 119: return @"↘"; // End
        case 71: return @"Clear";
        case 114: return @"Help";
            // Function keys
        case 122: return @"F1";
        case 120: return @"F2";
        case 99: return @"F3";
        case 118: return @"F4";
        case 96: return @"F5";
        case 97: return @"F6";
        case 98: return @"F7";
        case 100: return @"F8";
        case 101: return @"F9";
        case 109: return @"F10";
        case 103: return @"F11";
        case 111: return @"F12";
        case 105: return @"F13";
        case 107: return @"F14";
        case 113: return @"F15";
        case 106: return @"F16";
        case 64: return @"F17";
        case 79: return @"F18";
        case 80: return @"F19";
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

                    OSStatus err = UCKeyTranslate(layout,
                                                  self.keyCode,
                                                  kUCKeyActionDisplay,
                                                  0,
                                                  LMGetKbdType(),
                                                  kUCKeyTranslateNoDeadKeysBit,
                                                  &deadKeyState,
                                                  sizeof(chars) / sizeof(chars[0]),
                                                  &actualLength,
                                                  chars);
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

- (NSString *)shortcutDisplayString {
    if ([self isClearCombo] || ![self isValidCombo]) {
        return NSLocalizedString(@"(None)", @"Hot Keys: Key Combo text for 'empty' combo");
    }

    return [NSString stringWithFormat:@"%@%@",
            [self modifierFlagsString],
            [self keyCodeString]];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %@, %@>",
            NSStringFromClass([self class]),
            self.identifier,
            [self shortcutDisplayString]];
}

#pragma mark - Modifier flag conversion (SGKeyCombo plist backward compat)

- (NSUInteger)_carbonToCocoaFlags:(NSUInteger)carbonFlags {
    NSUInteger cocoaFlags = 0;
    if (carbonFlags & cmdKey)      cocoaFlags |= NSCommandKeyMask;
    if (carbonFlags & optionKey)   cocoaFlags |= NSAlternateKeyMask;
    if (carbonFlags & controlKey)  cocoaFlags |= NSControlKeyMask;
    if (carbonFlags & shiftKey)    cocoaFlags |= NSShiftKeyMask;
    return cocoaFlags;
}

- (NSUInteger)_cocoaToCarbonFlags:(NSUInteger)cocoaFlags {
    NSUInteger carbonFlags = 0;
    if (cocoaFlags & NSCommandKeyMask)   carbonFlags |= cmdKey;
    if (cocoaFlags & NSAlternateKeyMask) carbonFlags |= optionKey;
    if (cocoaFlags & NSControlKeyMask)   carbonFlags |= controlKey;
    if (cocoaFlags & NSShiftKeyMask)     carbonFlags |= shiftKey;
    return carbonFlags;
}

@end