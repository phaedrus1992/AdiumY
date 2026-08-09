/*
 * Stub for the standalone CoverageHost test target. The real PurpleCommon.h declares
 * libpurple-facing helpers; no wired TU in the test bundle references those symbols, so this
 * stub only needs to exist for the SLPurpleCocoaAdapter.h import chain to resolve.
 */
#import <Cocoa/Cocoa.h>
