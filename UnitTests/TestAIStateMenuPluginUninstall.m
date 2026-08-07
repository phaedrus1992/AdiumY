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
 * Link shims for the standalone test target (see the note in
 * TestESUserIconHandlingPluginObserverRemoval.m). AIStateMenuPlugin's TU references these class
 * symbols; the test target links no Adium.framework binary, so each gets an empty implementation
 * here. The shared `adium` global, the AIPlugin class, and AIContactObserverManager +sharedManager
 * come from TestESUserIconHandlingPluginObserverRemoval.m in the same bundle — not redefined here.
 */
@protocol AIAdium;
extern id<AIAdium> adium;

@interface AIPlugin : NSObject
- (void)installPlugin;
- (void)uninstallPlugin;
@end

@interface AIAccountMenu : NSObject
+ (id)accountMenuWithDelegate:(id)delegate submenuType:(NSInteger)submenuType showTitleVerbs:(BOOL)showTitleVerbs;
@end

@implementation AIAccountMenu
+ (id)accountMenuWithDelegate:(id)delegate submenuType:(NSInteger)submenuType showTitleVerbs:(BOOL)showTitleVerbs
{
	return nil;
}
@end

@interface AIStatusMenu : NSObject
+ (id)statusMenuWithDelegate:(id)delegate;
@end

@implementation AIStatusMenu
+ (id)statusMenuWithDelegate:(id)delegate
{
	return nil;
}
@end

@interface AISocialNetworkingStatusMenu : NSObject
+ (id)socialNetworkingSubmenuItem;
@end

@implementation AISocialNetworkingStatusMenu
+ (id)socialNetworkingSubmenuItem
{
	return nil;
}
@end

@interface AIAccount : NSObject
@end

@implementation AIAccount
@end

/*
 * Relaxed declaration of the class under test (its real @implementation ships in the bundle and
 * imports the real Adium headers). installPlugin/uninstallPlugin are inherited from AIPlugin.
 */
@interface AIStateMenuPlugin : AIPlugin
- (void)statusMenu:(AIStatusMenu *)inStatusMenu didRebuildStatusMenuItems:(NSArray *)menuItemArray;
- (void)accountMenu:(AIAccountMenu *)inAccountMenu didRebuildMenuItems:(NSArray *)menuItems;
@end

/*
 * Recording fakes. installPlugin only registers a finish-loading observer; adiumFinishedLaunching:
 * (fired by the AIApplicationDidFinishLoadingNotification posted below) registers the dock status
 * menu item and a list-object observer. uninstallPlugin must undo all three. AIObserverManagerSharedMock
 * is the shared AIContactObserverManager singleton slot defined in
 * TestESUserIconHandlingPluginObserverRemoval.m.
 */
extern id AIObserverManagerSharedMock;

@interface StateMenuMockMenuController : NSObject
@property(nonatomic, assign) NSUInteger addCount;
@property(nonatomic, assign) NSUInteger removeCount;
@property(nonatomic, strong) NSMutableArray *addedItems;
@property(nonatomic, strong) NSMutableArray *removedItems;

- (void)addMenuItem:(NSMenuItem *)item toLocation:(NSInteger)location;
- (void)removeMenuItem:(NSMenuItem *)item;
@end

@implementation StateMenuMockMenuController
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
	_addCount++;
	[_addedItems addObject:item];
}

- (void)removeMenuItem:(NSMenuItem *)item
{
	_removeCount++;
	[_removedItems addObject:item];
}
@end

@interface StateMenuMockObserverManager : NSObject
@property(nonatomic, strong) id registeredObserver;
@property(nonatomic, strong) id unregisteredObserver;
@property(nonatomic, assign) NSUInteger registerCount;
@property(nonatomic, assign) NSUInteger unregisterCount;

- (void)registerListObjectObserver:(id)observer;
- (void)unregisterListObjectObserver:(id)observer;
@end

@implementation StateMenuMockObserverManager
- (void)registerListObjectObserver:(id)observer
{
	_registeredObserver = observer;
	_registerCount++;
}

- (void)unregisterListObjectObserver:(id)observer
{
	_unregisteredObserver = observer;
	_unregisterCount++;
}
@end

/*
 * updateKeyEquivalents (called at the end of statusMenu:didRebuildStatusMenuItems:) reads
 * adium.statusController; a status-menu rebuild must not crash on an unrecognized selector.
 */
@interface StateMenuMockStatusController : NSObject
- (NSInteger)activeStatusTypeTreatingInvisibleAsAway:(BOOL)invisible;
- (id)defaultInitialStatusState;
@end

@implementation StateMenuMockStatusController
- (NSInteger)activeStatusTypeTreatingInvisibleAsAway:(BOOL)invisible
{
	return 0; // AIAvailableStatusType
}

- (id)defaultInitialStatusState
{
	return nil;
}
@end

@interface StateMenuMockAdium : NSObject
@property(nonatomic, strong) StateMenuMockMenuController *menuController;
@property(nonatomic, strong) StateMenuMockStatusController *statusController;
@end

@implementation StateMenuMockAdium
@end

@interface AIStateMenuPluginUninstallTest : XCTestCase
@end

@implementation AIStateMenuPluginUninstallTest

