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
 * Link shims for the standalone test target. Each plugin TU below references its pane/factory classes
 * by class name (a +preferencePaneForPlugin: send or an alloc), which emits _OBJC_CLASS_$_ symbols no
 * linked framework provides, so each gets a minimal implementation here. The preference-pane plugins'
 * installPlugin is NOT invoked by these tests (the pane ivar is injected via KVC to sidestep
 * AIURLHandlerPlugin's LSSetDefaultHandlerForURLScheme side effects), so the pane shims need no factory
 * methods — the class symbol is all the linker needs. The shared `adium` global and the AIPlugin class
 * are provided by TestESUserIconHandlingPluginObserverRemoval.m in the same bundle — not redefined here.
 */
@interface AIContentNotification : NSObject
@end

@implementation AIContentNotification
@end

@interface AIListObject : NSObject
@end

@implementation AIListObject
@end

@interface AIContentTopic : NSObject
@end

@implementation AIContentTopic
@end

@interface ESGeneralPreferences : NSObject
@end

@implementation ESGeneralPreferences
@end

@interface AIHotKey : NSObject
@end

@implementation AIHotKey
@end

@interface AIHotKeyCenter : NSObject
@end

@implementation AIHotKeyCenter
@end

@interface AIMentionAdvancedPreferences : NSObject
@end

@implementation AIMentionAdvancedPreferences
@end

@interface AIURLHandlerAdvancedPreferences : NSObject
@end

@implementation AIURLHandlerAdvancedPreferences
@end

@interface AINewContactWindowController : NSObject
@end

@implementation AINewContactWindowController
@end

@interface AITemporaryIRCAccountWindowController : NSObject
@end

@implementation AITemporaryIRCAccountWindowController
@end

@interface XtrasInstaller : NSObject
@end

@implementation XtrasInstaller
@end

@interface AIAccountListPreferences : NSObject
@end

@implementation AIAccountListPreferences
@end

@interface AISoundSet : NSObject
@end

@implementation AISoundSet
@end

@interface ESGlobalEventsPreferences : NSObject
@end

@implementation ESGlobalEventsPreferences
@end

/*
 * The real @implementations for these plugin classes are wired into this bundle; the relaxed
 * @interfaces below declare only the surface each test needs.
 */
@interface AINudgeBuzzHandlerPlugin : NSObject
- (void)installPlugin;
- (void)uninstallPlugin;
@end

@interface ESGeneralPreferencesPlugin : NSObject
- (void)uninstallPlugin;
@end

@interface AIMentionEventPlugin : NSObject
- (void)uninstallPlugin;
@end

@interface AIURLHandlerPlugin : NSObject
- (void)uninstallPlugin;
@end

@interface AIAccountListPreferencesPlugin : NSObject
- (void)uninstallPlugin;
@end

@interface ESGlobalEventsPreferencesPlugin : NSObject
- (void)uninstallPlugin;
@end

/*
 * Fakes for the teardown tests. VariantUninstallMockPreferenceController records the preference-controller
 * interactions uninstallPlugin makes — removePreferencePane:, removeAdvancedPreferencePane:, and
 * unregisterPreferenceObserver:; the contact-alerts mock records registered/unregistered event IDs;
 * the adium mock supplies whichever controllers a test sets.
 */
@interface VariantUninstallMockPreferenceController : NSObject
@property(nonatomic, assign) NSUInteger removePreferencePaneCount;
@property(nonatomic, assign) NSUInteger removeAdvancedPreferencePaneCount;
@property(nonatomic, assign) NSUInteger unregisterObserverCount;

- (void)removePreferencePane:(id)inPane;
- (void)removeAdvancedPreferencePane:(id)inPane;
- (void)unregisterPreferenceObserver:(id)observer;
@end

@implementation VariantUninstallMockPreferenceController
- (void)removePreferencePane:(id)inPane
{
	_removePreferencePaneCount++;
}

- (void)removeAdvancedPreferencePane:(id)inPane
{
	_removeAdvancedPreferencePaneCount++;
}

- (void)unregisterPreferenceObserver:(id)observer
{
	_unregisterObserverCount++;
}
@end

@interface VariantUninstallMockContactAlertsController : NSObject
@property(nonatomic, readonly) NSMutableArray<NSString *> *registeredEventIDs;
@property(nonatomic, readonly) NSMutableArray<NSString *> *unregisteredEventIDs;

- (void)registerEventID:(NSString *)eventID
			withHandler:(id)handler
				inGroup:(AIEventHandlerGroupType)group
			 globalOnly:(BOOL)global;
- (void)unregisterEventID:(NSString *)eventID;
@end

@implementation VariantUninstallMockContactAlertsController
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

@interface VariantUninstallMockAdium : NSObject
@property(nonatomic, strong) id preferenceController;
@property(nonatomic, strong) id contactAlertsController;
@property(nonatomic, strong) id contentController;
@property(nonatomic, strong) id menuController;
@property(nonatomic, strong) id toolbarController;
@end

@implementation VariantUninstallMockAdium
@end

@interface PluginTeardownVariantUninstallTest : XCTestCase
@end

@implementation PluginTeardownVariantUninstallTest

// installPlugin registers CONTENT_NUDGE_BUZZ_OCCURED with itself as handler; uninstallPlugin must
// unregister it, or the uninstalled plugin keeps generating nudge/buzz alerts (#230).
- (void)testNudgeBuzzUnregistersEventOnUninstall
{
	VariantUninstallMockContactAlertsController *mockContactAlerts =
		[[VariantUninstallMockContactAlertsController alloc] init];
	VariantUninstallMockAdium *mockAdium = [[VariantUninstallMockAdium alloc] init];
	[mockAdium setContactAlertsController:mockContactAlerts];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		AINudgeBuzzHandlerPlugin *plugin = [[AINudgeBuzzHandlerPlugin alloc] init];
		[plugin installPlugin];

		// Hoisted to a local: an array literal with commas cannot sit directly in a macro argument —
		// the preprocessor splits on commas not inside parentheses, mangling the XCTAssertEqualObjects call.
		NSArray<NSString *> *expectedEventIDs = @[ CONTENT_NUDGE_BUZZ_OCCURED ];
		XCTAssertEqualObjects([mockContactAlerts registeredEventIDs], expectedEventIDs,
							  @"sanity: installPlugin registered the nudge/buzz event");

		[plugin uninstallPlugin];

		XCTAssertEqualObjects([mockContactAlerts unregisteredEventIDs], expectedEventIDs,
							  @"uninstallPlugin must unregister every event ID installPlugin registered");
	} @finally {
		adium = savedAdium;
	}
}

