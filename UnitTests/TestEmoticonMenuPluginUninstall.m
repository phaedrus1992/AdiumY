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
 * Link shims for the standalone test target. BGEmoticonMenuPlugin's own @implementation (wired into this
 * bundle) provides its class; the relaxed @interface below declares only the surface this test drives. The
 * shared `adium` global and the AIPlugin class are provided by TestESUserIconHandlingPluginObserverRemoval.m
 * in the same bundle — not redefined here. The mocks record the menu/toolbar/preference registrations
 * installPlugin makes so uninstallPlugin's teardown is observable.
 */
@protocol AIAdium;
extern id<AIAdium> adium;

@interface AIPlugin : NSObject
- (void)installPlugin;
- (void)uninstallPlugin;
@end

@interface BGEmoticonMenuPlugin : AIPlugin
@end

@interface EmoticonMockMenuController : NSObject
@property(nonatomic, strong) NSMutableArray *addedMenuItems;
@property(nonatomic, strong) NSMutableArray *addedContextualMenuItems;
@property(nonatomic, strong) NSMutableArray *removedMenuItems;
@property(nonatomic, strong) NSMutableArray *removedContextualMenuItems;

- (void)addMenuItem:(NSMenuItem *)menuItem toLocation:(NSInteger)location;
- (void)addContextualMenuItem:(NSMenuItem *)menuItem toLocation:(NSInteger)location;
- (void)removeMenuItem:(NSMenuItem *)menuItem;
- (void)removeContextualMenuItem:(NSMenuItem *)menuItem;
@end

