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

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

/*
 * Link shims for the standalone test target. The plugin TU references AIStatus (statusOfType:), its
 * superclass AIStatusItem, and AIHTMLDecoder (decodeHTML:) by class name, which emit _OBJC_CLASS_$
 * symbols no linked framework provides (they live in Adium.framework), so each gets an implementation
 * here. AIStatus and AIStatusItem are declared with relaxed superclasses so the heavy real headers
 * (and AIStatusItem's NSCoding conformance) stay out of this TU; the plugin's own TU imports the real
 * ones. The shared `adium` global and the AIPlugin class are provided by
 * TestESUserIconHandlingPluginObserverRemoval.m in the same bundle — not redefined here.
 */
@interface AIStatusItem : NSObject
- (void)setTitle:(NSString *)inTitle;
- (void)setUniqueStatusID:(NSNumber *)inUniqueStatusID;
@end

@implementation AIStatusItem
- (void)setTitle:(NSString *)inTitle
{}

- (void)setUniqueStatusID:(NSNumber *)inUniqueStatusID
{}
@end

@interface AIStatus : AIStatusItem
+ (instancetype)statusOfType:(NSInteger)inStatusType;
- (void)setStatusMessage:(NSAttributedString *)statusMessage;
- (void)setMutabilityType:(NSInteger)mutabilityType;
- (void)setSpecialStatusType:(NSInteger)specialStatusType;
@end

@implementation AIStatus
+ (instancetype)statusOfType:(NSInteger)inStatusType
{
	return [[self alloc] init];
}

- (void)setStatusMessage:(NSAttributedString *)statusMessage
{}

- (void)setMutabilityType:(NSInteger)mutabilityType
{}

- (void)setSpecialStatusType:(NSInteger)specialStatusType
{}
@end

@interface AIHTMLDecoder : NSObject
@end

@implementation AIHTMLDecoder
@end

#import <AdiumY/AIPlugin.h>
#import "ESiTunesPlugin.h"

/*
 * Declares the installPlugin internals the test subclass overrides or calls super on. These live in
 * ESiTunesPlugin.m's class extension, which this TU does not see; declaring them on a category here
 * makes the overrides and the [super ...] call compile without importing the real AIStatus headers.
 */
@interface ESiTunesPlugin (ItunesTestDeclarations)
- (BOOL)meetsMinimumiTunesVersionForPath:(NSString *)path;
- (void)createiTunesToolbarItemWithPath:(NSString *)path;
@end

/*
 * Fakes for the teardown tests. Each records the register/unregister calls installPlugin and
 * uninstallPlugin make, so a test can assert uninstallPlugin undoes exactly what installPlugin did.
 * ItunesMockAdium is a plain NSObject (never formally conforming to <AIAdium>) installed via
 * `adium = (id<AIAdium>)mockAdium`; its preferenceController accessor returns nil so
 * updateiTunesCurrentTrackFormat's preference reads and writes no-op instead of raising.
 */
@interface ItunesMockContentController : NSObject
@property(nonatomic, strong) id registeredFilter;
@property(nonatomic, strong) id unregisteredFilter;
@property(nonatomic, assign) NSUInteger registerCount;
@property(nonatomic, assign) NSUInteger unregisterCount;

- (void)registerContentFilter:(id)filter ofType:(NSInteger)type direction:(NSInteger)direction;
- (void)unregisterContentFilter:(id)filter;
@end

@implementation ItunesMockContentController
- (void)registerContentFilter:(id)filter ofType:(NSInteger)type direction:(NSInteger)direction
{
	_registeredFilter = filter;
	_registerCount++;
}

- (void)unregisterContentFilter:(id)filter
{
	_unregisteredFilter = filter;
	_unregisterCount++;
}
@end

@interface ItunesMockToolbarController : NSObject
@property(nonatomic, strong) NSToolbarItem *registeredItem;
@property(nonatomic, strong) NSToolbarItem *unregisteredItem;
@property(nonatomic, copy) NSString *registeredToolbarType;
@property(nonatomic, copy) NSString *unregisteredToolbarType;
@property(nonatomic, assign) NSUInteger registerCount;
@property(nonatomic, assign) NSUInteger unregisterCount;

