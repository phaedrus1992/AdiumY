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
 * Link shims for the standalone test target. The plugin TU references ErrorMessageWindowController
 * and ESPanelAlertDetailPane by class name (both message sends), which emit _OBJC_CLASS_$_ symbols
 * no linked framework provides, so each gets an empty implementation here. The shared `adium` global
 * and the AIPlugin class are provided by TestESUserIconHandlingPluginObserverRemoval.m in the same
 * bundle — not redefined here.
 */
@interface ErrorMessageWindowController : NSObject
+ (id)errorMessageWindowController;
+ (void)closeSharedInstance;
@end

@implementation ErrorMessageWindowController
+ (id)errorMessageWindowController
{
	return nil;
}

+ (void)closeSharedInstance
{}
@end

#import <AdiumY/AIActionDetailsPane.h>

@implementation AIActionDetailsPane
+ (AIActionDetailsPane *)actionDetailsPane
{
	return nil;
}
@end

@interface ESPanelAlertDetailPane : AIActionDetailsPane
+ (AIActionDetailsPane *)actionDetailsPane;
@end

@implementation ESPanelAlertDetailPane
+ (AIActionDetailsPane *)actionDetailsPane
{
	return nil;
}
@end

/*
 * Fakes for the contact-alert action unregistration test. ErrorMessageAlertMockContactAlertsController
 * records the register/unregister calls installPlugin and uninstallPlugin make; the registerEventID:
 * handler must exist so installPlugin's registration send resolves (its unregistration stays out of
 * scope — #200). ErrorMessageAlertMockAdium supplies the contactAlertsController installPlugin reads
 * off adium.
 */
@interface ErrorMessageAlertMockContactAlertsController : NSObject
@property(nonatomic, assign) NSUInteger registerActionIDCount;
@property(nonatomic, assign) NSUInteger registerEventIDCount;
@property(nonatomic, assign) NSUInteger unregisterActionIDCount;
@property(nonatomic, copy) NSString *lastUnregisteredActionID;

- (void)registerActionID:(NSString *)actionID withHandler:(id)handler;
- (void)registerEventID:(NSString *)eventID withHandler:(id)handler inGroup:(NSInteger)group globalOnly:(BOOL)global;
- (void)unregisterActionID:(NSString *)actionID;
@end

@implementation ErrorMessageAlertMockContactAlertsController
- (void)registerActionID:(NSString *)actionID withHandler:(id)handler
{
	_registerActionIDCount++;
}

- (void)registerEventID:(NSString *)eventID withHandler:(id)handler inGroup:(NSInteger)group globalOnly:(BOOL)global
{
	_registerEventIDCount++;
}

- (void)unregisterActionID:(NSString *)actionID
{
	_unregisterActionIDCount++;
	_lastUnregisteredActionID = actionID;
}
@end

@interface ErrorMessageAlertMockAdium : NSObject
@property(nonatomic, strong) ErrorMessageAlertMockContactAlertsController *contactAlertsController;
@end

@implementation ErrorMessageAlertMockAdium
@end

#import "ErrorMessageHandlerPlugin.h"
#import <AdiumY/AIInterfaceControllerProtocol.h>

/*
 * Counting subclass: overrides handleError: so the install-time observer can be detected by counter
 * instead of by side effect; installPlugin/uninstallPlugin run their real bodies.
 */
@interface ErrorMessageHandlerObserverCountingPlugin : ErrorMessageHandlerPlugin
@property(nonatomic, assign) NSUInteger handleErrorCount;
@end

@implementation ErrorMessageHandlerObserverCountingPlugin
- (void)handleError:(NSNotification *)notification
{
	_handleErrorCount++;
}
@end

@interface ErrorMessageHandlerPluginObserverRemovalTest : XCTestCase
@end

@implementation ErrorMessageHandlerPluginObserverRemovalTest

// installPlugin registers the Interface_ShouldDisplayErrorMessage observer; uninstallPlugin must
// remove it, or the plugin keeps handling errors after it is uninstalled.
- (void)testUninstallRemovesShouldDisplayErrorMessageObserver
{
	ErrorMessageHandlerObserverCountingPlugin *plugin = [[ErrorMessageHandlerObserverCountingPlugin alloc] init];
	[plugin installPlugin];

	// Positive control: the observer must fire while installed, or this test cannot tell
	// "removed by uninstallPlugin" from "never registered at all".
	[[NSNotificationCenter defaultCenter] postNotificationName:Interface_ShouldDisplayErrorMessage
														object:nil
													  userInfo:@{@"Title" : @"t", @"Description" : @"d"}];
	XCTAssertEqual([plugin handleErrorCount], (NSUInteger)1,
				   @"sanity: Interface_ShouldDisplayErrorMessage observer fired while installed");

	[plugin uninstallPlugin];
	[[NSNotificationCenter defaultCenter] postNotificationName:Interface_ShouldDisplayErrorMessage
														object:nil
													  userInfo:@{@"Title" : @"t", @"Description" : @"d"}];
	XCTAssertEqual([plugin handleErrorCount], (NSUInteger)1,
				   @"Interface_ShouldDisplayErrorMessage observer still registered after uninstallPlugin");
}

// installPlugin registers ERROR_MESSAGE_CONTACT_ALERT_IDENTIFIER's action handler; uninstallPlugin must
// unregister it, or the handler stays registered on an uninstalled plugin (#219). The registerEventID:
// registration is not asserted — its unregistration is out of scope (#200).
- (void)testUninstallUnregistersContactAlertActionHandler
{
	ErrorMessageAlertMockContactAlertsController *mockController =
		[[ErrorMessageAlertMockContactAlertsController alloc] init];
	ErrorMessageAlertMockAdium *mockAdium = [[ErrorMessageAlertMockAdium alloc] init];
	[mockAdium setContactAlertsController:mockController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		ErrorMessageHandlerObserverCountingPlugin *plugin = [[ErrorMessageHandlerObserverCountingPlugin alloc] init];
		[plugin installPlugin];

		XCTAssertEqual([mockController registerActionIDCount], (NSUInteger)1,
					   @"sanity: installPlugin registered the contact alert action handler");

		[plugin uninstallPlugin];

		XCTAssertEqual([mockController unregisterActionIDCount], (NSUInteger)1,
					   @"uninstallPlugin did not unregister the contact alert action handler");
		XCTAssertEqualObjects([mockController lastUnregisteredActionID], ERROR_MESSAGE_CONTACT_ALERT_IDENTIFIER,
							  @"uninstallPlugin must unregister the action ID it registered");
	} @finally {
		adium = savedAdium;
	}
}

@end
