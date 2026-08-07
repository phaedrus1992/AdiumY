/*
 * Stub for the standalone CoverageHost test target. Provides just enough of the real
 * AISoundController protocol (via the real AISoundController.h) for the sound-plugging contact
 * alert TUs to compile without an AdiumY.framework binary. Only playSoundAtPath: and
 * speakText:withVoice:pitch:rate: are used.
 */
#import <Foundation/Foundation.h>

#import <AdiumY/AIControllerProtocol.h>

// The real AISoundControllerProtocol.h defines this at line 19; the standalone test target has no
// Adium.pch providing it app-wide, so define it here for the sound-plugging TUs.
#define PREF_GROUP_SOUNDS @"Sounds"

@protocol AISoundController <AIController>
- (void)playSoundAtPath:(NSString *)inPath;
- (void)speakText:(NSString *)text withVoice:(NSString *)voiceString pitch:(float)pitch rate:(float)rate;
@end
