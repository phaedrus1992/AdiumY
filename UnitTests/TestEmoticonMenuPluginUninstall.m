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
 * in the same bundle — not redefined here. The mocks record the menu/toolbar registrations
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

@interface EmoticonMockAdium : NSObject
@property(nonatomic, strong) EmoticonMockMenuController *menuController;
@property(nonatomic, strong) EmoticonMockToolbarController *toolbarController;
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
	EmoticonMockAdium *mockAdium = [[EmoticonMockAdium alloc] init];
	[mockAdium setMenuController:mockMenuController];
	[mockAdium setToolbarController:mockToolbarController];

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
	} @finally {
		adium = savedAdium;
	}
}

// installPlugin attaches itself as the delegate of the emoticon menu it sets up on a live toolbar item
// (driven by NSToolbarWillAddItemNotification); uninstallPlugin must nil those delegates and drop the
// tracked items so an uninstalled plugin leaves no dangling toolbar menu delegate (#221).
- (void)testUninstallDropsToolbarMenuDelegates
{
	EmoticonMockMenuController *mockMenuController = [[EmoticonMockMenuController alloc] init];
	EmoticonMockToolbarController *mockToolbarController = [[EmoticonMockToolbarController alloc] init];
	EmoticonMockAdium *mockAdium = [[EmoticonMockAdium alloc] init];
	[mockAdium setMenuController:mockMenuController];
	[mockAdium setToolbarController:mockToolbarController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		BGEmoticonMenuPlugin *plugin = [[BGEmoticonMenuPlugin alloc] init];
		[plugin installPlugin];

		// The plugin only reacts to toolbar items whose identifier is TOOLBAR_EMOTICON_IDENTIFIER
		// (@"InsertEmoticon", a private #define in the plugin's own TU — assert the literal here).
		NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:@"InsertEmoticon"];
		NSView *view = [[NSView alloc] initWithFrame:NSZeroRect];
		[toolbarItem setView:view];

		[[NSNotificationCenter defaultCenter] postNotificationName:NSToolbarWillAddItemNotification
															object:nil
														  userInfo:@{@"item" : toolbarItem}];

		// installPlugin replaces the view's menu and the menu-form's submenu with a single emoticon menu
		// (delegate = itself); capture that menu to verify uninstall nils its delegate.
		NSMenu *emoticonMenu = [[toolbarItem view] menu];
		XCTAssertNotNil(emoticonMenu, @"sanity: installPlugin attached an emoticon menu to the toolbar view");
		XCTAssertEqual((id)[emoticonMenu delegate], plugin,
					   @"sanity: installPlugin set itself as the toolbar emoticon menu delegate");
		XCTAssertEqual((id)[[[toolbarItem menuFormRepresentation] submenu] delegate], plugin,
					   @"sanity: installPlugin set itself as the toolbar menu-form delegate");
		XCTAssertEqual([[[plugin valueForKey:@"toolbarItems"] allObjects] count], (NSUInteger)1,
					   @"sanity: installPlugin tracks the live toolbar item");

		[plugin uninstallPlugin];

		XCTAssertNil([emoticonMenu delegate],
					 @"uninstallPlugin must nil the toolbar emoticon menu delegate so none dangles");
		XCTAssertNil([[[toolbarItem menuFormRepresentation] submenu] delegate],
					 @"uninstallPlugin must nil the toolbar menu-form delegate so none dangles");
		XCTAssertEqual([[[plugin valueForKey:@"toolbarItems"] allObjects] count], (NSUInteger)0,
					   @"uninstallPlugin must drop its tracked toolbar items");
	} @finally {
		adium = savedAdium;
	}
}

@end
