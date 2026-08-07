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
 * Link shims for the standalone test target (see the note in
 * TestESUserIconHandlingPluginObserverRemoval.m). The five #212 plugin TUs reference these class
 * symbols; the test target links no Adium.framework binary, so each gets an empty implementation
 * here. The shared `adium` global and the AIPlugin class come from
 * TestESUserIconHandlingPluginObserverRemoval.m in the same bundle — not redefined here.
 */
@protocol AIAdium;
extern id<AIAdium> adium;

@interface AINewMessagePromptController : NSObject
+ (void)showPrompt;
@end

@implementation AINewMessagePromptController
+ (void)showPrompt
{}
@end

@interface DCJoinChatWindowController : NSObject
+ (void)showJoinChatWindow;
@end

@implementation DCJoinChatWindowController
+ (void)showJoinChatWindow
{}
@end

@interface DCInviteToChatWindowController : NSObject
+ (void)inviteToChatWindowForChat:(id)chat contact:(id)contact;
@end

@implementation DCInviteToChatWindowController
+ (void)inviteToChatWindowForChat:(id)chat contact:(id)contact
{}
@end

@interface ESStatusPreferences : NSObject
+ (id)preferencePaneForPlugin:(id)plugin;
@end

@implementation ESStatusPreferences
+ (id)preferencePaneForPlugin:(id)plugin
{
	return [[self alloc] init];
}
@end

@interface ESStatusAdvancedPreferences : NSObject
+ (id)preferencePaneForPlugin:(id)plugin;
@end

@implementation ESStatusAdvancedPreferences
+ (id)preferencePaneForPlugin:(id)plugin
{
	return [[self alloc] init];
}
@end

@interface AIListBookmark : NSObject
@end

@implementation AIListBookmark
@end

@interface AIMetaContact : NSObject
@end

@implementation AIMetaContact
@end

/*
 * Recording fakes. The five plugins register menu items (and contextual items) against
 * adium.menuController at install; uninstallPlugin must remove exactly those and nil their ivars.
 * MenuMockPreferenceController backs ESStatusPreferencesPlugin's default-registration call.
 * MenuMockAdium is a plain NSObject (never formally conforming to <AIAdium>) installed via
 * `adium = (id<AIAdium>)mockAdium`.
 */
@interface MenuMockMenuController : NSObject
@property(nonatomic, strong) NSMutableArray *addedItems;
@property(nonatomic, strong) NSMutableArray *removedItems;
@property(nonatomic, strong) NSMutableArray *addedContextualItems;
@property(nonatomic, strong) NSMutableArray *removedContextualItems;

- (void)addMenuItem:(NSMenuItem *)item toLocation:(NSInteger)location;
- (void)removeMenuItem:(NSMenuItem *)item;
- (void)addContextualMenuItem:(NSMenuItem *)item toLocation:(NSInteger)location;
- (void)removeContextualMenuItem:(NSMenuItem *)item;
@end

@implementation MenuMockMenuController
- (instancetype)init
{
	if ((self = [super init])) {
		_addedItems = [[NSMutableArray alloc] init];
		_removedItems = [[NSMutableArray alloc] init];
		_addedContextualItems = [[NSMutableArray alloc] init];
		_removedContextualItems = [[NSMutableArray alloc] init];
	}

	return self;
}

- (void)addMenuItem:(NSMenuItem *)item toLocation:(NSInteger)location
{
	[_addedItems addObject:item];
}

- (void)removeMenuItem:(NSMenuItem *)item
{
	[_removedItems addObject:item];
}

- (void)addContextualMenuItem:(NSMenuItem *)item toLocation:(NSInteger)location
{
	[_addedContextualItems addObject:item];
}

- (void)removeContextualMenuItem:(NSMenuItem *)item
{
	[_removedContextualItems addObject:item];
}
@end

@interface MenuMockPreferenceController : NSObject
@property(nonatomic, assign) NSUInteger unregisterObserverCount;
@property(nonatomic, strong) NSMutableArray *removedPanes;

- (void)registerDefaults:(NSDictionary *)defaults forGroup:(NSString *)group;
- (void)registerPreferenceObserver:(id)observer forGroup:(NSString *)group;
- (void)unregisterPreferenceObserver:(id)observer;
- (void)removePreferencePane:(id)pane;
@end

@implementation MenuMockPreferenceController
- (instancetype)init
{
	if ((self = [super init])) {
		_removedPanes = [[NSMutableArray alloc] init];
	}

	return self;
}

- (void)registerDefaults:(NSDictionary *)defaults forGroup:(NSString *)group
{}

- (void)registerPreferenceObserver:(id)observer forGroup:(NSString *)group
{}

- (void)unregisterPreferenceObserver:(id)observer
{
	_unregisterObserverCount++;
}

- (void)removePreferencePane:(id)pane
{
	[_removedPanes addObject:pane];
}