// installPlugin creates an ESGeneralPreferences pane; uninstallPlugin must remove it from the
// preference controller and release it, or the uninstalled plugin's pane stays in the preferences
// window (#231).
- (void)testESGeneralPreferencesPluginRemovesPaneOnUninstall
{
	VariantUninstallMockPreferenceController *mockPreferenceController =
		[[VariantUninstallMockPreferenceController alloc] init];
	VariantUninstallMockAdium *mockAdium = [[VariantUninstallMockAdium alloc] init];
	[mockAdium setPreferenceController:mockPreferenceController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		ESGeneralPreferencesPlugin *plugin = [[ESGeneralPreferencesPlugin alloc] init];
		[plugin setValue:[[NSObject alloc] init] forKey:@"preferences"];

		[plugin uninstallPlugin];

		XCTAssertEqual([mockPreferenceController removePreferencePaneCount], (NSUInteger)1,
					   @"uninstallPlugin must remove the pane installPlugin created");
		XCTAssertEqual([mockPreferenceController unregisterObserverCount], (NSUInteger)1,
					   @"uninstallPlugin must unregister the preference observer installPlugin registered");
		XCTAssertNil([plugin valueForKey:@"preferences"], @"uninstallPlugin must release the pane ivar");
	} @finally {
		adium = savedAdium;
	}
}

