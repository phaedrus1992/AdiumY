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

#import "AIContactIdlePlugin.h"
#import <AdiumY/AIListObject.h>
#import <XCTest/XCTest.h>

/*
 * The shared `adium` global, the AIPlugin class, AIContactObserverManager +sharedManager, and the
 * empty AIMetaContact class come from TestESUserIconHandlingPluginObserverRemoval.m / TestMenuPluginUninstall.m
 * in the same bundle — not redefined here.
 */
@protocol AIAdium;
extern id<AIAdium> adium;
extern id AIObserverManagerSharedMock;

/*
 * A plain NSObject — deliberately NOT an AIMetaContact — so the plugin's updateListObject:
 * `![inObject isKindOfClass:[AIMetaContact class]]` guard lets it through and it acquires an
 * idleSince value, which is what starts the repeating idle-update timer.
 */
@interface IdleMockListObject : NSObject
@property(nonatomic, assign) BOOL isIdle;

- (id)valueForProperty:(NSString *)property;
- (void)setValue:(id)value forProperty:(NSString *)property notify:(NSInteger)notify;
- (void)notifyOfChangedPropertiesSilently:(BOOL)silent;
@end

@implementation IdleMockListObject
- (instancetype)init
{
	if ((self = [super init])) {
		_isIdle = YES;
	}

	return self;
}

- (id)valueForProperty:(NSString *)property
{
	if ([property isEqualToString:@"idleSince"]) {
		return self.isIdle ? [NSDate date] : nil;
	}

	return nil;
}

- (void)setValue:(id)value forProperty:(NSString *)property notify:(NSInteger)notify
{}

- (void)notifyOfChangedPropertiesSilently:(BOOL)silent
{}
@end

@interface IdleMockObserverManager : NSObject
@property(nonatomic, assign) NSUInteger registerCount;
@property(nonatomic, assign) NSUInteger unregisterCount;

- (void)registerListObjectObserver:(id)observer;
- (void)unregisterListObjectObserver:(id)observer;
- (void)delayListObjectNotifications;
- (void)endListObjectNotificationsDelay;
@end

@implementation IdleMockObserverManager
- (void)registerListObjectObserver:(id)observer
{
	_registerCount++;
}

- (void)unregisterListObjectObserver:(id)observer
{
	_unregisterCount++;
}

- (void)delayListObjectNotifications
{}

- (void)endListObjectNotificationsDelay
{}
@end

@interface IdleMockInterfaceController : NSObject
@property(nonatomic, assign) NSUInteger registerCount;
@property(nonatomic, assign) NSUInteger unregisterCount;

- (void)registerContactListTooltipEntry:(id)entry secondaryEntry:(BOOL)secondary;
- (void)unregisterContactListTooltipEntry:(id)entry secondaryEntry:(BOOL)secondary;
@end

@implementation IdleMockInterfaceController
- (void)registerContactListTooltipEntry:(id)entry secondaryEntry:(BOOL)secondary
{
	_registerCount++;
}

- (void)unregisterContactListTooltipEntry:(id)entry secondaryEntry:(BOOL)secondary
{
	_unregisterCount++;
}
@end

@interface IdleMockAdium : NSObject
@property(nonatomic, strong) IdleMockInterfaceController *interfaceController;
@end

@implementation IdleMockAdium
@end

@interface AIContactIdlePluginUninstallTest : XCTestCase
@end

@implementation AIContactIdlePluginUninstallTest

