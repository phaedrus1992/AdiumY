/*
 * Stub for the standalone CoverageHost test target. Provides just enough of the real
 * AISoundController protocol (via the real AISoundController.h) for the sound-plugging contact
 * alert TUs to compile without an AdiumY.framework binary. Only playSoundAtPath: and
 * speakText:withVoice:pitch:rate: are used.
 */
#import <Foundation/Foundation.h>

#import <AdiumY/AIControllerProtocol.h>

@protocol AISoundController <AIController>
- (void)playSoundAtPath:(NSString *)inPath;
- (void)speakText:(NSString *)text withVoice:(NSString *)voiceString pitch:(float)pitch rate:(float)rate;
@end