- (void)testUninstallUnregistersListObjectObserver
{
	StateMenuMockMenuController *mockMenuController = [[StateMenuMockMenuController alloc] init];
	StateMenuMockObserverManager *mockObserverManager = [[StateMenuMockObserverManager alloc] init];
	StateMenuMockStatusController *mockStatusController = [[StateMenuMockStatusController alloc] init];
	StateMenuMockAdium *mockAdium = [[StateMenuMockAdium alloc] init];
	[mockAdium setMenuController:mockMenuController];
	[mockAdium setStatusController:mockStatusController];
	id<AIAdium> savedAdium = adium;
	id savedObserverManagerMock = AIObserverManagerSharedMock;

	AIObserverManagerSharedMock = mockObserverManager;
	adium = (id<AIAdium>)mockAdium;
	@try {
		AIStateMenuPlugin *plugin = [[AIStateMenuPlugin alloc] init];
		[plugin installPlugin];

		// installPlugin only registers the finish-loading observer; the dock menu item and the
		// list-object observer appear once the finish-loading notification fires.
		[[NSNotificationCenter defaultCenter] postNotificationName:@"AIApplicationDidFinishLoading" object:nil];

		XCTAssertEqual([mockMenuController addCount], (NSUInteger)1,
					   @"sanity: adiumFinishedLaunching: registered one dock status menu item");
		XCTAssertEqual([mockObserverManager registerCount], (NSUInteger)1,
					   @"sanity: adiumFinishedLaunching: registered one list-object observer");
		XCTAssertEqual(mockObserverManager.registeredObserver, plugin,
					   @"sanity: the registered list-object observer is the plugin itself");

		// Capture the item before uninstall — uninstallPlugin nils dockStatusMenuRoot.
		NSMenuItem *registeredDockItem = [plugin valueForKey:@"dockStatusMenuRoot"];

		[plugin uninstallPlugin];

		XCTAssertEqual([mockObserverManager unregisterCount], (NSUInteger)1,
					   @"uninstallPlugin did not unregister the list-object observer");
		XCTAssertEqual(mockObserverManager.unregisteredObserver, plugin,
					   @"the list-object observer unregistered is the plugin itself");
		XCTAssertEqual([mockMenuController removeCount], (NSUInteger)1,
					   @"uninstallPlugin did not remove the dock status menu item");
		XCTAssertTrue([mockMenuController.removedItems containsObject:registeredDockItem],
					  @"the dock status menu item removed is the one installPlugin registered");
	} @finally {
		adium = savedAdium;
		AIObserverManagerSharedMock = savedObserverManagerMock;
	}
}

- (void)testUninstallRemovesStatusAndAccountMenuItems
{
	StateMenuMockMenuController *mockMenuController = [[StateMenuMockMenuController alloc] init];
	StateMenuMockObserverManager *mockObserverManager = [[StateMenuMockObserverManager alloc] init];
	StateMenuMockStatusController *mockStatusController = [[StateMenuMockStatusController alloc] init];
	StateMenuMockAdium *mockAdium = [[StateMenuMockAdium alloc] init];
	[mockAdium setMenuController:mockMenuController];
	[mockAdium setStatusController:mockStatusController];
	id<AIAdium> savedAdium = adium;
	id savedObserverManagerMock = AIObserverManagerSharedMock;

	AIObserverManagerSharedMock = mockObserverManager;
	adium = (id<AIAdium>)mockAdium;
	@try {
		AIStateMenuPlugin *plugin = [[AIStateMenuPlugin alloc] init];
		[plugin installPlugin];

		[[NSNotificationCenter defaultCenter] postNotificationName:@"AIApplicationDidFinishLoading" object:nil];

		// Capture the item before uninstall — uninstallPlugin nils dockStatusMenuRoot.
		NSMenuItem *registeredDockItem = [plugin valueForKey:@"dockStatusMenuRoot"];

		// Reproduce the delegate callbacks that register the status and account menu items at runtime.
		NSMenuItem *statusItem = [[NSMenuItem alloc] initWithTitle:@"Status" action:nil keyEquivalent:@""];
		NSMenuItem *accountItem = [[NSMenuItem alloc] initWithTitle:@"Account" action:nil keyEquivalent:@""];
		[plugin statusMenu:nil didRebuildStatusMenuItems:@[ statusItem ]];
		[plugin accountMenu:nil didRebuildMenuItems:@[ accountItem ]];

		XCTAssertEqual([mockMenuController addCount], (NSUInteger)3,
					   @"sanity: dock status root + status item + account item = three registered menu items");

		[plugin uninstallPlugin];

		XCTAssertEqual(
			[mockMenuController removeCount], (NSUInteger)3,
			@"uninstallPlugin must remove the dock status root and every status/account menu item it registered");
		XCTAssertTrue([mockMenuController.removedItems containsObject:registeredDockItem],
					  @"uninstallPlugin must remove the dock status menu item");
		XCTAssertTrue([mockMenuController.removedItems containsObject:statusItem],
					  @"uninstallPlugin must remove the status menu items in currentMenuItemArray");
		XCTAssertTrue([mockMenuController.removedItems containsObject:accountItem],
					  @"uninstallPlugin must remove the account menu items in installedMenuItems");
	} @finally {
		adium = savedAdium;
		AIObserverManagerSharedMock = savedObserverManagerMock;
	}
}

@end
