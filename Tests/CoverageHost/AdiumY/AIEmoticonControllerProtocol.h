/*
 * Stub for the standalone CoverageHost test target. Provides just enough of the real
 * AIEmoticonController protocol for BGEmoticonMenuPlugin.m (via the real AIEmoticonController.h)
 * to compile without an AdiumY.framework binary. PREF_GROUP_EMOTICONS is deliberately NOT defined
 * here: BGEmoticonMenuPlugin.m defines it locally and a macro redefinition would warn.
 */
#import <Foundation/Foundation.h>

#import <AdiumY/AIControllerProtocol.h>

@protocol AIEmoticonController <AIController>
- (NSArray *)activeEmoticonPacks;
@end