// installPlugin creates an AIMentionAdvancedPreferences pane; uninstallPlugin must remove it and
// release it (#231).
- (void)testMentionEventPluginRemovesPaneOnUninstall
{
	VariantUninstallMockPreferenceController *mockPreferenceController =
		[[VariantUninstallMockPreferenceController alloc] init];
	VariantUninstallMockAdium *mockAdium = [[VariantUninstallMockAdium alloc] init];
	[mockAdium setPreferenceController:mockPreferenceController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		AIMentionEventPlugin *plugin = [[AIMentionEventPlugin alloc] init];
		[plugin setValue:[[NSObject alloc] init] forKey:@"advancedPreferences"];

		[plugin uninstallPlugin];

		XCTAssertEqual([mockPreferenceController removeAdvancedPreferencePaneCount], (NSUInteger)1,
					   @"uninstallPlugin must remove the pane installPlugin created");
		XCTAssertEqual([mockPreferenceController unregisterObserverCount], (NSUInteger)1,
					   @"uninstallPlugin must unregister the preference observer installPlugin registered");
		XCTAssertNil([plugin valueForKey:@"advancedPreferences"], @"uninstallPlugin must release the pane ivar");
	} @finally {
		adium = savedAdium;
	}
}

// installPlugin creates an AIURLHandlerAdvancedPreferences pane; uninstallPlugin must remove it and
// release it (#231).
- (void)testURLHandlerPluginRemovesPaneOnUninstall
{
	VariantUninstallMockPreferenceController *mockPreferenceController =
		[[VariantUninstallMockPreferenceController alloc] init];
	VariantUninstallMockAdium *mockAdium = [[VariantUninstallMockAdium alloc] init];
	[mockAdium setPreferenceController:mockPreferenceController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		AIURLHandlerPlugin *plugin = [[AIURLHandlerPlugin alloc] init];
		[plugin setValue:[[NSObject alloc] init] forKey:@"preferences"];

		[plugin uninstallPlugin];

		XCTAssertEqual([mockPreferenceController removeAdvancedPreferencePaneCount], (NSUInteger)1,
					   @"uninstallPlugin must remove the pane installPlugin created");
		XCTAssertNil([plugin valueForKey:@"preferences"], @"uninstallPlugin must release the pane ivar");
	} @finally {
		adium = savedAdium;
	}
}

// installPlugin creates an AIAccountListPreferences pane; uninstallPlugin must remove it and
// release it (#231).
- (void)testAccountListPreferencesPluginRemovesPaneOnUninstall
{
	VariantUninstallMockPreferenceController *mockPreferenceController =
		[[VariantUninstallMockPreferenceController alloc] init];
	VariantUninstallMockAdium *mockAdium = [[VariantUninstallMockAdium alloc] init];
	[mockAdium setPreferenceController:mockPreferenceController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		AIAccountListPreferencesPlugin *plugin = [[AIAccountListPreferencesPlugin alloc] init];
		[plugin setValue:[[NSObject alloc] init] forKey:@"accountListPreferences"];

		[plugin uninstallPlugin];

		XCTAssertEqual([mockPreferenceController removePreferencePaneCount], (NSUInteger)1,
					   @"uninstallPlugin must remove the pane installPlugin created");
		XCTAssertNil([plugin valueForKey:@"accountListPreferences"], @"uninstallPlugin must release the pane ivar");
	} @finally {
		adium = savedAdium;
	}
}

// installPlugin creates an ESGlobalEventsPreferences pane; uninstallPlugin must remove it and
// release it (#231).
- (void)testGlobalEventsPreferencesPluginRemovesPaneOnUninstall
{
	VariantUninstallMockPreferenceController *mockPreferenceController =
		[[VariantUninstallMockPreferenceController alloc] init];
	VariantUninstallMockAdium *mockAdium = [[VariantUninstallMockAdium alloc] init];
	[mockAdium setPreferenceController:mockPreferenceController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		ESGlobalEventsPreferencesPlugin *plugin = [[ESGlobalEventsPreferencesPlugin alloc] init];
		[plugin setValue:[[NSObject alloc] init] forKey:@"preferences"];

		[plugin uninstallPlugin];

		XCTAssertEqual([mockPreferenceController removePreferencePaneCount], (NSUInteger)1,
					   @"uninstallPlugin must remove the pane installPlugin created");
		XCTAssertNil([plugin valueForKey:@"preferences"], @"uninstallPlugin must release the pane ivar");
	} @finally {
		adium = savedAdium;
	}
}

@end
