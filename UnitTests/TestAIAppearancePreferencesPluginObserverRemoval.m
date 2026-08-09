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

// The plugin TU reads AIStatusIconSetInvalidSetNotification via AIStatusIcons.h; this TU avoids
// importing that header (its class is shimmed below), so the constant is defined locally.
#ifndef AIStatusIconSetInvalidSetNotification
#define AIStatusIconSetInvalidSetNotification @"AIStatusIconSetInvalidSetNotification"
#endif

/*
 * Link shims for the standalone test target. The plugin TU references AIAppearancePreferences
 * (preferencePaneForPlugin:) and AIStatusIcons (setActiveStatusIconsFromPath:) by class name, which
 * emit _OBJC_CLASS_$ symbols no linked framework provides, so each gets a minimal implementation here.
 * (AIXtrasManager, also class-sent by the plugin TU, comes from its own real TU wired into this bundle.)
 * The plugin's own TU imports the real headers; the relaxed declarations here keep the heavy headers
 * (and AIAppearancePreferences's AIPreferencePane superclass) out of this TU. AIServiceIcons and the
 * shared `adium` global and AIPlugin class are provided by TestESUserIconHandlingPluginObserverRemoval.m
 * in the same bundle — not redefined here.
 */
@interface AIAppearancePreferences : NSObject
+ (instancetype)preferencePaneForPlugin:(id)plugin;
@end

@implementation AIAppearancePreferences
+ (instancetype)preferencePaneForPlugin:(id)plugin
{
	// Return a live pane so installPlugin stores a non-nil `preferences` and uninstallPlugin must
	// removePreferencePane: it — the exact path #220 fixes.
	return [[self alloc] init];
}
@end

/*
 * The wired AIStatusController.m sends [AIStatusIcons statusIconForStatusName:...] when building
 * status menus, so the shim must implement the method (returning nil) to keep menu construction
 * from raising an unrecognized-selector exception.
 */
@interface AIStatusIcons : NSObject
+ (id)statusIconForStatusName:(NSString *)statusName
				   statusType:(NSInteger)statusType
					 iconType:(NSInteger)iconType
					direction:(NSInteger)direction;
@end

@implementation AIStatusIcons
+ (id)statusIconForStatusName:(NSString *)statusName
				   statusType:(NSInteger)statusType
					 iconType:(NSInteger)iconType
					direction:(NSInteger)direction
{
	return nil;
}
@end

#import "AIAppearancePreferencesPlugin.h"
#import <AdiumY/AIPlugin.h>

/*
 * Fakes for the teardown test. AppearanceMockPreferenceController records the register/unregister
 * calls installPlugin and uninstallPlugin make, including removePreferencePane:; AppearanceMockAdium
 * provides the preference controller (which installPlugin asserts on, unlike ESiTunes's nil
 * preferenceController) and implements createResourcePathForName:, which installPlugin calls directly
 * on adium.
 */
@interface AppearanceMockPreferenceController : NSObject
@property(nonatomic, assign) NSUInteger registerDefaultsCount;
@property(nonatomic, assign) NSUInteger registerObserverCount;
@property(nonatomic, assign) NSUInteger unregisterObserverCount;
@property(nonatomic, assign) NSUInteger removePreferencePaneCount;

- (void)registerDefaults:(NSDictionary *)defaults forGroup:(NSString *)group;
- (void)registerPreferenceObserver:(id)observer forGroup:(NSString *)group;
- (void)unregisterPreferenceObserver:(id)observer;
- (void)removePreferencePane:(id)inPane;
@end

@implementation AppearanceMockPreferenceController
- (void)registerDefaults:(NSDictionary *)defaults forGroup:(NSString *)group
{
	_registerDefaultsCount++;
}

- (void)registerPreferenceObserver:(id)observer forGroup:(NSString *)group
{
	_registerObserverCount++;
}

- (void)unregisterPreferenceObserver:(id)observer
{
	_unregisterObserverCount++;
}

- (void)removePreferencePane:(id)inPane
{
	_removePreferencePaneCount++;
}
@end

@interface AppearanceMockAdium : NSObject
@property(nonatomic, strong) AppearanceMockPreferenceController *preferenceController;
- (void)createResourcePathForName:(NSString *)name;
@end

@implementation AppearanceMockAdium
- (void)createResourcePathForName:(NSString *)name
{}
@end

/*
 * Counting subclass: overrides invalidStatusSetActivated: so the install-time observer can be
 * detected by counter instead of by side effect; installPlugin/uninstallPlugin run their real
 * bodies.
 */
@interface AppearancePreferencesObserverCountingPlugin : AIAppearancePreferencesPlugin
@property(nonatomic, assign) NSUInteger invalidStatusSetCount;
@end

@implementation AppearancePreferencesObserverCountingPlugin
- (void)invalidStatusSetActivated:(NSNotification *)notification
{
	_invalidStatusSetCount++;
}
@end

@interface AIAppearancePreferencesPluginObserverRemovalTest : XCTestCase
@end

@implementation AIAppearancePreferencesPluginObserverRemovalTest

// installPlugin registers the AIStatusIconSetInvalidSetNotification observer and a preference
// observer; uninstallPlugin must remove both, or the uninstalled plugin keeps reacting to status
// icon set changes and preference updates.
- (void)testUninstallRemovesObservers
{
	AppearanceMockPreferenceController *mockPreferenceController = [[AppearanceMockPreferenceController alloc] init];
	AppearanceMockAdium *mockAdium = [[AppearanceMockAdium alloc] init];
	[mockAdium setPreferenceController:mockPreferenceController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		AppearancePreferencesObserverCountingPlugin *plugin =
			[[AppearancePreferencesObserverCountingPlugin alloc] init];
		[plugin installPlugin];

		XCTAssertEqual([mockPreferenceController registerDefaultsCount], (NSUInteger)1,
					   @"sanity: registerDefaults:forGroup: called once at install");
		XCTAssertEqual([mockPreferenceController registerObserverCount], (NSUInteger)1,
					   @"sanity: registerPreferenceObserver:forGroup: called once at install");
		XCTAssertEqual([plugin invalidStatusSetCount], (NSUInteger)0,
					   @"sanity: installPlugin does not fire the status-icon-set observer");

		// Positive control: the observer must fire while installed, or this test cannot tell
		// "removed by uninstallPlugin" from "never registered at all".
		[[NSNotificationCenter defaultCenter] postNotificationName:AIStatusIconSetInvalidSetNotification object:nil];
		XCTAssertEqual([plugin invalidStatusSetCount], (NSUInteger)1,
					   @"sanity: AIStatusIconSetInvalidSetNotification observer fired while installed");

		[plugin uninstallPlugin];

		XCTAssertEqual([mockPreferenceController unregisterObserverCount], (NSUInteger)1,
					   @"uninstallPlugin did not unregister the preference observer");
		XCTAssertEqual([mockPreferenceController removePreferencePaneCount], (NSUInteger)1,
					   @"uninstallPlugin did not remove the preference pane it registered");
		[[NSNotificationCenter defaultCenter] postNotificationName:AIStatusIconSetInvalidSetNotification object:nil];
		XCTAssertEqual([plugin invalidStatusSetCount], (NSUInteger)1,
					   @"AIStatusIconSetInvalidSetNotification observer still registered after uninstallPlugin");
	} @finally {
		adium = savedAdium;
	}
}

@end