- (void)testUninstallInvalidatesIdleUpdateTimer
{
	IdleMockListObject *mockObject = [[IdleMockListObject alloc] init];
	IdleMockObserverManager *mockObserverManager = [[IdleMockObserverManager alloc] init];
	IdleMockInterfaceController *mockInterfaceController = [[IdleMockInterfaceController alloc] init];
	IdleMockAdium *mockAdium = [[IdleMockAdium alloc] init];
	[mockAdium setInterfaceController:mockInterfaceController];
	id<AIAdium> savedAdium = adium;
	id savedObserverManagerMock = AIObserverManagerSharedMock;
	AIContactIdlePlugin *plugin = nil;

	AIObserverManagerSharedMock = mockObserverManager;
	adium = (id<AIAdium>)mockAdium;
	@try {
		plugin = [[AIContactIdlePlugin alloc] init];
		[plugin installPlugin];

		// A contact with an idleSince property makes updateListObject: start the repeating idle timer.
		[plugin updateListObject:(AIListObject *)mockObject keys:nil silent:YES];

		NSTimer *idleObjectTimer = [plugin valueForKey:@"idleObjectTimer"];
		XCTAssertNotNil(idleObjectTimer, @"sanity: updateListObject: started the idle timer for an idle contact");
		XCTAssertTrue([idleObjectTimer isValid], @"sanity: the idle timer is scheduled and valid while installed");

		[plugin uninstallPlugin];

		XCTAssertFalse([idleObjectTimer isValid],
					   @"uninstallPlugin must invalidate the idle-update timer so it cannot fire after uninstall");
		XCTAssertNil([plugin valueForKey:@"idleObjectArray"], @"uninstallPlugin must nil the idle-object array ivar");
		XCTAssertEqual([mockInterfaceController unregisterCount], (NSUInteger)1,
					   @"sanity: uninstallPlugin unregisters the tooltip entry");
		XCTAssertEqual([mockObserverManager unregisterCount], (NSUInteger)1,
					   @"sanity: uninstallPlugin unregisters the list-object observer");
	} @finally {
		// Guard against the pre-fix behavior leaving a scheduled repeating timer behind: the run loop
		// retains it and would otherwise keep it (and the plugin) alive across tests.
		NSTimer *timer = [plugin valueForKey:@"idleObjectTimer"];
		if ([timer isValid]) {
			[timer invalidate];
		}
		adium = savedAdium;
		AIObserverManagerSharedMock = savedObserverManagerMock;
	}
}

- (void)testDrainPathInvalidatesIdleUpdateTimer
{
	IdleMockListObject *mockObject = [[IdleMockListObject alloc] init];
	IdleMockObserverManager *mockObserverManager = [[IdleMockObserverManager alloc] init];
	IdleMockInterfaceController *mockInterfaceController = [[IdleMockInterfaceController alloc] init];
	IdleMockAdium *mockAdium = [[IdleMockAdium alloc] init];
	[mockAdium setInterfaceController:mockInterfaceController];
	id<AIAdium> savedAdium = adium;
	id savedObserverManagerMock = AIObserverManagerSharedMock;
	AIContactIdlePlugin *plugin = nil;

	AIObserverManagerSharedMock = mockObserverManager;
	adium = (id<AIAdium>)mockAdium;
	@try {
		plugin = [[AIContactIdlePlugin alloc] init];
		[plugin installPlugin];

		// An idle contact starts the repeating idle-update timer.
		[plugin updateListObject:(AIListObject *)mockObject keys:nil silent:YES];

		NSTimer *idleObjectTimer = [plugin valueForKey:@"idleObjectTimer"];
		XCTAssertNotNil(idleObjectTimer, @"sanity: an idle contact starts the idle-update timer");
		XCTAssertTrue([idleObjectTimer isValid], @"sanity: the idle timer is scheduled and valid while tracking");

		// The last tracked contact stops being idle; the drain path must stop the timer too.
		mockObject.isIdle = NO;
		[plugin updateListObject:(AIListObject *)mockObject keys:nil silent:YES];

		XCTAssertFalse(
			[idleObjectTimer isValid],
			@"the drain path must invalidate the idle-update timer when the last idle contact stops being idle");
		XCTAssertNil([plugin valueForKey:@"idleObjectTimer"], @"the drain path must nil the idle-update timer ivar");
		XCTAssertNil([plugin valueForKey:@"idleObjectArray"], @"the drain path must nil the idle-object array ivar");
	} @finally {
		// Guard against the pre-fix behavior leaving a scheduled repeating timer behind: the run loop
		// retains it and would otherwise keep it (and the plugin) alive across tests.
		NSTimer *timer = [plugin valueForKey:@"idleObjectTimer"];
		if ([timer isValid]) {
			[timer invalidate];
		}
		adium = savedAdium;
		AIObserverManagerSharedMock = savedObserverManagerMock;
	}
}

@end
