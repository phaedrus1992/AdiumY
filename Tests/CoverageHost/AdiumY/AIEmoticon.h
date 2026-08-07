/*
 * Stub for the standalone CoverageHost test target. Provides just enough of the real
 * AIEmoticon class for BGEmoticonMenuPlugin.m to compile without an AdiumY.framework binary.
 * The plugin TU only reads the enabled/name/image accessors and textEquivalents.
 */
#import <Cocoa/Cocoa.h>

@interface AIEmoticon : NSObject
- (NSString *)name;
- (NSImage *)image;
- (BOOL)isEnabled;
- (NSArray *)textEquivalents;
@end
