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
#import <AdiumY/AIPlugin.h>
#import <AdiumY/AISharedAdium.h>
// clang-format on

/*
 * Bare @interface only — the wired CBPurpleServicePlugin.m provides the class symbol and the real
 * installPlugin/uninstallPlugin bodies. Redeclaring the class here (same superclass, declaration
 * only, no @implementation) lets this TU send alloc/init/installPlugin/uninstallPlugin without
 * importing the plugin's own headers.
 */
@interface CBPurpleServicePlugin : AIPlugin
@end

/*
 * Recording service shims. The real CBPurpleServicePlugin.m sends +registerService to ESIRCService,
 * ESSimpleService, and ESJabberService at install (results currently discarded — #241) and must
 * send -unregisterService to each at uninstall. These shims bind to those class symbols at link
 * and count the calls. They deliberately subclass NSObject (not the real AIService) so +registerService
 * can return a live instance without pulling in real AIService -init.
 */
static NSUInteger sServiceRegisterCount = 0;
static NSUInteger sServiceUnregisterCount = 0;

@interface PurpleServiceShim : NSObject
+ (id)registerService;
- (void)unregisterService;
@end

@implementation PurpleServiceShim
+ (id)registerService
{
	sServiceRegisterCount++;
	return [[self alloc] init];
}

- (void)unregisterService
{
	sServiceUnregisterCount++;
}
@end

@interface ESIRCService : PurpleServiceShim
@end

@implementation ESIRCService
@end

@interface ESSimpleService : PurpleServiceShim
@end

@implementation ESSimpleService
@end

@interface ESJabberService : PurpleServiceShim
@end

@implementation ESJabberService
@end

/*
 * Link shims for the classes the plugin TU instantiates or class-sends during install/uninstall.
 * SLPurpleCocoaAdapter's +pluginDidLoad is executed by installPlugin; the sub-plugins get
 * alloc/init/installPlugin/uninstallPlugin. All no-op here — they aren't the subject of #241.
 */
@interface SLPurpleCocoaAdapter : NSObject
+ (void)pluginDidLoad;
@end

@implementation SLPurpleCocoaAdapter
+ (void)pluginDidLoad
{}
@end

@interface AMPurpleTuneTooltip : NSObject
@end

@implementation AMPurpleTuneTooltip
@end

@interface AIIRCServicesPasswordPlugin : NSObject
- (void)installPlugin;
- (void)uninstallPlugin;
@end

@implementation AIIRCServicesPasswordPlugin
- (void)installPlugin
{}
- (void)uninstallPlugin
{}
@end

@interface AIAnnoyingIRCMessagesHiderPlugin : NSObject
- (void)installPlugin;
- (void)uninstallPlugin;
@end

@implementation AIAnnoyingIRCMessagesHiderPlugin
- (void)installPlugin
{}
- (void)uninstallPlugin
{}
@end

/*
 * Mocks for the adium services installPlugin reads. preferenceController gets registerDefaults:forGroup:;
 * interfaceController gets the tooltip registration/unregistration calls. Named uniquely per test
 * bundle (the same generic mock names exist in the pre-existing ESUserIconHandling test).
 */
@interface CBPurpleMockPreferenceController : NSObject
@property(nonatomic, assign) NSUInteger registerDefaultsCount;
- (void)registerDefaults:(NSDictionary *)defaults forGroup:(NSString *)group;
@end

@implementation CBPurpleMockPreferenceController
- (void)registerDefaults:(NSDictionary *)defaults forGroup:(NSString *)group
{
	_registerDefaultsCount++;
}
@end

@interface CBPurpleMockInterfaceController : NSObject
@property(nonatomic, assign) NSUInteger registerTooltipCount;
@property(nonatomic, assign) NSUInteger unregisterTooltipCount;
- (void)registerContactListTooltipEntry:(id)entry secondaryEntry:(BOOL)secondary;
- (void)unregisterContactListTooltipEntry:(id)entry secondaryEntry:(BOOL)secondary;
@end

@implementation CBPurpleMockInterfaceController
- (void)registerContactListTooltipEntry:(id)entry secondaryEntry:(BOOL)secondary
{
	_registerTooltipCount++;
}

- (void)unregisterContactListTooltipEntry:(id)entry secondaryEntry:(BOOL)secondary
{
	_unregisterTooltipCount++;
}
@end

@interface CBPurpleMockAdium : NSObject
@property(nonatomic, strong) CBPurpleMockPreferenceController *preferenceController;
@property(nonatomic, strong) CBPurpleMockInterfaceController *interfaceController;
@end

@implementation CBPurpleMockAdium
@end

@interface CBPurpleServicePluginUninstallTest : XCTestCase
@end

@implementation CBPurpleServicePluginUninstallTest

- (void)setUp
{
	sServiceRegisterCount = 0;
	sServiceUnregisterCount = 0;
}

// installPlugin registers ESIRCService, ESSimpleService, and ESJabberService; uninstallPlugin must
// unregister each of them, or the uninstalled plugin leaves its services registered in the account
// registry and status controller (#241).
- (void)testUninstallUnregistersAllThreeServices
{
	CBPurpleMockPreferenceController *preferenceController = [[CBPurpleMockPreferenceController alloc] init];
	CBPurpleMockInterfaceController *interfaceController = [[CBPurpleMockInterfaceController alloc] init];
	CBPurpleMockAdium *mockAdium = [[CBPurpleMockAdium alloc] init];
	mockAdium.preferenceController = preferenceController;
	mockAdium.interfaceController = interfaceController;

	id<AIAdium> savedAdium = adium;
	@try {
		adium = (id<AIAdium>)mockAdium;

		CBPurpleServicePlugin *plugin = [[CBPurpleServicePlugin alloc] init];
		[plugin installPlugin];

		XCTAssertEqual(sServiceRegisterCount, (NSUInteger)3,
					   @"sanity: installPlugin registers ESIRC, ESSimple, and ESJabber services");
		XCTAssertEqual(preferenceController.registerDefaultsCount, (NSUInteger)1,
					   @"sanity: installPlugin registered default preferences once");

		[plugin uninstallPlugin];

		XCTAssertEqual(sServiceUnregisterCount, (NSUInteger)3,
					   @"uninstallPlugin did not unregister all three services it registered");
		XCTAssertEqual(interfaceController.unregisterTooltipCount, (NSUInteger)1,
					   @"sanity: uninstallPlugin still removes the tune tooltip entry");
	} @finally {
		adium = savedAdium;
	}
}

@end
