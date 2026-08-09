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
#import <AdiumY/AIService.h>
#import <AdiumY/AISharedAdium.h>
#import <AdiumY/AIStatusController.h>
#import <AdiumY/AIStatusDefines.h>
// clang-format on

/*
 * Link shims — class symbols only. The wired AIStatusController.m compiles against these classes;
 * none is instantiated on the paths this test executes (AIStatusController -init only allocates
 * AdiumIdleManager), so empty @implementations satisfy the linker.
 */
@interface AIStatusGroup : NSObject
@end

@implementation AIStatusGroup
@end

@interface AdiumIdleManager : NSObject
@end

@implementation AdiumIdleManager
@end

@interface AIAccountViewController : NSObject
@end

@implementation AIAccountViewController
@end

/*
 * MockAccountController records the account-side half of service registration/unregistration. #240
 * asserts unregisterService: is still sent (the status-side teardown is the subject of the test).
 */
@interface MockAccountController : NSObject
@property(nonatomic, assign) NSUInteger registerServiceCount;
@property(nonatomic, assign) NSUInteger unregisterServiceCount;
- (void)registerService:(AIService *)service;
- (void)unregisterService:(AIService *)service;
@end

@implementation MockAccountController
- (void)registerService:(AIService *)service
{
	_registerServiceCount++;
}
- (void)unregisterService:(AIService *)service
{
	_unregisterServiceCount++;
}
@end

/*
 * AIServiceMockAdium stands in for the global. accountController + statusController are the only
 * properties the exercised code reads. Named uniquely per test bundle (MockAdium is defined by the
 * pre-existing ESUserIconHandling test too, and CoverageHost links one bundle).
 */
@interface AIServiceMockAdium : NSObject
@property(nonatomic, strong) MockAccountController *accountController;
@property(nonatomic, strong) id<AIStatusController> statusController;
@end

@implementation AIServiceMockAdium
@end

/*
 * A concrete service exercising the real AIService lifecycle. Overrides registerStatuses to publish
 * exactly one status under a unique code so the test can observe it disappear after -unregisterService.
 */
@interface TestStatusService : AIService
- (NSString *)serviceCodeUniqueID;
- (void)registerStatuses;
@end

@implementation TestStatusService

- (NSString *)serviceCodeUniqueID
{
	return @"test-service-240";
}

- (void)registerStatuses
{
	[adium.statusController registerStatus:@"status-away-240"
						   withDescription:@"Unique Test Status Away - 240"
									ofType:AIAwayStatusType
								forService:self];
}

@end

@interface AIServiceUnregisterTest : XCTestCase
@end

@implementation AIServiceUnregisterTest

// registerService publishes the service's statuses; unregisterService must clear them from the
// status controller as well as the account controller, or the uninstalled service keeps its statuses
// selectable in the status menu (#240).
- (void)testUnregisterServiceClearsRegisteredStatuses
{
	MockAccountController *accountController = [[MockAccountController alloc] init];
	id<AIStatusController> statusController = [[AIStatusController alloc] init];
	AIServiceMockAdium *mockAdium = [[AIServiceMockAdium alloc] init];
	mockAdium.accountController = accountController;
	mockAdium.statusController = statusController;

	id<AIAdium> savedAdium = adium;
	@try {
		adium = (id<AIAdium>)mockAdium;

		TestStatusService *service = [TestStatusService registerService];
		XCTAssertEqual(accountController.registerServiceCount, (NSUInteger)1,
					   @"sanity: AIService +registerService registers with the account controller");

		NSMenu *menu = [statusController menuOfStatusesForService:service withTarget:nil];
		XCTAssertNotNil([menu itemWithTitle:@"Unique Test Status Away - 240"],
						@"sanity: the registered status appears in the status menu before unregister");

		[service unregisterService];

		XCTAssertEqual(accountController.unregisterServiceCount, (NSUInteger)1,
					   @"unregisterService still unregisters from the account controller");
		NSMenu *menuAfter = [statusController menuOfStatusesForService:service withTarget:nil];
		XCTAssertNil([menuAfter itemWithTitle:@"Unique Test Status Away - 240"],
					 @"unregisterService did not clear the service's statuses from the status controller");
	} @finally {
		adium = savedAdium;
	}
}

// removeObjectForKey:nil raises NSInvalidArgumentException. A nil service yields a nil key, so
// unregisterStatusesForService: must no-op rather than raise — the same guard the account-side
// unregister gained in #235.
- (void)testUnregisterStatusesForNilServiceDoesNotRaise
{
	MockAccountController *accountController = [[MockAccountController alloc] init];
	id<AIStatusController> statusController = [[AIStatusController alloc] init];
	AIServiceMockAdium *mockAdium = [[AIServiceMockAdium alloc] init];
	mockAdium.accountController = accountController;
	mockAdium.statusController = statusController;

	id<AIAdium> savedAdium = adium;
	@try {
		adium = (id<AIAdium>)mockAdium;

		TestStatusService *service = [TestStatusService registerService];
		NSMenu *menu = [statusController menuOfStatusesForService:service withTarget:nil];
		XCTAssertNotNil([menu itemWithTitle:@"Unique Test Status Away - 240"],
						@"sanity: the registered status appears in the status menu");

		XCTAssertNoThrow([statusController unregisterStatusesForService:nil],
						 @"unregisterStatusesForService: with a nil service must not raise");

		NSMenu *menuAfter = [statusController menuOfStatusesForService:service withTarget:nil];
		XCTAssertNotNil([menuAfter itemWithTitle:@"Unique Test Status Away - 240"],
						@"nil-service unregister must not remove any statuses");
	} @finally {
		adium = savedAdium;
	}
}

@end