@implementation EmoticonMockMenuController
- (instancetype)init
{
	if ((self = [super init])) {
		_addedMenuItems = [[NSMutableArray alloc] init];
		_addedContextualMenuItems = [[NSMutableArray alloc] init];
		_removedMenuItems = [[NSMutableArray alloc] init];
		_removedContextualMenuItems = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)addMenuItem:(NSMenuItem *)menuItem toLocation:(NSInteger)location
{
	[_addedMenuItems addObject:menuItem];
}

- (void)addContextualMenuItem:(NSMenuItem *)menuItem toLocation:(NSInteger)location
{
	[_addedContextualMenuItems addObject:menuItem];
}

- (void)removeMenuItem:(NSMenuItem *)menuItem
{
	[_removedMenuItems addObject:menuItem];
}

- (void)removeContextualMenuItem:(NSMenuItem *)menuItem
{
	[_removedContextualMenuItems addObject:menuItem];
}
@end

@interface EmoticonMockToolbarController : NSObject
@property(nonatomic, assign) NSUInteger registerCount;
@property(nonatomic, assign) NSUInteger unregisterCount;
@property(nonatomic, strong) NSToolbarItem *registeredItem;
@property(nonatomic, copy) NSString *registeredType;

- (void)registerToolbarItem:(NSToolbarItem *)toolbarItem forToolbarType:(NSString *)toolbarType;
- (void)unregisterToolbarItem:(NSToolbarItem *)toolbarItem forToolbarType:(NSString *)toolbarType;
@end

@implementation EmoticonMockToolbarController
- (void)registerToolbarItem:(NSToolbarItem *)toolbarItem forToolbarType:(NSString *)toolbarType
{
	_registerCount++;
	_registeredItem = toolbarItem;
	_registeredType = toolbarType;
}

- (void)unregisterToolbarItem:(NSToolbarItem *)toolbarItem forToolbarType:(NSString *)toolbarType
{
	_unregisterCount++;
}
@end

@interface EmoticonMockPreferenceController : NSObject
@property(nonatomic, assign) NSUInteger unregisterObserverCount;

- (void)unregisterPreferenceObserver:(id)observer;
@end

@implementation EmoticonMockPreferenceController
- (void)unregisterPreferenceObserver:(id)observer
{
	_unregisterObserverCount++;
}
@end

@interface EmoticonMockAdium : NSObject
@property(nonatomic, strong) EmoticonMockMenuController *menuController;
@property(nonatomic, strong) EmoticonMockToolbarController *toolbarController;
@property(nonatomic, strong) EmoticonMockPreferenceController *preferenceController;
@end

@implementation EmoticonMockAdium
@end

@interface EmoticonMenuPluginUninstallTest : XCTestCase
@end

@implementation EmoticonMenuPluginUninstallTest

// installPlugin keeps BGEmoticonMenuPlugin as the delegate of both submenus and registers a toolbar item;
// uninstallPlugin must nil the delegates and unregister everything, or an uninstalled plugin stays
// reachable as a menu delegate and registered toolbar consumer (#221).
- (void)testUninstallDropsSubmenuDelegatesAndUnregistersRegistrations
{
	EmoticonMockMenuController *mockMenuController = [[EmoticonMockMenuController alloc] init];
	EmoticonMockToolbarController *mockToolbarController = [[EmoticonMockToolbarController alloc] init];
	EmoticonMockPreferenceController *mockPreferenceController = [[EmoticonMockPreferenceController alloc] init];
	EmoticonMockAdium *mockAdium = [[EmoticonMockAdium alloc] init];
	[mockAdium setMenuController:mockMenuController];
	[mockAdium setToolbarController:mockToolbarController];
	[mockAdium setPreferenceController:mockPreferenceController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		BGEmoticonMenuPlugin *plugin = [[BGEmoticonMenuPlugin alloc] init];
		[plugin installPlugin];

		XCTAssertEqual([mockMenuController.addedMenuItems count], (NSUInteger)1,
					   @"sanity: installPlugin registered the emoticon menu item");
		XCTAssertEqual([mockMenuController.addedContextualMenuItems count], (NSUInteger)1,
					   @"sanity: installPlugin registered the contextual emoticon menu item");
		XCTAssertEqual([mockToolbarController registerCount], (NSUInteger)1,
					   @"sanity: installPlugin registered the toolbar item");

		NSMenuItem *quickMenuItem = [mockMenuController.addedMenuItems firstObject];
		NSMenuItem *quickContextualMenuItem = [mockMenuController.addedContextualMenuItems firstObject];
		XCTAssertNotNil(quickMenuItem, @"installPlugin must add a main emoticon menu item");
		XCTAssertNotNil(quickContextualMenuItem, @"installPlugin must add a contextual emoticon menu item");

		XCTAssertEqual((id)quickMenuItem.submenu.delegate, plugin,
					   @"the main emoticon submenu must use the plugin as its delegate while installed");
		XCTAssertEqual((id)quickContextualMenuItem.submenu.delegate, plugin,
					   @"the contextual emoticon submenu must use the plugin as its delegate while installed");

		[plugin uninstallPlugin];

		XCTAssertNil(quickMenuItem.submenu.delegate,
					 @"uninstallPlugin must nil the main submenu delegate so none dangles");
		XCTAssertNil(quickContextualMenuItem.submenu.delegate,
					 @"uninstallPlugin must nil the contextual submenu delegate so none dangles");

		XCTAssertEqual([mockMenuController.removedMenuItems count], (NSUInteger)1,
					   @"uninstallPlugin must remove the main emoticon menu item");
		XCTAssertEqual([mockMenuController.removedContextualMenuItems count], (NSUInteger)1,
					   @"uninstallPlugin must remove the contextual emoticon menu item");
		XCTAssertEqual([mockToolbarController unregisterCount], (NSUInteger)1,
					   @"uninstallPlugin must unregister the toolbar item it registered");
		XCTAssertEqualObjects([mockToolbarController registeredType], @"TextEntry",
							  @"uninstallPlugin must unregister the toolbar item from the TextEntry toolbar");
		XCTAssertEqual([mockPreferenceController unregisterObserverCount], (NSUInteger)1,
					   @"uninstallPlugin must unregister the preference observer");
	} @finally {
		adium = savedAdium;
	}
}

@end
