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

#import "CBContactLastSeenPlugin.h"
#import <AdiumY/AIPlugin.h>
#import <XCTest/XCTest.h>

/*
 * Fakes for the teardown tests. installPlugin registers a contact-list tooltip entry
 * (registerContactListTooltipEntry:secondaryEntry:) and a list-object observer
 * (registerListObjectObserver:); uninstallPlugin must unregister exactly those. LastSeenMockInterfaceController
 * and MockContactObserverManager record the register/unregister calls; LastSeenMockAdium is a plain
 * NSObject (never formally conforming to <AIAdium>) installed via `adium = (id<AIAdium>)mockAdium`.
 *
 * AIContactObserverManager's +sharedManager is provided by
 * TestESUserIconHandlingPluginObserverRemoval.m in the same bundle; it returns the shared
 * AIObserverManagerSharedMock slot, set to the recording mock below. The shared `adium` global and
 * the AIPlugin class are provided by that same file — not redefined here.
 */
extern id AIObserverManagerSharedMock;
@interface LastSeenMockInterfaceController : NSObject
@property(nonatomic, strong) id registeredTooltipEntry;
@property(nonatomic, assign) BOOL registeredSecondaryEntry;
@property(nonatomic, strong) id unregisteredTooltipEntry;
@property(nonatomic, assign) BOOL unregisteredSecondaryEntry;
@property(nonatomic, assign) NSUInteger registerCount;
@property(nonatomic, assign) NSUInteger unregisterCount;

- (void)registerContactListTooltipEntry:(id)entry secondaryEntry:(BOOL)secondary;
- (void)unregisterContactListTooltipEntry:(id)entry secondaryEntry:(BOOL)secondary;
@end

@implementation LastSeenMockInterfaceController
- (void)registerContactListTooltipEntry:(id)entry secondaryEntry:(BOOL)secondary
{
	_registeredTooltipEntry = entry;
	_registeredSecondaryEntry = secondary;
	_registerCount++;
}

- (void)unregisterContactListTooltipEntry:(id)entry secondaryEntry:(BOOL)secondary
{
	_unregisteredTooltipEntry = entry;
	_unregisteredSecondaryEntry = secondary;
	_unregisterCount++;
}
@end

@interface MockContactObserverManager : NSObject
@property(nonatomic, strong) id registeredObserver;
@property(nonatomic, strong) id unregisteredObserver;
@property(nonatomic, assign) NSUInteger registerCount;
@property(nonatomic, assign) NSUInteger unregisterCount;

- (void)registerListObjectObserver:(id)observer;
- (void)unregisterListObjectObserver:(id)observer;
@end

@implementation MockContactObserverManager
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

@interface LastSeenMockAdium : NSObject
@property(nonatomic, strong) LastSeenMockInterfaceController *interfaceController;
@end

@implementation LastSeenMockAdium
@end

/*
 * The plugin is a single file covering both a contact-list tooltip entry (#206) and a list-object
 * observer (#207): the test asserts uninstallPlugin unregisters exactly what installPlugin registered,
 * with the same secondaryEntry flag installPlugin used.
 */
@interface CBContactLastSeenPluginObserverRemovalTest : XCTestCase
@end

@implementation CBContactLastSeenPluginObserverRemovalTest

- (void)testUninstallUnregistersTooltipEntryAndListObserver
{
	CBContactLastSeenPlugin *plugin = [[CBContactLastSeenPlugin alloc] init];
	LastSeenMockAdium *mockAdium = [[LastSeenMockAdium alloc] init];
	LastSeenMockInterfaceController *mockInterfaceController = [[LastSeenMockInterfaceController alloc] init];
	MockContactObserverManager *mockObserverManager = [[MockContactObserverManager alloc] init];
	id<AIAdium> savedAdium = adium;

	[mockAdium setInterfaceController:mockInterfaceController];
	AIObserverManagerSharedMock = mockObserverManager;
	adium = (id<AIAdium>)mockAdium;
	@try {
		[plugin installPlugin];

		XCTAssertEqual([mockInterfaceController registerCount], (NSUInteger)1,
					   @"sanity: installPlugin registered one tooltip entry");
		XCTAssertEqual([mockInterfaceController unregisterCount], (NSUInteger)0,
					   @"sanity: nothing unregistered at install time");
		XCTAssertEqual(mockInterfaceController.registeredTooltipEntry, plugin,
					   @"tooltip entry registered is the plugin itself");
		XCTAssertFalse(mockInterfaceController.registeredSecondaryEntry,
					   @"sanity: tooltip entry registered as a primary (non-secondary) entry");

		XCTAssertEqual([mockObserverManager registerCount], (NSUInteger)1,
					   @"sanity: installPlugin registered one list-object observer");
		XCTAssertEqual(mockObserverManager.registeredObserver, plugin,
					   @"list-object observer registered is the plugin itself");

		[plugin uninstallPlugin];

		XCTAssertEqual([mockInterfaceController unregisterCount], (NSUInteger)1,
					   @"uninstallPlugin unregisters the tooltip entry installPlugin registered");
		XCTAssertEqual(mockInterfaceController.unregisteredTooltipEntry, plugin,
					   @"tooltip entry unregistered is the plugin itself");
		XCTAssertFalse(mockInterfaceController.unregisteredSecondaryEntry,
					   @"tooltip unregister matches the secondaryEntry flag installPlugin used");

		XCTAssertEqual([mockObserverManager unregisterCount], (NSUInteger)1,
					   @"uninstallPlugin unregisters the list-object observer installPlugin registered");
		XCTAssertEqual(mockObserverManager.unregisteredObserver, plugin,
					   @"list-object observer unregistered is the plugin itself");
	} @finally {
		adium = savedAdium;
		AIObserverManagerSharedMock = nil;
	}
}

@end
