/*
 * Adium is the property of its developers, whose names are listed in the copyright file included
 * with this source distribution.
 *
 * This program is free software; you can redistribute it and/or modify it under the terms of the GNU
 * General Public License as published by the Free Software Foundation; either version 2 of the License,
 * or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
 * the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
 * Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program; if not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

#import <XCTest/XCTest.h>

/*
 * AIXtrasManager keeps a static shared manager that must be cleared on uninstall (#222). The real
 * AIXtrasManager @implementation is wired into this bundle and provides the _OBJC_CLASS_$_AIXtrasManager
 * symbol; the relaxed @interface below declares only the surface this test needs. AIXtraInfo gets a
 * minimal @implementation so the class sends in the real TU ([AIXtraInfo infoWithURL:]) link.
 */
@interface AIXtrasManager : NSObject
+ (AIXtrasManager *)sharedManager;
- (void)installPlugin;
- (void)uninstallPlugin;
@end

@interface AIXtraInfo : NSObject
+ (id)infoWithURL:(NSURL *)url;
@end

@implementation AIXtraInfo
+ (id)infoWithURL:(NSURL *)url
{
	return nil;
}
@end

/*
 * Link shim for the path-utility symbol. AIXtrasManager.m calls AISearchPathForDirectories from its
 * xtrasForCategoryAtIndex: path; the standalone test bundle links no AIPathUtilities implementation,
 * so this returns nil (arrayOfXtrasAtPaths: fast-enumerates over it, which is a safe no-op on nil).
 */
NSArray *AISearchPathForDirectories(NSUInteger directory)
{
	return nil;
}

@interface XtrasManagerUninstallTest : XCTestCase
@end

@implementation XtrasManagerUninstallTest

// installPlugin stores self in the static shared manager; uninstallPlugin must clear it, or an
// uninstalled plugin stays reachable as a dangling singleton.
- (void)testUninstallClearsSharedManager
{
	XCTAssertNil([AIXtrasManager sharedManager], @"sanity: the shared manager must be nil before any plugin installs");

	AIXtrasManager *plugin = [[AIXtrasManager alloc] init];
	[plugin installPlugin];

	XCTAssertEqualObjects([AIXtrasManager sharedManager], plugin,
						  @"installPlugin must set the static shared manager to itself");

	[plugin uninstallPlugin];

	XCTAssertNil([AIXtrasManager sharedManager],
				 @"uninstallPlugin must clear the static shared manager so no dangling singleton remains");
}

@end
