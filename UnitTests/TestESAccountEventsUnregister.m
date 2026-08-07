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

#import <AdiumY/AIAdiumProtocol.h>
#import <AdiumY/AIContactAlertsControllerProtocol.h>
#import <AdiumY/AISharedAdium.h>

/*
 * The real ESAccountEvents @implementation is wired into this bundle and provides the
 * _OBJC_CLASS_$_ESAccountEvents symbol; the relaxed @interface below declares only the surface this
 * test needs. The shared `adium` global, the AIPlugin class, and the AIContactObserverManager class
 * come from the other test files in the same bundle — not redefined here.
 */
@interface ESAccountEvents : NSObject
- (void)installPlugin;
- (void)uninstallPlugin;
@end

/*
 * Records which event IDs installPlugin registered and which uninstallPlugin unregistered, so a test
 * can assert the plugin undoes exactly what it set up.
 */
@interface AccountEventsMockContactAlertsController : NSObject
@property(nonatomic, readonly) NSMutableArray<NSString *> *registeredEventIDs;
@property(nonatomic, readonly) NSMutableArray<NSString *> *unregisteredEventIDs;

- (void)registerEventID:(NSString *)eventID
			withHandler:(id)handler
				inGroup:(AIEventHandlerGroupType)group
			 globalOnly:(BOOL)global;
- (void)unregisterEventID:(NSString *)eventID;
@end

@implementation AccountEventsMockContactAlertsController
- (instancetype)init
{
	if ((self = [super init])) {
		_registeredEventIDs = [[NSMutableArray alloc] init];
		_unregisteredEventIDs = [[NSMutableArray alloc] init];
	}

	return self;
}

- (void)registerEventID:(NSString *)eventID
			withHandler:(id)handler
				inGroup:(AIEventHandlerGroupType)group
			 globalOnly:(BOOL)global
{
	[_registeredEventIDs addObject:eventID];
}

- (void)unregisterEventID:(NSString *)eventID
{
	[_unregisteredEventIDs addObject:eventID];
}
@end

@interface AccountEventsMockAdium : NSObject
@property(nonatomic, strong) AccountEventsMockContactAlertsController *contactAlertsController;
@end

@implementation AccountEventsMockAdium
@end

@interface ESAccountEventsUnregisterTest : XCTestCase
@end

@implementation ESAccountEventsUnregisterTest

// installPlugin registers three account events; uninstallPlugin must unregister every one of them,
// or the handlers stay registered on an uninstalled plugin (#230).
- (void)testUninstallUnregistersAllRegisteredEvents
{
	AccountEventsMockContactAlertsController *mockController = [[AccountEventsMockContactAlertsController alloc] init];
	AccountEventsMockAdium *mockAdium = [[AccountEventsMockAdium alloc] init];
	[mockAdium setContactAlertsController:mockController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		ESAccountEvents *plugin = [[ESAccountEvents alloc] init];
		[plugin installPlugin];

		// Hoisted to locals: an array literal with commas cannot sit directly in a macro argument —
		// the preprocessor splits on commas not inside parentheses, mangling the XCTAssertEqualObjects call.
		NSArray<NSString *> *expectedEventIDs = @[ ACCOUNT_CONNECTED, ACCOUNT_DISCONNECTED, ACCOUNT_RECEIVED_EMAIL ];
		XCTAssertEqualObjects([mockController registeredEventIDs], expectedEventIDs,
							  @"sanity: installPlugin registered the three account events");

		[plugin uninstallPlugin];

		XCTAssertEqualObjects([mockController unregisteredEventIDs], expectedEventIDs,
							  @"uninstallPlugin must unregister every event ID installPlugin registered");
	} @finally {
		adium = savedAdium;
	}
}

@end
