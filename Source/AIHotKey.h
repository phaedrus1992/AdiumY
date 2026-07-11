//
//  AIHotKey.h
//  Adium
//
//  Modern replacement for SGHotKey/SGKeyCombo.
//  Uses Cocoa NSEventModifierFlags instead of Carbon modifier constants.
//

#import <Cocoa/Cocoa.h>

@interface AIHotKey : NSObject

@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, assign) unsigned short keyCode;
@property(nonatomic, assign) NSUInteger modifierFlags; // NSEventModifierFlags
@property(nonatomic, assign) id target;
@property(nonatomic, assign) SEL action;

- (id)initWithIdentifier:(NSString *)theIdentifier
				 keyCode:(unsigned short)theKeyCode
		   modifierFlags:(NSUInteger)theModifierFlags
				  target:(id)theTarget
				  action:(SEL)theAction;

- (id)initWithIdentifier:(NSString *)theIdentifier
				 keyCode:(unsigned short)theKeyCode
		   modifierFlags:(NSUInteger)theModifierFlags;

// Plist persistence (backward-compatible with SGKeyCombo plist format)
- (id)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)dictionaryRepresentation;

- (BOOL)isClearCombo;
- (BOOL)isValidCombo;

// Display strings
- (NSString *)keyCodeString;
- (NSString *)modifierFlagsString;
- (NSString *)shortcutDisplayString;

@end