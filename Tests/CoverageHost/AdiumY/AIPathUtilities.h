/*
 * Stub for the standalone CoverageHost test target. Provides just enough of the real
 * AIPathUtilities.h C functions for AIXtrasManager.m to compile without an AdiumY.framework
 * binary.
 */
#import <Foundation/Foundation.h>

enum {
	AICachesDirectory = 400,
	AIPluginsDirectory = 405,
	AIContactListDirectory = 410,
	AIDockIconsDirectory = 411,
	AIEmoticonsDirectory = 412,
	AIMessageStylesDirectory = 413,
	AIScriptsDirectory = 414,
	AIServiceIconsDirectory = 415,
	AISoundsDirectory = 416,
	AIStatusIconsDirectory = 417,
	AIMenuBarIconsDirectory = 418,
};

NSArray *AISearchPathForDirectories(NSUInteger directory);
NSArray *AISearchPathForDirectoriesInDomainsExpanding(NSUInteger directory, NSUInteger domainMask, BOOL expandTilde);