- (void)registerToolbarItem:(NSToolbarItem *)item forToolbarType:(NSString *)toolbarType;
- (void)unregisterToolbarItem:(NSToolbarItem *)item forToolbarType:(NSString *)toolbarType;
@end

@implementation ItunesMockToolbarController
- (void)registerToolbarItem:(NSToolbarItem *)item forToolbarType:(NSString *)toolbarType
{
	_registeredItem = item;
	_registeredToolbarType = toolbarType;
	_registerCount++;
}

- (void)unregisterToolbarItem:(NSToolbarItem *)item forToolbarType:(NSString *)toolbarType
{
	_unregisteredItem = item;
	_unregisteredToolbarType = toolbarType;
	_unregisterCount++;
}
@end

@interface ItunesMockStatusController : NSObject
@property(nonatomic, strong) AIStatus *addedStatusState;
@property(nonatomic, strong) AIStatus *removedStatusState;
@property(nonatomic, assign) NSUInteger addCount;
@property(nonatomic, assign) NSUInteger removeCount;

- (void)addStatusState:(AIStatus *)statusState;
- (void)removeStatusState:(AIStatus *)statusState;
@end

@implementation ItunesMockStatusController
- (void)addStatusState:(AIStatus *)statusState
{
	_addedStatusState = statusState;
	_addCount++;
}

- (void)removeStatusState:(AIStatus *)statusState
{
	_removedStatusState = statusState;
	_removeCount++;
}
@end

@interface ItunesMockMenuController : NSObject
@property(nonatomic, strong) NSMenuItem *registeredMenuItem;
@property(nonatomic, strong) NSMenuItem *removedMenuItem;
@property(nonatomic, strong) NSMenuItem *registeredContextualMenuItem;
@property(nonatomic, strong) NSMenuItem *removedContextualMenuItem;
@property(nonatomic, assign) NSUInteger addMenuItemCount;
@property(nonatomic, assign) NSUInteger removeMenuItemCount;
@property(nonatomic, assign) NSUInteger addContextualMenuItemCount;
@property(nonatomic, assign) NSUInteger removeContextualMenuItemCount;

- (void)addMenuItem:(NSMenuItem *)menuItem toLocation:(NSInteger)location;
- (void)removeMenuItem:(NSMenuItem *)menuItem;
- (void)addContextualMenuItem:(NSMenuItem *)menuItem toLocation:(NSInteger)location;
- (void)removeContextualMenuItem:(NSMenuItem *)menuItem;
@end

@implementation ItunesMockMenuController
- (void)addMenuItem:(NSMenuItem *)menuItem toLocation:(NSInteger)location
{
	_registeredMenuItem = menuItem;
	_addMenuItemCount++;
}

- (void)removeMenuItem:(NSMenuItem *)menuItem
{
	_removedMenuItem = menuItem;
	_removeMenuItemCount++;
}

- (void)addContextualMenuItem:(NSMenuItem *)menuItem toLocation:(NSInteger)location
{
	_registeredContextualMenuItem = menuItem;
	_addContextualMenuItemCount++;
}

- (void)removeContextualMenuItem:(NSMenuItem *)menuItem
{
	_removedContextualMenuItem = menuItem;
	_removeContextualMenuItemCount++;
}
@end

@interface ItunesMockAdium : NSObject
@property(nonatomic, strong) ItunesMockContentController *contentController;
@property(nonatomic, strong) ItunesMockToolbarController *toolbarController;
@property(nonatomic, strong) ItunesMockStatusController *statusController;
@property(nonatomic, strong) ItunesMockMenuController *menuController;
@end

@implementation ItunesMockAdium
- (id)preferenceController
{
	return nil;
}
@end

