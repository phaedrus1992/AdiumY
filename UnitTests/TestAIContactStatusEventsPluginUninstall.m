/*
 * Adium is the legal property of its developers, whose names are listed in the copyright file included
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
 * The real @implementation for AIContactStatusEventsPlugin is wired into this bundle; the relaxed
 * @interface below declares only the surface this test needs. installPlugin: allocates five cache
 * dictionaries but nothing in the unload path ever releases them (#237). The caches are plain ivars
 * with no accessors, so the test observes them via KVC; installPlugin touches no adium state, so no
 * mock adium is needed here.
 */
@interface AIContactStatusEventsPlugin : NSObject
- (void)installPlugin;
- (void)uninstallPlugin;
@end

@interface AIContactStatusEventsPluginUninstallTest : XCTestCase
@end

@implementation AIContactStatusEventsPluginUninstallTest

// installPlugin: allocates five cache dicts; uninstallPlugin: must release all five (#237).
- (void)testUninstallClearsAllFiveCacheDictionaries
{
	NSArray<NSString *> *cacheKeys =
		@[ @"onlineCache", @"awayCache", @"idleCache", @"statusMessageCache", @"mobileCache" ];

	AIContactStatusEventsPlugin *plugin = [[AIContactStatusEventsPlugin alloc] init];
	[plugin installPlugin];

	for (NSString *key in cacheKeys) {
		XCTAssertNotNil([plugin valueForKey:key], @"sanity: installPlugin allocates %@", key);
	}

	[plugin uninstallPlugin];

	for (NSString *key in cacheKeys) {
		XCTAssertNil([plugin valueForKey:key], @"uninstallPlugin must release %@", key);
	}
}

// Teardown must be safe against already-torn-down state: a second uninstallPlugin: is a no-op.
- (void)testUninstallIsIdempotent
{
	AIContactStatusEventsPlugin *plugin = [[AIContactStatusEventsPlugin alloc] init];
	[plugin installPlugin];
	[plugin uninstallPlugin];

	[plugin uninstallPlugin];

	XCTAssertNil([plugin valueForKey:@"onlineCache"], @"double uninstall must not resurrect caches");
}

@end
