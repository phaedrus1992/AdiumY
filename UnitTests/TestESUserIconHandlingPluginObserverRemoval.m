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
 * Link shims for the standalone test target. The plugin's TU imports the real AdiumY framework
 * headers and references these symbols, but the test target links no AdiumY.framework binary, so
 * each referenced class gets an empty implementation here and the shared `adium` global is provided
 * (left nil — installPlugin/uninstallPlugin no-op their controller calls against it).
 */
@protocol AIAdium;
id<AIAdium> adium = nil;

@interface AIPlugin : NSObject
- (void)installPlugin;
- (void)uninstallPlugin;
@end

@implementation AIPlugin
@end

@interface AIListContact : NSObject
@end

@implementation AIListContact
@end

@interface AIServiceIcons : NSObject
+ (id)serviceIconForObject:(id)inObject type:(NSInteger)iconType direction:(NSInteger)direction;
@end

@implementation AIServiceIcons
+ (id)serviceIconForObject:(id)inObject type:(NSInteger)iconType direction:(NSInteger)direction
{
	return nil;
}
@end

#import "ESUserIconHandlingPlugin.h"

/*
 * Counting subclass used by the install-time observer tests. Overrides the three handlers
 * installPlugin/registerToolbarItem register so notifications can be detected by counter instead
 * of by side effect; installPlugin/uninstallPlugin/registerToolbarItem run their real bodies.
 */
@interface UserIconObserverCountingPlugin : ESUserIconHandlingPlugin
@property (nonatomic, assign) NSUInteger listObjectAttributesChangedCount;
@property (nonatomic, assign) NSUInteger toolbarWillAddItemCount;
@property (nonatomic, assign) NSUInteger toolbarDidRemoveItemCount;
@end

@implementation UserIconObserverCountingPlugin
- (void)listObjectAttributesChanged:(NSNotification *)notification
{
	_listObjectAttributesChangedCount++;
}

- (void)toolbarWillAddItem:(NSNotification *)notification
{
	_toolbarWillAddItemCount++;
}

- (void)toolbarDidRemoveItem:(NSNotification *)notification
{
	_toolbarDidRemoveItemCount++;
}
@end

/*
 * Counting subclass used by the lazy chat-observer test. The real toolbarWillAddItem: must run —
 * it is what registers the chat observer on the first item add — so only the handlers that would
 * do real work are overridden: chatDidBecomeVisible: counts, and toolbarDidAddItem: (the delayed
 * post-add callback) is a no-op to neutralize the performSelector:afterDelay:0 scheduling.
 */
@interface ChatObserverTrackingPlugin : ESUserIconHandlingPlugin
@property (nonatomic, assign) NSUInteger chatDidBecomeVisibleCount;
@end

@implementation ChatObserverTrackingPlugin
- (void)chatDidBecomeVisible:(NSNotification *)notification
{
	_chatDidBecomeVisibleCount++;
}

- (void)toolbarDidAddItem:(NSToolbarItem *)item
{
}
@end

@interface ESUserIconHandlingPluginObserverRemovalTest : XCTestCase
- (void)postListObjectAttributesChanged;
- (void)postToolbarNotification:(NSNotificationName)name withItem:(NSToolbarItem *)item;
- (void)postChatDidBecomeVisible;
@end

@implementation ESUserIconHandlingPluginObserverRemovalTest

#pragma mark - Observers installed by installPlugin

// installPlugin registers the ListObject_AttributesChanged observer; uninstallPlugin must remove it,
// or the plugin keeps receiving notifications after it is uninstalled.
- (void)testUninstallRemovesListObjectAttributesChangedObserver
{
	UserIconObserverCountingPlugin *plugin = [[UserIconObserverCountingPlugin alloc] init];
	[plugin installPlugin];

	// Positive control: the observer must fire while installed, or this test cannot tell
	// "removed by uninstallPlugin" from "never registered at all".
	[self postListObjectAttributesChanged];
	XCTAssertEqual([plugin listObjectAttributesChangedCount], (NSUInteger)1,
				   @"sanity: ListObject_AttributesChanged observer fired while installed");

	[plugin uninstallPlugin];
	[self postListObjectAttributesChanged];
	XCTAssertEqual([plugin listObjectAttributesChangedCount], (NSUInteger)1,
				   @"observer still registered after uninstallPlugin");
}

// registerToolbarItem registers the NSToolbarWillAddItem / NSToolbarDidRemoveItem observers;
// uninstallPlugin must remove both.
- (void)testUninstallRemovesToolbarObservers
{
	UserIconObserverCountingPlugin *plugin = [[UserIconObserverCountingPlugin alloc] init];
	[plugin installPlugin];

	// Positive control: both observers must fire while installed, or this test cannot tell
	// "removed by uninstallPlugin" from "never registered at all".
	[self postToolbarNotification:NSToolbarWillAddItemNotification withItem:nil];
	XCTAssertEqual([plugin toolbarWillAddItemCount], (NSUInteger)1,
				   @"sanity: NSToolbarWillAddItemNotification observer fired while installed");

	[self postToolbarNotification:NSToolbarDidRemoveItemNotification withItem:nil];
	XCTAssertEqual([plugin toolbarDidRemoveItemCount], (NSUInteger)1,
				   @"sanity: NSToolbarDidRemoveItemNotification observer fired while installed");

	[plugin uninstallPlugin];

	[self postToolbarNotification:NSToolbarWillAddItemNotification withItem:nil];
	XCTAssertEqual([plugin toolbarWillAddItemCount], (NSUInteger)1,
				   @"NSToolbarWillAddItemNotification observer still registered after uninstallPlugin");

	[self postToolbarNotification:NSToolbarDidRemoveItemNotification withItem:nil];
	XCTAssertEqual([plugin toolbarDidRemoveItemCount], (NSUInteger)1,
				   @"NSToolbarDidRemoveItemNotification observer still registered after uninstallPlugin");
}

// The chat observer is registered lazily by toolbarWillAddItem: on the first item add;
// uninstallPlugin must remove it too, since toolbarDidRemoveItem: only does so when the toolbar
// count reaches zero.
- (void)testUninstallRemovesChatBecameVisibleObserver
{
	ChatObserverTrackingPlugin *plugin = [[ChatObserverTrackingPlugin alloc] init];
	[plugin installPlugin];

	NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:@"UserIcon"];
	[self postToolbarNotification:NSToolbarWillAddItemNotification withItem:item];
	[self postChatDidBecomeVisible];
	XCTAssertEqual([plugin chatDidBecomeVisibleCount], (NSUInteger)1,
				   @"sanity: chat observer fired while installed");

	[plugin uninstallPlugin];
	[self postChatDidBecomeVisible];
	XCTAssertEqual([plugin chatDidBecomeVisibleCount], (NSUInteger)1,
				   @"chat observer still registered after uninstallPlugin");
}

#pragma mark - Notification posting helpers

- (void)postListObjectAttributesChanged
{
	[[NSNotificationCenter defaultCenter] postNotificationName:ListObject_AttributesChanged
														object:nil
													  userInfo:@{ @"Keys": @[ KEY_USER_ICON ] }];
}

- (void)postToolbarNotification:(NSNotificationName)name withItem:(NSToolbarItem *)item
{
	NSDictionary *userInfo = item ? @{ @"item": item } : @{};
	[[NSNotificationCenter defaultCenter] postNotificationName:name object:nil userInfo:userInfo];
}

- (void)postChatDidBecomeVisible
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"AIChatDidBecomeVisible"
														object:nil
													  userInfo:@{ @"NSWindow": [NSNull null] }];
}

@end