/*
 * The install gate is a minimum-iTunes-version check against the app at a path; iTunes is not
 * installed on CI machines, so the test subclass forces the check YES. createiTunesToolbarItemWithPath:
 * is forwarded with the test bundle's own path so the real registration path (and its iconForFile:)
 * runs without an iTunes install. currentTrackFormatDidChange: counts instead of doing real work.
 */
@interface ItunesInstallTrackingPlugin : ESiTunesPlugin
@property(nonatomic, assign) NSUInteger currentTrackFormatDidChangeCount;
@end

@implementation ItunesInstallTrackingPlugin
- (BOOL)meetsMinimumiTunesVersionForPath:(NSString *)path
{
	return YES;
}

- (void)createiTunesToolbarItemWithPath:(NSString *)path
{
	[super createiTunesToolbarItemWithPath:[[NSBundle mainBundle] bundlePath]];
}

- (void)currentTrackFormatDidChange:(NSNotification *)notification
{
	_currentTrackFormatDidChangeCount++;
}
@end

@interface ESiTunesPluginObserverRemovalTest : XCTestCase
@end

@implementation ESiTunesPluginObserverRemovalTest

// installPlugin registers the Adium_CurrentTrackFormatChangedNotification observer; uninstallPlugin
// must remove it, or the plugin keeps updating the current-track format after it is uninstalled.
// installPlugin runs against a nil adium here: its controller messages no-op, leaving the observer
// registration as the only observable side effect.
- (void)testUninstallRemovesCurrentTrackFormatObserver
{
	ItunesInstallTrackingPlugin *plugin = [[ItunesInstallTrackingPlugin alloc] init];
	[plugin installPlugin];

	// Positive control: the observer must fire while installed, or this test cannot tell
	// "removed by uninstallPlugin" from "never registered at all".
	XCTAssertEqual([plugin currentTrackFormatDidChangeCount], (NSUInteger)0,
				   @"sanity: installPlugin does not fire the current-track-format observer");
	[[NSNotificationCenter defaultCenter] postNotificationName:Adium_CurrentTrackFormatChangedNotification
														object:nil];
	XCTAssertEqual([plugin currentTrackFormatDidChangeCount], (NSUInteger)1,
				   @"sanity: Adium_CurrentTrackFormatChangedNotification observer fired while installed");

	[plugin uninstallPlugin];
	[[NSNotificationCenter defaultCenter] postNotificationName:Adium_CurrentTrackFormatChangedNotification
														object:nil];
	XCTAssertEqual([plugin currentTrackFormatDidChangeCount], (NSUInteger)1,
				   @"Adium_CurrentTrackFormatChangedNotification observer still registered after uninstallPlugin");
}