- (void)removeAdvancedPreferencePane:(id)pane
{
	[_removedPanes addObject:pane];
}
@end

@interface MenuMockAdium : NSObject
@property(nonatomic, strong) MenuMockMenuController *menuController;
@property(nonatomic, strong) MenuMockPreferenceController *preferenceController;
@end

@implementation MenuMockAdium
@end

/*
 * Relaxed declarations of the plugin classes under test. The real @implementations ship in the
 * bundle (their TUs import the real Adium headers); this TU only needs the method surface to drive
 * installPlugin/uninstallPlugin against them.
 */
@interface AIChatConsolidationPlugin : NSObject
- (void)installPlugin;
- (void)uninstallPlugin;
@end

@interface AINewMessagePanelPlugin : NSObject
- (void)installPlugin;
- (void)uninstallPlugin;
@end

@interface DCJoinChatPanelPlugin : NSObject
- (void)installPlugin;
- (void)uninstallPlugin;
@end

@interface DCInviteToChatPlugin : NSObject
- (void)installPlugin;
- (void)uninstallPlugin;
@end

@interface ESStatusPreferencesPlugin : NSObject
- (void)installPlugin;
- (void)uninstallPlugin;
@end

@interface MenuPluginUninstallTest : XCTestCase
- (void)uninstallAndAssertRemovalForPlugin:(id)plugin menuController:(MenuMockMenuController *)mockMenuController;
@end

@implementation MenuPluginUninstallTest

// Shared teardown assertion: after uninstallPlugin, every menu/contextual item installPlugin
// registered must have been removed (count and identity), so an uninstalled plugin leaves no live
// menu item behind.
- (void)uninstallAndAssertRemovalForPlugin:(id)plugin menuController:(MenuMockMenuController *)mockMenuController
{
	[plugin uninstallPlugin];

	XCTAssertEqual([mockMenuController.removedItems count], [mockMenuController.addedItems count],
				   @"uninstallPlugin removed a different number of menu items than installPlugin registered");
	XCTAssertEqual([mockMenuController.removedContextualItems count], [mockMenuController.addedContextualItems count],
				   @"uninstallPlugin removed a different number of contextual items than installPlugin registered");

	for (NSMenuItem *item in mockMenuController.addedItems) {
		XCTAssertTrue([mockMenuController.removedItems containsObject:item],
					  @"uninstallPlugin did not remove a menu item installPlugin registered");
	}
	for (NSMenuItem *item in mockMenuController.addedContextualItems) {
		XCTAssertTrue([mockMenuController.removedContextualItems containsObject:item],
					  @"uninstallPlugin did not remove a contextual item installPlugin registered");
	}
}

- (void)testAIChatConsolidationPluginUninstallRemovesMenuItems
{
	MenuMockMenuController *mockMenuController = [[MenuMockMenuController alloc] init];
	MenuMockAdium *mockAdium = [[MenuMockAdium alloc] init];
	[mockAdium setMenuController:mockMenuController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		AIChatConsolidationPlugin *plugin = [[AIChatConsolidationPlugin alloc] init];
		[plugin installPlugin];

		XCTAssertEqual([mockMenuController.addedItems count], (NSUInteger)2,
					   @"sanity: installPlugin registered two menu items");
		XCTAssertEqual([mockMenuController.addedContextualItems count], (NSUInteger)0,
					   @"sanity: AIChatConsolidationPlugin registered no contextual items");

		[self uninstallAndAssertRemovalForPlugin:plugin menuController:mockMenuController];

		XCTAssertNil([plugin valueForKey:@"consolidateMenuItem"],
					 @"uninstallPlugin must nil the consolidate menu item ivar");
		XCTAssertNil([plugin valueForKey:@"newWndowMenuItem"],
					 @"uninstallPlugin must nil the new-window menu item ivar");
	} @finally {
		adium = savedAdium;
	}
}

- (void)testAINewMessagePanelPluginUninstallRemovesMenuItems
{
	MenuMockMenuController *mockMenuController = [[MenuMockMenuController alloc] init];
	MenuMockAdium *mockAdium = [[MenuMockAdium alloc] init];
	[mockAdium setMenuController:mockMenuController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		AINewMessagePanelPlugin *plugin = [[AINewMessagePanelPlugin alloc] init];
		[plugin installPlugin];

		XCTAssertEqual([mockMenuController.addedItems count], (NSUInteger)1,
					   @"sanity: installPlugin registered one menu item");
		XCTAssertEqual([mockMenuController.addedContextualItems count], (NSUInteger)1,
					   @"sanity: installPlugin registered one contextual item");

		[self uninstallAndAssertRemovalForPlugin:plugin menuController:mockMenuController];

		XCTAssertNil([plugin valueForKey:@"newMessageMenuItem"],
					 @"uninstallPlugin must nil the new-message menu item ivar");
		XCTAssertNil([plugin valueForKey:@"openChatMenuItem"],
					 @"uninstallPlugin must nil the open-chat contextual item ivar");
	} @finally {
		adium = savedAdium;
	}
}

