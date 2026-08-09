/*
 * Stub for the standalone CoverageHost test target. The real CBPurpleAccount pulls in the full
 * libpurple account surface; the test bundle only needs the type name so SLPurpleCocoaAdapter.h
 * compiles (its pointer usages are covered by that header's own @class forward declaration).
 */
#import <Cocoa/Cocoa.h>

@interface CBPurpleAccount : NSObject
@end
