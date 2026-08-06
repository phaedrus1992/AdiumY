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

@end