- (void)testDCJoinChatPanelPluginUninstallRemovesMenuItem
{
	MenuMockMenuController *mockMenuController = [[MenuMockMenuController alloc] init];
	MenuMockAdium *mockAdium = [[MenuMockAdium alloc] init];
	[mockAdium setMenuController:mockMenuController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		DCJoinChatPanelPlugin *plugin = [[DCJoinChatPanelPlugin alloc] init];
		[plugin installPlugin];

		XCTAssertEqual([mockMenuController.addedItems count], (NSUInteger)1,
					   @"sanity: installPlugin registered one menu item");
		XCTAssertEqual([mockMenuController.addedContextualItems count], (NSUInteger)0,
					   @"sanity: DCJoinChatPanelPlugin registered no contextual items");

		[self uninstallAndAssertRemovalForPlugin:plugin menuController:mockMenuController];

		XCTAssertNil([plugin valueForKey:@"joinChatMenuItem"],
					 @"uninstallPlugin must nil the join-chat menu item ivar");
	} @finally {
		adium = savedAdium;
	}
}

- (void)testDCInviteToChatPluginUninstallRemovesMenuItems
{
	MenuMockMenuController *mockMenuController = [[MenuMockMenuController alloc] init];
	MenuMockAdium *mockAdium = [[MenuMockAdium alloc] init];
	[mockAdium setMenuController:mockMenuController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		DCInviteToChatPlugin *plugin = [[DCInviteToChatPlugin alloc] init];
		[plugin installPlugin];

		XCTAssertEqual([mockMenuController.addedItems count], (NSUInteger)1,
					   @"sanity: installPlugin registered one menu item");
		XCTAssertEqual([mockMenuController.addedContextualItems count], (NSUInteger)1,
					   @"sanity: installPlugin registered one contextual item");

		[self uninstallAndAssertRemovalForPlugin:plugin menuController:mockMenuController];

		XCTAssertNil([plugin valueForKey:@"menuItem_inviteToChat"],
					 @"uninstallPlugin must nil the invite-to-chat menu item ivar");
		XCTAssertNil([plugin valueForKey:@"menuItem_inviteToChatContext"],
					 @"uninstallPlugin must nil the invite-to-chat contextual item ivar");
	} @finally {
		adium = savedAdium;
	}
}

- (void)testESStatusPreferencesPluginUninstallRemovesMenuItem
{
	MenuMockMenuController *mockMenuController = [[MenuMockMenuController alloc] init];
	MenuMockPreferenceController *mockPreferenceController = [[MenuMockPreferenceController alloc] init];
	MenuMockAdium *mockAdium = [[MenuMockAdium alloc] init];
	[mockAdium setMenuController:mockMenuController];
	[mockAdium setPreferenceController:mockPreferenceController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		ESStatusPreferencesPlugin *plugin = [[ESStatusPreferencesPlugin alloc] init];
		[plugin installPlugin];

		XCTAssertEqual([mockMenuController.addedItems count], (NSUInteger)1,
					   @"sanity: installPlugin registered one menu item");
		XCTAssertEqual([mockMenuController.addedContextualItems count], (NSUInteger)0,
					   @"sanity: ESStatusPreferencesPlugin registered no contextual items");

		// Capture the panes before uninstall — uninstallPlugin nils both ivars.
		id preferences = [plugin valueForKey:@"preferences"];
		id advancedPreferences = [plugin valueForKey:@"advancedPreferences"];
		XCTAssertNotNil(preferences, @"sanity: installPlugin created the status preferences pane");
		XCTAssertNotNil(advancedPreferences, @"sanity: installPlugin created the advanced status preferences pane");

		[self uninstallAndAssertRemovalForPlugin:plugin menuController:mockMenuController];

		XCTAssertNil([plugin valueForKey:@"menuItem"], @"uninstallPlugin must nil the edit-status-menu item ivar");
		XCTAssertEqual([mockPreferenceController.removedPanes count], (NSUInteger)2,
					   @"uninstallPlugin must unregister both preference panes installPlugin registered");
		XCTAssertTrue([mockPreferenceController.removedPanes containsObject:preferences],
					  @"uninstallPlugin must unregister the status preferences pane");
		XCTAssertTrue([mockPreferenceController.removedPanes containsObject:advancedPreferences],
					  @"uninstallPlugin must unregister the advanced status preferences pane");
		XCTAssertNil([plugin valueForKey:@"preferences"], @"uninstallPlugin must nil the status preferences pane ivar");
		XCTAssertNil([plugin valueForKey:@"advancedPreferences"],
					 @"uninstallPlugin must nil the advanced status preferences pane ivar");
	} @finally {
		adium = savedAdium;
	}
}

@end
