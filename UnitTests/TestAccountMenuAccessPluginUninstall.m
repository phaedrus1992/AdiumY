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
 * Link shims for the standalone test target. AIGuestAccountWindowController is sent by class name in
 * AIAccountMenuAccessPlugin.m ([AIGuestAccountWindowController showGuestAccountWindow]), emitting the
 * _OBJC_CLASS_$_AIGuestAccountWindowController symbol no linked framework provides, so it gets an empty
 * implementation here. The AIAccountMenu shim (accountMenuWithDelegate:submenuType:showTitleVerbs:), the
 * shared `adium` global, and the AIPlugin class come from TestAIStateMenuPluginUninstall.m and
 * TestESUserIconHandlingPluginObserverRemoval.m in the same bundle — not redefined here.
 * AIAccountMenuAccessPlugin's own @implementation (wired into this bundle) provides its class; the relaxed
 * @interface below declares the delegate callback this test drives.
 */
@protocol AIAdium;
extern id<AIAdium> adium;

@interface AIPlugin : NSObject
- (void)installPlugin;
- (void)uninstallPlugin;
@end

@interface AIAccountMenuAccessPlugin : AIPlugin
- (void)accountMenu:(id)inAccountMenu didRebuildMenuItems:(NSArray *)menuItems;
@end

@interface AIGuestAccountWindowController : NSObject
+ (void)showGuestAccountWindow;
@end

@implementation AIGuestAccountWindowController
+ (void)showGuestAccountWindow
{}
@end

@interface AccountMenuAccessMockMenuController : NSObject
@property(nonatomic, strong) NSMutableArray *addedItems;
@property(nonatomic, strong) NSMutableArray *removedItems;

- (void)addMenuItem:(NSMenuItem *)menuItem toLocation:(NSInteger)location;
- (void)removeMenuItem:(NSMenuItem *)menuItem;
@end

@implementation AccountMenuAccessMockMenuController
- (instancetype)init
{
	if ((self = [super init])) {
		_addedItems = [[NSMutableArray alloc] init];
		_removedItems = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)addMenuItem:(NSMenuItem *)menuItem toLocation:(NSInteger)location
{
	[_addedItems addObject:menuItem];
}

- (void)removeMenuItem:(NSMenuItem *)menuItem
{
	[_removedItems addObject:menuItem];
}
@end

@interface AccountMenuAccessMockAdium : NSObject
@property(nonatomic, strong) AccountMenuAccessMockMenuController *menuController;
@end

@implementation AccountMenuAccessMockAdium
@end

@interface AccountMenuAccessPluginUninstallTest : XCTestCase
@end

@implementation AccountMenuAccessPluginUninstallTest

// installPlugin registers the guest account item and accountMenu:didRebuildMenuItems: registers one item
// per account; uninstallPlugin must remove every registered item and drop the account menu so no delegate
// or menu items dangle on an uninstalled plugin (#218).
- (void)testUninstallRemovesAllRegisteredMenuItems
{
	AccountMenuAccessMockMenuController *mockMenuController = [[AccountMenuAccessMockMenuController alloc] init];
	AccountMenuAccessMockAdium *mockAdium = [[AccountMenuAccessMockAdium alloc] init];
	[mockAdium setMenuController:mockMenuController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		AIAccountMenuAccessPlugin *plugin = [[AIAccountMenuAccessPlugin alloc] init];
		[plugin installPlugin];

		XCTAssertEqual([mockMenuController.addedItems count], (NSUInteger)1,
					   @"sanity: installPlugin registered the guest account menu item");
		NSMenuItem *guestMenuItem = [plugin valueForKey:@"guestAccountMenuItem"];
		XCTAssertNotNil(guestMenuItem, @"installPlugin must keep the guest menu item it registered");
		XCTAssertTrue([mockMenuController.addedItems containsObject:guestMenuItem],
					  @"the item installPlugin registered must be the one it stored");

		NSMenuItem *accountItemA = [[NSMenuItem alloc] initWithTitle:@"A" action:NULL keyEquivalent:@""];
		NSMenuItem *accountItemB = [[NSMenuItem alloc] initWithTitle:@"B" action:NULL keyEquivalent:@""];
		[plugin accountMenu:nil didRebuildMenuItems:@[ accountItemA, accountItemB ]];

		XCTAssertEqual([mockMenuController.addedItems count], (NSUInteger)3,
					   @"sanity: guest item plus two account items = three registered items");

		[plugin uninstallPlugin];

		XCTAssertEqual([mockMenuController.removedItems count], (NSUInteger)3,
					   @"uninstallPlugin must remove the guest item and every account item it registered");
		XCTAssertTrue([mockMenuController.removedItems containsObject:guestMenuItem],
					  @"uninstallPlugin must remove the guest account menu item");
		XCTAssertTrue([mockMenuController.removedItems containsObject:accountItemA],
					  @"uninstallPlugin must remove each account menu item it registered");
		XCTAssertTrue([mockMenuController.removedItems containsObject:accountItemB],
					  @"uninstallPlugin must remove each account menu item it registered");

		XCTAssertNil([plugin valueForKey:@"guestAccountMenuItem"],
					 @"uninstallPlugin must clear the guest account menu item");
		XCTAssertNil([plugin valueForKey:@"installedMenuItems"],
					 @"uninstallPlugin must clear the installed account menu items");
		XCTAssertNil([plugin valueForKey:@"accountMenu"],
					 @"uninstallPlugin must drop the account menu so no delegate dangles");
	} @finally {
		adium = savedAdium;
	}
}

@end