// installPlugin registers a content filter, a toolbar item, a status state and two menu items;
// uninstallPlugin must unregister/remove exactly those same objects, or they are left dead after the
// plugin uninstalls.
- (void)testUninstallUnregistersResources
{
	ItunesMockContentController *mockContentController = [[ItunesMockContentController alloc] init];
	ItunesMockToolbarController *mockToolbarController = [[ItunesMockToolbarController alloc] init];
	ItunesMockStatusController *mockStatusController = [[ItunesMockStatusController alloc] init];
	ItunesMockMenuController *mockMenuController = [[ItunesMockMenuController alloc] init];
	ItunesMockAdium *mockAdium = [[ItunesMockAdium alloc] init];
	[mockAdium setContentController:mockContentController];
	[mockAdium setToolbarController:mockToolbarController];
	[mockAdium setStatusController:mockStatusController];
	[mockAdium setMenuController:mockMenuController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		ItunesInstallTrackingPlugin *plugin = [[ItunesInstallTrackingPlugin alloc] init];
		[plugin installPlugin];

		XCTAssertEqual([mockContentController registerCount], (NSUInteger)1,
					   @"sanity: content filter registered once at install");
		XCTAssertEqual([mockToolbarController registerCount], (NSUInteger)1,
					   @"sanity: toolbar item registered once at install");
		XCTAssertEqualObjects([mockToolbarController registeredToolbarType], @"TextEntry",
							  @"sanity: toolbar item registered in the TextEntry toolbar");
		XCTAssertEqual([mockStatusController addCount], (NSUInteger)1,
					   @"sanity: status state added once at install");
		XCTAssertEqual([mockMenuController addMenuItemCount], (NSUInteger)1,
					   @"sanity: Edit > Insert menu item added once at install");
		XCTAssertEqual([mockMenuController addContextualMenuItemCount], (NSUInteger)1,
					   @"sanity: contextual menu item added once at install");

		[plugin uninstallPlugin];

		XCTAssertEqual([mockContentController unregisterCount], (NSUInteger)1,
					   @"uninstallPlugin did not unregister the content filter");
		XCTAssertEqual([mockToolbarController unregisterCount], (NSUInteger)1,
					   @"uninstallPlugin did not unregister the toolbar item");
		XCTAssertTrue([mockToolbarController unregisteredItem] == [mockToolbarController registeredItem],
					  @"uninstallPlugin unregistered a different toolbar item than registerToolbarItem registered");
		XCTAssertEqualObjects([mockToolbarController unregisteredToolbarType], @"TextEntry",
							  @"uninstallPlugin unregistered the toolbar item in a different toolbar than it was registered");
		XCTAssertEqual([mockStatusController removeCount], (NSUInteger)1,
					   @"uninstallPlugin did not remove the status state");
		XCTAssertTrue([mockStatusController removedStatusState] == [mockStatusController addedStatusState],
					  @"uninstallPlugin removed a different status state than addStatusState added");
		XCTAssertEqual([mockMenuController removeMenuItemCount], (NSUInteger)1,
					   @"uninstallPlugin did not remove the Edit > Insert menu item");
		XCTAssertEqual([mockMenuController removeContextualMenuItemCount], (NSUInteger)1,
					   @"uninstallPlugin did not remove the contextual menu item");
	} @finally {
		adium = savedAdium;
	}
}

// The toolbar/status/menu unregister calls are guarded on the registered ivars being non-nil:
// uninstalling a plugin whose installPlugin never ran must not unregister resources that were never
// registered (the real controllers' nil-keyed removals would raise). The content-filter removal is
// unconditional and is a no-op against a never-registered filter.
- (void)testUninstallWithoutInstallSkipsResourceUnregister
{
	ItunesMockContentController *mockContentController = [[ItunesMockContentController alloc] init];
	ItunesMockToolbarController *mockToolbarController = [[ItunesMockToolbarController alloc] init];
	ItunesMockStatusController *mockStatusController = [[ItunesMockStatusController alloc] init];
	ItunesMockMenuController *mockMenuController = [[ItunesMockMenuController alloc] init];
	ItunesMockAdium *mockAdium = [[ItunesMockAdium alloc] init];
	[mockAdium setContentController:mockContentController];
	[mockAdium setToolbarController:mockToolbarController];
	[mockAdium setStatusController:mockStatusController];
	[mockAdium setMenuController:mockMenuController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		ItunesInstallTrackingPlugin *plugin = [[ItunesInstallTrackingPlugin alloc] init];
		[plugin uninstallPlugin];

		XCTAssertEqual([mockContentController unregisterCount], (NSUInteger)1,
					   @"content filter unregistered unconditionally by uninstallPlugin");
		XCTAssertEqual([mockToolbarController unregisterCount], (NSUInteger)0,
					   @"uninstallPlugin unregistered a toolbar item that was never registered");
		XCTAssertEqual([mockStatusController removeCount], (NSUInteger)0,
					   @"uninstallPlugin removed a status state that was never added");
		XCTAssertEqual([mockMenuController removeMenuItemCount], (NSUInteger)0,
					   @"uninstallPlugin removed a menu item that was never added");
		XCTAssertEqual([mockMenuController removeContextualMenuItemCount], (NSUInteger)0,
					   @"uninstallPlugin removed a contextual menu item that was never added");
	} @finally {
		adium = savedAdium;
	}
}

@end
