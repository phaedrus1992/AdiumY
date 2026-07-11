//
//  AIHotKeyRecorder.h
//  Adium
//
//  Minimal replacement for SRRecorderControl.
//  Click to capture a key combination; displays the current combo.
//

#import <Cocoa/Cocoa.h>

@class AIHotKey;

@interface AIHotKeyRecorder : NSControl

@property(nonatomic, assign) id delegate;
@property(nonatomic, retain) AIHotKey *hotKey;

- (NSString *)keyComboString;

@end

@interface NSObject (AIHotKeyRecorderDelegate)

- (BOOL)hotKeyRecorder:(AIHotKeyRecorder *)aRecorder
	shouldCaptureKeyCode:(unsigned short)keyCode
		   modifierFlags:(NSUInteger)modifierFlags;
- (void)hotKeyRecorder:(AIHotKeyRecorder *)aRecorder keyComboDidChange:(AIHotKey *)hotKey;

@end