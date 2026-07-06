//
//  AIHotKeyCenter.h
//  Adium
//
//  Modern replacement for SGHotKeyCenter.
//  Uses NSEvent global monitors instead of Carbon RegisterEventHotKey.
//

#import <Cocoa/Cocoa.h>

@class AIHotKey;

@interface AIHotKeyCenter : NSObject

+ (AIHotKeyCenter *)sharedCenter;

- (BOOL)registerHotKey:(AIHotKey *)theHotKey;
- (void)unregisterHotKey:(AIHotKey *)theHotKey;

- (NSArray *)allHotKeys;
- (AIHotKey *)hotKeyWithIdentifier:(NSString *)theIdentifier;

@end