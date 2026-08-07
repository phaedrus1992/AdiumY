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
 * Link shims for the standalone test target. The plugin TU references AIAdvancedPreferences,
 * AIMessageAlertsAdvancedPreferences, and AIConfirmationsAdvancedPreferences by class name (each
 * sent +preferencePane), which emit _OBJC_CLASS_$_ symbols no linked framework provides, so each
 * gets a minimal implementation here. Each returns a live pane so installPlugin stores non-nil
 * references and uninstallPlugin must removePreferencePane: all three — the exact path #231 fixes.
 * The shared `adium` global and the AIPlugin class are provided by TestESUserIconHandlingPluginObserverRemoval.m
 * in the same bundle — not redefined here.
 */
@interface AIAdvancedPreferences : NSObject
+ (instancetype)preferencePane;
@end

@implementation AIAdvancedPreferences
+ (instancetype)preferencePane
{
	return [[self alloc] init];
}
@end

@interface AIMessageAlertsAdvancedPreferences : NSObject
+ (instancetype)preferencePane;
@end

@implementation AIMessageAlertsAdvancedPreferences
+ (instancetype)preferencePane
{
	return [[self alloc] init];
}
@end

@interface AIConfirmationsAdvancedPreferences : NSObject
+ (instancetype)preferencePane;
@end

@implementation AIConfirmationsAdvancedPreferences
+ (instancetype)preferencePane
{
	return [[self alloc] init];
}
@end

// clang-format off
// Import order is load-bearing here too: AIAdvancedPreferencesPlugin.h declares its superclass AIPlugin
// without importing it (Adium.pch does that app-wide), so AIPlugin must precede the own-header.
#import <AdiumY/AIPlugin.h>
#import "AIAdvancedPreferencesPlugin.h"
// clang-format on

/*
 * Fakes for the teardown test. AdvancedPrefsMockPreferenceController records removePreferencePane:
 * calls (the only preference-controller interaction uninstallPlugin makes); AdvancedPrefsMockAdium
 * supplies the preference controller.
 */
@interface AdvancedPrefsMockPreferenceController : NSObject
@property(nonatomic, assign) NSUInteger removePreferencePaneCount;

- (void)removePreferencePane:(id)inPane;
@end

@implementation AdvancedPrefsMockPreferenceController
- (void)removePreferencePane:(id)inPane
{
	_removePreferencePaneCount++;
}
@end

@interface AdvancedPrefsMockAdium : NSObject
@property(nonatomic, strong) AdvancedPrefsMockPreferenceController *preferenceController;
@end

@implementation AdvancedPrefsMockAdium
@end

@interface AIAdvancedPreferencesPluginUninstallTest : XCTestCase
@end

@implementation AIAdvancedPreferencesPluginUninstallTest

// installPlugin creates three preference panes (AIAdvancedPreferences, AIMessageAlertsAdvancedPreferences,
// AIConfirmationsAdvancedPreferences), each registering itself with the preference controller;
// uninstallPlugin must remove every one, or the uninstalled plugin's panes stay in the preferences
// window (#231).
- (void)testUninstallRemovesAllRegisteredPreferencePanes
{
	AdvancedPrefsMockPreferenceController *mockPreferenceController =
		[[AdvancedPrefsMockPreferenceController alloc] init];
	AdvancedPrefsMockAdium *mockAdium = [[AdvancedPrefsMockAdium alloc] init];
	[mockAdium setPreferenceController:mockPreferenceController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		AIAdvancedPreferencesPlugin *plugin = [[AIAdvancedPreferencesPlugin alloc] init];
		[plugin installPlugin];

		XCTAssertEqual([mockPreferenceController removePreferencePaneCount], (NSUInteger)0,
					   @"sanity: installPlugin registers panes but removes none");

		[plugin uninstallPlugin];

		XCTAssertEqual([mockPreferenceController removePreferencePaneCount], (NSUInteger)3,
					   @"uninstallPlugin must remove every preference pane installPlugin registered");
	} @finally {
		adium = savedAdium;
	}
}

@end
