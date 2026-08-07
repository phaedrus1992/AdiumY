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

#import "AIContactVisibilityControlPlugin.h"
#import <XCTest/XCTest.h>

/*
 * The shared `adium` global, the AIPlugin class, and the empty AIAccountMenu class come from
 * TestESUserIconHandlingPluginObserverRemoval.m / TestAIStateMenuPluginUninstall.m in the same
 * bundle — not redefined here.
 */
@protocol AIAdium;
extern id<AIAdium> adium;

/*
 * Recording fakes. installPlugin registers eight view-toggle menu items against
 * adium.menuController and keeps the hide-accounts submenu delegated to the plugin; uninstallPlugin
 * must remove exactly those eight and nil the submenu delegate. VisibilityMockPreferenceController
 * backs the default-registration and preference-observer calls. VisibilityMockAdium is a plain
 * NSObject installed via `adium = (id<AIAdium>)mockAdium`.
 */
@interface VisibilityMockMenuController : NSObject
@property(nonatomic, strong) NSMutableArray *addedItems;
@property(nonatomic, strong) NSMutableArray *removedItems;

- (void)addMenuItem:(NSMenuItem *)item toLocation:(NSInteger)location;
- (void)removeMenuItem:(NSMenuItem *)item;
@end

@implementation VisibilityMockMenuController
- (instancetype)init
{
	if ((self = [super init])) {
		_addedItems = [[NSMutableArray alloc] init];
		_removedItems = [[NSMutableArray alloc] init];
	}

	return self;
}

- (void)addMenuItem:(NSMenuItem *)item toLocation:(NSInteger)location
{
	[_addedItems addObject:item];
}

- (void)removeMenuItem:(NSMenuItem *)item
{
	[_removedItems addObject:item];
}
@end

@interface VisibilityMockPreferenceController : NSObject
@property(nonatomic, assign) NSUInteger unregisterObserverCount;

- (void)registerDefaults:(NSDictionary *)defaults forGroup:(NSString *)group;
- (void)registerPreferenceObserver:(id)observer forGroup:(NSString *)group;
- (void)unregisterPreferenceObserver:(id)observer;
@end

@implementation VisibilityMockPreferenceController
- (void)registerDefaults:(NSDictionary *)defaults forGroup:(NSString *)group
{}

- (void)registerPreferenceObserver:(id)observer forGroup:(NSString *)group
{}

- (void)unregisterPreferenceObserver:(id)observer
{
	_unregisterObserverCount++;
}
@end

@interface VisibilityMockAdium : NSObject
@property(nonatomic, strong) VisibilityMockMenuController *menuController;
@property(nonatomic, strong) VisibilityMockPreferenceController *preferenceController;
@end

@implementation VisibilityMockAdium
@end

@interface AIContactVisibilityControlPluginUninstallTest : XCTestCase
@end

@implementation AIContactVisibilityControlPluginUninstallTest

- (void)testUninstallNilsHideAccountsSubmenuDelegate
{
	VisibilityMockMenuController *mockMenuController = [[VisibilityMockMenuController alloc] init];
	VisibilityMockPreferenceController *mockPreferenceController = [[VisibilityMockPreferenceController alloc] init];
	VisibilityMockAdium *mockAdium = [[VisibilityMockAdium alloc] init];
	[mockAdium setMenuController:mockMenuController];
	[mockAdium setPreferenceController:mockPreferenceController];
	id<AIAdium> savedAdium = adium;

	adium = (id<AIAdium>)mockAdium;
	@try {
		AIContactVisibilityControlPlugin *plugin = [[AIContactVisibilityControlPlugin alloc] init];
		[plugin installPlugin];

		XCTAssertEqual([mockMenuController.addedItems count], (NSUInteger)8,
					   @"sanity: installPlugin registered eight view-toggle menu items");
		XCTAssertTrue([[plugin valueForKey:@"menu_hideAccounts"] delegate] == plugin,
					  @"sanity: the hide-accounts submenu is delegated to the plugin while installed");

		[plugin uninstallPlugin];

		XCTAssertEqual([mockMenuController.removedItems count], (NSUInteger)8,
					   @"uninstallPlugin removed a different number of menu items than installPlugin registered");
		XCTAssertNil([[plugin valueForKey:@"menu_hideAccounts"] delegate],
					 @"uninstallPlugin must nil the hide-accounts submenu delegate");
	} @finally {
		adium = savedAdium;
	}
}

@end
