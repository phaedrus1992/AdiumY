/*
 * Stub for the standalone CoverageHost test target. Provides just enough of the real
 * AIListOutlineView class for the AIListWindowController.h chain pulled in by
 * SMContactListShowBehaviorPlugin.m to compile without an AdiumY.framework binary. The TU only
 * receives the concrete AIAnimatingListOutlineView via AIListWindowController's accessor, so no
 * methods are required here.
 */
#import <Cocoa/Cocoa.h>

@interface AIListOutlineView : NSOutlineView
@end
