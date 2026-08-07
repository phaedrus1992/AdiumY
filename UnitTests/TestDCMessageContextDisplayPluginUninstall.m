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
#import <AdiumY/AISharedAdium.h>

/*
 * Link shims for the standalone test target. The plugin TU references AILoggerPlugin, AIXMLElement,
 * AIContentContext, AIContentStatus, and LMXParser by class name, which emit _OBJC_CLASS_$_ symbols
 * no linked framework provides (AIHTMLDecoder and AIContentMessage are shimmed in other test files in
 * this bundle; ISO8601DateFormatter ships in AIUtilities.framework). Each gets a minimal
 * implementation here. The shared `adium` global and the AIPlugin class are provided by
 * TestESUserIconHandlingPluginObserverRemoval.m in the same bundle — not redefined here.
 */
@interface AILoggerPlugin : NSObject
@end

@implementation AILoggerPlugin
@end

@interface AIXMLElement : NSObject
+ (id)elementWithName:(NSString *)name;
@end

@implementation AIXMLElement
+ (id)elementWithName:(NSString *)name
{
	return nil;
}
@end

@interface AIContentContext : NSObject
@end

@implementation AIContentContext
@end

@interface AIContentStatus : NSObject
@end

@implementation AIContentStatus
@end

#import <LMX/LMXParser.h>

@implementation LMXParser
+ (LMXParser *)parser
{
	return nil;
}

- (void)setDelegate:(id<LMXParserDelegate>)delegate
{}

- (void)setContextInfo:(void *)contextInfo
{}

- (void *)contextInfo
{
	return NULL;
}

- (enum LMXParseResult)parseChunk:(NSData *)chunk
{
	return LMXParsedIncomplete;
}

- (void)abortParsing
{}
@end

/*
 * The real DCMessageContextDisplayPlugin @implementation is wired into this bundle and provides the
 * _OBJC_CLASS_$_DCMessageContextDisplayPlugin symbol (along with +sharedInstance, installPlugin,
 * uninstallPlugin); the relaxed @interface below declares only the surface this test needs. Its real
 * header is not imported here so the standalone target doesn't pull in AIPlugin's dependencies.
 */
@interface DCMessageContextDisplayPlugin : NSObject
+ (DCMessageContextDisplayPlugin *)sharedInstance;
- (void)installPlugin;
- (void)uninstallPlugin;
@end

/*
 * Fakes for the shared-instance teardown test. DCPluginMockPreferenceController accepts the
 * registerDefaults:/registerPreferenceObserver:forGroup:/unregisterPreferenceObserver: sends
 * installPlugin and uninstallPlugin make; DCPluginMockAdium supplies the preference controller.
 */
@interface DCPluginMockPreferenceController : NSObject
- (void)registerDefaults:(NSDictionary *)defaultDict forGroup:(NSString *)group;
- (void)registerPreferenceObserver:(id)observer forGroup:(NSString *)group;
- (void)unregisterPreferenceObserver:(id)observer;
@end

@implementation DCPluginMockPreferenceController
- (void)registerDefaults:(NSDictionary *)defaultDict forGroup:(NSString *)group
{}

- (void)registerPreferenceObserver:(id)observer forGroup:(NSString *)group
{}

- (void)unregisterPreferenceObserver:(id)observer
{}
@end

@interface DCPluginMockAdium : NSObject
@property(nonatomic, strong) DCPluginMockPreferenceController *preferenceController;
@end

@implementation DCPluginMockAdium
@end

@interface DCMessageContextDisplayPluginUninstallTest : XCTestCase
@end

@implementation DCMessageContextDisplayPluginUninstallTest

// installPlugin sets the static sharedInstance; uninstallPlugin must clear it, or the uninstalled
// plugin keeps being handed out by +sharedInstance (#232).
- (void)testUninstallClearsSharedInstance
{
	DCPluginMockPreferenceController *mockPreferenceController = [[DCPluginMockPreferenceController alloc] init];
	DCPluginMockAdium *mockAdium = [[DCPluginMockAdium alloc] init];
	[mockAdium setPreferenceController:mockPreferenceController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		DCMessageContextDisplayPlugin *plugin = [[DCMessageContextDisplayPlugin alloc] init];

		XCTAssertNil([DCMessageContextDisplayPlugin sharedInstance],
					 @"sanity: sharedInstance is nil before installPlugin");

		[plugin installPlugin];
		XCTAssertEqualObjects([DCMessageContextDisplayPlugin sharedInstance], plugin,
							  @"sanity: installPlugin set sharedInstance");

		[plugin uninstallPlugin];
		XCTAssertNil([DCMessageContextDisplayPlugin sharedInstance],
					 @"uninstallPlugin must clear the sharedInstance installPlugin set");
	} @finally {
		adium = savedAdium;
	}
}

@end
