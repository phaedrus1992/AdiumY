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

/*
 * AIService interface declaration only (no @implementation): the single class symbol for this bundle
 * is defined by the empty shim in TestAdiumServicesUnregister.m. A bare @interface emits no
 * _OBJC_CLASS_$_ symbol, so declaring it here satisfies the AWBonjourService superclass reference at
 * compile time without duplicating the definition at link time.
 */
@interface AIService : NSObject
@end

/*
 * Recording shim for AWBonjourService. The real AWBonjourService.m is NOT compiled into this bundle —
 * the wired-in AWBonjourPlugin TU sends +registerService / -unregisterService to it, and those messages
 * land here. Static counters let the tests observe install/uninstall without touching the plugin's
 * private ivars.
 */
@interface AWBonjourService : AIService
+ (instancetype)registerService;
- (void)unregisterService;
+ (NSUInteger)registerCallCount;
+ (NSUInteger)unregisterCallCount;
+ (void)resetCounts;
@end

@implementation AWBonjourService {
	NSUInteger _registrationID;
}

static NSUInteger AWBonjourServiceRegisterCount;
static NSUInteger AWBonjourServiceUnregisterCount;
static NSUInteger AWBonjourServiceNextRegistrationID;

+ (instancetype)registerService
{
	AWBonjourServiceRegisterCount++;
	AWBonjourService *service = [[self alloc] init];
	service->_registrationID = ++AWBonjourServiceNextRegistrationID;
	return service;
}

- (void)unregisterService
{
	AWBonjourServiceUnregisterCount++;
}

+ (NSUInteger)registerCallCount
{
	return AWBonjourServiceRegisterCount;
}

+ (NSUInteger)unregisterCallCount
{
	return AWBonjourServiceUnregisterCount;
}

+ (void)resetCounts
{
	AWBonjourServiceRegisterCount = 0;
	AWBonjourServiceUnregisterCount = 0;
	AWBonjourServiceNextRegistrationID = 0;
}

@end

/*
 * The real @implementation for AWBonjourPlugin is wired into this bundle; the relaxed @interface
 * declares only the surface these tests need. installPlugin: registers the Bonjour service;
 * uninstallPlugin: must undo that registration (#235).
 */
@interface AWBonjourPlugin : NSObject
- (void)installPlugin;
- (void)uninstallPlugin;
@end

@interface AWBonjourPluginUninstallTest : XCTestCase
@end

@implementation AWBonjourPluginUninstallTest

- (void)setUp
{
	[AWBonjourService resetCounts];
}

// installPlugin: registers the Bonjour service; uninstallPlugin: must unregister exactly the service
// installPlugin registered, so the unloaded plugin leaves no registration behind (#235).
- (void)testUninstallUnregistersServiceInstalledByInstall
{
	AWBonjourPlugin *plugin = [[AWBonjourPlugin alloc] init];
	[plugin installPlugin];

	XCTAssertEqual([AWBonjourService registerCallCount], (NSUInteger)1,
				   @"sanity: installPlugin registers the Bonjour service");

	[plugin uninstallPlugin];

	XCTAssertEqual([AWBonjourService unregisterCallCount], (NSUInteger)1,
				   @"uninstallPlugin must unregister the service installPlugin registered");
}

// Teardown must be safe against already-torn-down state: a second uninstallPlugin: (with the service
// ivar already nil) must not crash and must not send any further messages.
- (void)testUninstallIsIdempotent
{
	AWBonjourPlugin *plugin = [[AWBonjourPlugin alloc] init];
	[plugin installPlugin];
	[plugin uninstallPlugin];

	[plugin uninstallPlugin];

	XCTAssertEqual([AWBonjourService unregisterCallCount], (NSUInteger)1,
				   @"double uninstall must not unregister the service a second time");
}

@end
