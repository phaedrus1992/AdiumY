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

#import <AdiumY/AIAdiumProtocol.h>
#import <AdiumY/AISharedAdium.h>

/*
 * Link shim for the standalone test target. The wired-in AIDualWindowInterfacePlugin TU sends
 * +[ESDualWindowMessageAdvancedPreferences preferencePane] in openInterface:, which emits an
 * _OBJC_CLASS_$_ reference no linked framework provides. The tests never invoke openInterface (the
 * pane ivar is injected via KVC), so the shim needs no factory method — the class symbol alone
 * satisfies the linker.
 */
@interface ESDualWindowMessageAdvancedPreferences : NSObject
@end

@implementation ESDualWindowMessageAdvancedPreferences
@end

/*
 * Link shims for the three container classes the wired-in AIDualWindowInterfacePlugin TU
 * instantiates (openChat: sends +[AIMessageViewController messageDisplayControllerForChat:],
 * +[AIMessageTabViewItem messageTabWithView:]; openContainerWithID: sends
 * +[AIMessageWindowController messageWindowControllerForInterface:withID:name:]). Their .m files are
 * not in the standalone test target, so the _OBJC_CLASS_$_ references need satisfied link symbols.
 * The tests never exercise those container paths, so the shims need no methods.
 */
@interface AIMessageTabViewItem : NSObject
@end

@implementation AIMessageTabViewItem
@end

@interface AIMessageViewController : NSObject
@end

@implementation AIMessageViewController
@end

@interface AIMessageWindowController : NSObject
@end

@implementation AIMessageWindowController
@end

/*
 * The real @implementation for AIDualWindowInterfacePlugin is wired into this bundle; the relaxed
 * @interface declares only the surface these tests need.
 */
@interface AIDualWindowInterfacePlugin : NSObject
- (void)uninstallPlugin;
- (void)closeInterface;
@end

/*
 * Fakes. DualWindowMockInterfaceController records unregisterInterfaceController: (what uninstallPlugin
 * must call); DualWindowMockPreferenceController records removeAdvancedPreferencePane: (what
 * closeInterface must call before releasing its pane ivar). The adium mock supplies whichever
 * controller a test needs.
 */
@interface DualWindowMockInterfaceController : NSObject
@property(nonatomic, assign) NSUInteger unregisterInterfaceControllerCount;
- (void)unregisterInterfaceController:(id)controller;
@end

@implementation DualWindowMockInterfaceController
- (void)unregisterInterfaceController:(id)controller
{
	_unregisterInterfaceControllerCount++;
}
@end

@interface DualWindowMockPreferenceController : NSObject
@property(nonatomic, assign) NSUInteger removeAdvancedPreferencePaneCount;
- (void)removeAdvancedPreferencePane:(id)inPane;
@end

@implementation DualWindowMockPreferenceController
- (void)removeAdvancedPreferencePane:(id)inPane
{
	_removeAdvancedPreferencePaneCount++;
}
@end

@interface DualWindowMockAdium : NSObject
@property(nonatomic, strong) id interfaceController;
@property(nonatomic, strong) id preferenceController;
@end

@implementation DualWindowMockAdium
@end

@interface AIDualWindowInterfacePluginUninstallTest : XCTestCase
@end

@implementation AIDualWindowInterfacePluginUninstallTest

// installPlugin: registers the plugin as an interface controller; uninstallPlugin: must undo that
// registration, or the uninstalled plugin stays wired into the interface controller (#236).
- (void)testUninstallUnregistersInterfaceController
{
	DualWindowMockInterfaceController *mockInterfaceController = [[DualWindowMockInterfaceController alloc] init];
	DualWindowMockAdium *mockAdium = [[DualWindowMockAdium alloc] init];
	[mockAdium setInterfaceController:mockInterfaceController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		AIDualWindowInterfacePlugin *plugin = [[AIDualWindowInterfacePlugin alloc] init];
		[plugin uninstallPlugin];

		XCTAssertEqual([mockInterfaceController unregisterInterfaceControllerCount], (NSUInteger)1,
					   @"uninstallPlugin must unregister the interface controller installPlugin registered");
	} @finally {
		adium = savedAdium;
	}
}

// uninstallPlugin: must close the interface before unregistering. The component loader uninstalls
// components (AIAdium.m controllerWillClose) before the interface controller's own controllerWillClose
// would close the interface, so unregistering first would skip closeInterface's window/observer/pane
// cleanup entirely on the shutdown path (#236).
- (void)testUninstallClosesInterfaceBeforeUnregistering
{
	DualWindowMockInterfaceController *mockInterfaceController = [[DualWindowMockInterfaceController alloc] init];
	DualWindowMockPreferenceController *mockPreferenceController = [[DualWindowMockPreferenceController alloc] init];
	DualWindowMockAdium *mockAdium = [[DualWindowMockAdium alloc] init];
	[mockAdium setInterfaceController:mockInterfaceController];
	[mockAdium setPreferenceController:mockPreferenceController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		AIDualWindowInterfacePlugin *plugin = [[AIDualWindowInterfacePlugin alloc] init];
		[plugin setValue:[[NSObject alloc] init] forKey:@"preferenceMessageAdvController"];

		[plugin uninstallPlugin];

		XCTAssertEqual([mockPreferenceController removeAdvancedPreferencePaneCount], (NSUInteger)1,
					   @"uninstallPlugin must close the interface, removing the advanced preference pane");
		XCTAssertEqual([mockInterfaceController unregisterInterfaceControllerCount], (NSUInteger)1,
					   @"uninstallPlugin must also unregister the interface controller");
	} @finally {
		adium = savedAdium;
	}
}

// openInterface: creates an ESDualWindowMessageAdvancedPreferences pane; closeInterface: must remove
// it from the preference controller before releasing the ivar, or the pane lingers in the
// preferences window after the plugin unloads (#236).
- (void)testCloseInterfaceRemovesAdvancedPreferencePane
{
	DualWindowMockPreferenceController *mockPreferenceController = [[DualWindowMockPreferenceController alloc] init];
	DualWindowMockAdium *mockAdium = [[DualWindowMockAdium alloc] init];
	[mockAdium setPreferenceController:mockPreferenceController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		AIDualWindowInterfacePlugin *plugin = [[AIDualWindowInterfacePlugin alloc] init];
		[plugin setValue:[[NSObject alloc] init] forKey:@"preferenceMessageAdvController"];

		[plugin closeInterface];

		XCTAssertEqual([mockPreferenceController removeAdvancedPreferencePaneCount], (NSUInteger)1,
					   @"closeInterface must remove the advanced preference pane openInterface created");
		XCTAssertNil([plugin valueForKey:@"preferenceMessageAdvController"],
					 @"closeInterface must release the pane ivar");
	} @finally {
		adium = savedAdium;
	}
}

@end
