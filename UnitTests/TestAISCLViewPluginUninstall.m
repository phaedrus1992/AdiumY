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

// clang-format off
#import <AdiumY/AIAdiumProtocol.h>
#import <AdiumY/AIPlugin.h>
#import <AdiumY/AISharedAdium.h>
// clang-format on

/*
 * Bare @interface only — the wired AISCLViewPlugin.m provides the class symbol and the real
 * installPlugin/uninstallPlugin bodies. installPlugin/uninstallPlugin are declared on AIPlugin,
 * which this declaration inherits, so no method redeclaration is needed.
 */
@interface AISCLViewPlugin : AIPlugin
@end

/*
 * Link shim — the wired AISCLViewPlugin.m references AIBorderlessListWindowController by name in
 * detachContactList:, which emits a _OBJC_CLASS_$ symbol no linked framework provides. The path is
 * not executed by install/uninstall, so an empty implementation satisfies the linker.
 */
@interface AIBorderlessListWindowController : NSObject
@end

@implementation AIBorderlessListWindowController
@end

/*
 * Mocks for the adium services installPlugin/uninstallPlugin read. interfaceController gets the
 * registerContactListController: call at install and — per #242 — must get the matching
 * unregisterContactListController: at uninstall. menuController absorbs the menu item additions
 * and removals; preferenceController the defaults + observer registration. Named uniquely per test
 * bundle (the same generic mock names exist in the pre-existing ESUserIconHandling test).
 */
@interface SCLViewMockInterfaceController : NSObject
@property(nonatomic, assign) NSUInteger registerContactListControllerCount;
@property(nonatomic, assign) NSUInteger unregisterContactListControllerCount;
- (void)registerContactListController:(id)controller;
- (void)unregisterContactListController:(id)controller;
@end

@implementation SCLViewMockInterfaceController
- (void)registerContactListController:(id)controller
{
	_registerContactListControllerCount++;
}

- (void)unregisterContactListController:(id)controller
{
	_unregisterContactListControllerCount++;
}
@end

@interface MockMenuController : NSObject
@property(nonatomic, assign) NSUInteger addMenuItemCount;
@property(nonatomic, assign) NSUInteger removeMenuItemCount;
- (void)addContextualMenuItem:(NSMenuItem *)menuItem toLocation:(NSUInteger)location;
- (void)addMenuItem:(NSMenuItem *)menuItem toLocation:(NSUInteger)location;
- (void)removeContextualMenuItem:(NSMenuItem *)menuItem;
- (void)removeMenuItem:(NSMenuItem *)menuItem;
@end

@implementation MockMenuController
- (void)addContextualMenuItem:(NSMenuItem *)menuItem toLocation:(NSUInteger)location
{
	_addMenuItemCount++;
}

- (void)addMenuItem:(NSMenuItem *)menuItem toLocation:(NSUInteger)location
{
	_addMenuItemCount++;
}

- (void)removeContextualMenuItem:(NSMenuItem *)menuItem
{
	_removeMenuItemCount++;
}

- (void)removeMenuItem:(NSMenuItem *)menuItem
{
	_removeMenuItemCount++;
}
@end

@interface SCLViewMockPreferenceController : NSObject
@property(nonatomic, assign) NSUInteger registerDefaultsCount;
@property(nonatomic, assign) NSUInteger registerObserverCount;
@property(nonatomic, assign) NSUInteger unregisterObserverCount;
- (void)registerDefaults:(NSDictionary *)defaults forGroup:(NSString *)group;
- (void)registerPreferenceObserver:(id)observer forGroup:(NSString *)group;
- (void)unregisterPreferenceObserver:(id)observer;
@end

@implementation SCLViewMockPreferenceController
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
@end

@interface SCLViewMockAdium : NSObject
@property(nonatomic, strong) SCLViewMockInterfaceController *interfaceController;
@property(nonatomic, strong) MockMenuController *menuController;
@property(nonatomic, strong) SCLViewMockPreferenceController *preferenceController;
@end

@implementation SCLViewMockAdium
@end

@interface AISCLViewPluginUninstallTest : XCTestCase
@end

@implementation AISCLViewPluginUninstallTest

// installPlugin registers the plugin itself as a contact list controller; uninstallPlugin must
// unregister it, or the uninstalled plugin remains the interface's contact list controller (#242).
- (void)testUninstallUnregistersContactListController
{
	SCLViewMockInterfaceController *interfaceController = [[SCLViewMockInterfaceController alloc] init];
	MockMenuController *menuController = [[MockMenuController alloc] init];
	SCLViewMockPreferenceController *preferenceController = [[SCLViewMockPreferenceController alloc] init];
	SCLViewMockAdium *mockAdium = [[SCLViewMockAdium alloc] init];
	mockAdium.interfaceController = interfaceController;
	mockAdium.menuController = menuController;
	mockAdium.preferenceController = preferenceController;

	id<AIAdium> savedAdium = adium;
	@try {
		adium = (id<AIAdium>)mockAdium;

		AISCLViewPlugin *plugin = [[AISCLViewPlugin alloc] init];
		[plugin installPlugin];

		XCTAssertEqual(interfaceController.registerContactListControllerCount, (NSUInteger)1,
					   @"sanity: installPlugin registers the plugin as a contact list controller");

		[plugin uninstallPlugin];

		XCTAssertEqual(interfaceController.unregisterContactListControllerCount, (NSUInteger)1,
					   @"uninstallPlugin did not unregister the contact list controller it registered");
		XCTAssertEqual(preferenceController.unregisterObserverCount, (NSUInteger)1,
					   @"sanity: uninstallPlugin still unregisters the preference observer");
		XCTAssertEqual(menuController.removeMenuItemCount, (NSUInteger)6,
					   @"sanity: uninstallPlugin still removes the menu items it added");
	} @finally {
		adium = savedAdium;
	}
}

@end
