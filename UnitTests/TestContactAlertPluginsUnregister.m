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

#import <AdiumY/AIActionDetailsPane.h>
#import <AdiumY/AISharedAdium.h>

#import "AIDoNothingContactAlertPlugin.h"
#import "AIDockBehaviorPlugin.h"
#import "AIDockNameOverlay.h"
#import "AIEventSoundsPlugin.h"
#import "ESAnnouncerPlugin.h"
#import "ESApplescriptContactAlertPlugin.h"
#import "ESOpenMessageWindowContactAlertPlugin.h"
#import "ESSendMessageContactAlertPlugin.h"
#import "NEHUserNotificationPlugin.h"
#import "SMContactListShowBehaviorPlugin.h"

/*
 * Link shims for the standalone test target. Each plugin TU sends a class message to its details
 * pane and/or data classes (e.g. [ESSendMessageAlertDetailPane actionDetailsPane]), which emits
 * _OBJC_CLASS_$_ symbols no linked framework provides, so each gets a nil-returning implementation
 * here. The shared `adium` global, the AIPlugin class, and the AIListContact / AIMetaContact /
 * AIAccount / AIContactObserverManager classes come from the other test files in the same bundle —
 * not redefined here.
 */
#define DETAIL_PANE_SHIM(ClassName)                                                                                    \
	@interface ClassName : AIActionDetailsPane                                                                         \
	+(AIActionDetailsPane *)actionDetailsPane;                                                                         \
	@end                                                                                                               \
	@implementation ClassName                                                                                          \
	+(AIActionDetailsPane *)actionDetailsPane                                                                          \
	{                                                                                                                  \
		return nil;                                                                                                    \
	}                                                                                                                  \
	@end

DETAIL_PANE_SHIM(ESEventSoundAlertDetailPane)
DETAIL_PANE_SHIM(ESDockAlertDetailPane)
DETAIL_PANE_SHIM(ESAnnouncerSpeakEventAlertDetailPane)
DETAIL_PANE_SHIM(ESAnnouncerSpeakTextAlertDetailPane)
DETAIL_PANE_SHIM(ESPanelApplescriptDetailPane)
DETAIL_PANE_SHIM(ESSendMessageAlertDetailPane)
DETAIL_PANE_SHIM(SMContactListShowDetailsPane)

#undef DETAIL_PANE_SHIM

/*
 * Link shim for the debug-logging symbol. ESDebugAILog.h (reached via Adium.pch in the real app)
 * declares AILogWithSignature_impl, which ESSendMessageContactAlertPlugin.m calls; the standalone
 * test bundle links no debug-logging implementation, so this no-op satisfies the undefined symbol.
 */
void AILogWithSignature_impl(const char *function, int line, NSString *format, ...)
{
	// No-op: the standalone test bundle links no debug-logging implementation.
}

@interface AIContentMessage : NSObject
+ (id)messageInChat:(id)inChat
		 withSource:(id)inSource
		destination:(id)inDestination
			   date:(NSDate *)inDate
			message:(id)inMessage
		  autoreply:(BOOL)inAutoreply;
@end

@implementation AIContentMessage
+ (id)messageInChat:(id)inChat
		 withSource:(id)inSource
		destination:(id)inDestination
			   date:(NSDate *)inDate
			message:(id)inMessage
		  autoreply:(BOOL)inAutoreply
{
	return nil;
}
@end

@interface ESFileTransfer : NSObject
+ (id)existingFileTransferWithID:(NSString *)fileTransferID;
- (void)reveal;
@end

@implementation ESFileTransfer
+ (id)existingFileTransferWithID:(NSString *)fileTransferID
{
	return nil;
}

- (void)reveal
{}
@end

/*
 * Records which action IDs installPlugin registered and which uninstallPlugin unregistered, so a
 * test can assert the plugin undoes exactly what it set up.
 */
@interface ContactAlertsMockController : NSObject
@property(nonatomic, readonly) NSMutableArray<NSString *> *registeredActionIDs;
@property(nonatomic, readonly) NSMutableArray<NSString *> *unregisteredActionIDs;

- (void)registerActionID:(NSString *)actionID withHandler:(id)handler;
- (void)unregisterActionID:(NSString *)actionID;
@end

@implementation ContactAlertsMockController
- (instancetype)init
{
	if ((self = [super init])) {
		_registeredActionIDs = [[NSMutableArray alloc] init];
		_unregisteredActionIDs = [[NSMutableArray alloc] init];
	}

	return self;
}

- (void)registerActionID:(NSString *)actionID withHandler:(id)handler
{
	[_registeredActionIDs addObject:actionID];
}

- (void)unregisterActionID:(NSString *)actionID
{
	[_unregisteredActionIDs addObject:actionID];
}
@end

/*
 * The contact-alert plugins reach through `adium` for several controllers during install; every
 * accessor beyond contactAlertsController must return nil (not crash), since the plugins only
 * call into the real controllers on code paths the tests do not exercise.
 */
@interface ContactAlertsMockAdium : NSObject
@property(nonatomic, strong) ContactAlertsMockController *contactAlertsController;

- (id)preferenceController;
- (id)chatController;
- (id)soundController;
- (id)interfaceController;
@end

@implementation ContactAlertsMockAdium
- (id)preferenceController
{
	return nil;
}

- (id)chatController
{
	return nil;
}

- (id)soundController
{
	return nil;
}

- (id)interfaceController
{
	return nil;
}
@end

@interface ContactAlertPluginsUnregisterTest : XCTestCase
- (void)assertPlugin:(AIPlugin *)plugin
	  registersActionIDs:(NSArray<NSString *> *)expectedRegistered
	unregistersActionIDs:(NSArray<NSString *> *)expectedUnregistered;
@end

@implementation ContactAlertPluginsUnregisterTest

- (void)assertPlugin:(AIPlugin *)plugin
	  registersActionIDs:(NSArray<NSString *> *)expectedRegistered
	unregistersActionIDs:(NSArray<NSString *> *)expectedUnregistered
{
	ContactAlertsMockController *mockController = [[ContactAlertsMockController alloc] init];
	ContactAlertsMockAdium *mockAdium = [[ContactAlertsMockAdium alloc] init];
	[mockAdium setContactAlertsController:mockController];

	id<AIAdium> savedAdium = adium;
	adium = (id<AIAdium>)mockAdium;
	@try {
		[plugin installPlugin];
		XCTAssertEqualObjects([mockController registeredActionIDs], expectedRegistered,
							  @"installPlugin registered the wrong contact-alert actions");
		[plugin uninstallPlugin];
		XCTAssertEqualObjects([mockController unregisteredActionIDs], expectedUnregistered,
							  @"uninstallPlugin must unregister exactly the actions installPlugin registered");
	} @finally {
		adium = savedAdium;
	}
}

// #219 — each contact-alert plugin must unregister the action handler it registered at install,
// or a removed plugin keeps handling (and firing) alerts for events that still occur.
- (void)testEventSoundsPluginUnregistersItsAction
{
	[self assertPlugin:[[AIEventSoundsPlugin alloc] init]
		  registersActionIDs:@[ @"PlaySound" ]
		unregistersActionIDs:@[ @"PlaySound" ]];
}

- (void)testDockBehaviorPluginUnregistersItsAction
{
	[self assertPlugin:[[AIDockBehaviorPlugin alloc] init]
		  registersActionIDs:@[ AIDockBehavior_ALERT_IDENTIFIER ]
		unregistersActionIDs:@[ AIDockBehavior_ALERT_IDENTIFIER ]];
}

- (void)testAnnouncerPluginUnregistersBothItsActions
{
	[self assertPlugin:[[ESAnnouncerPlugin alloc] init]
		  registersActionIDs:@[ SPEAK_TEXT_ALERT_IDENTIFIER, SPEAK_EVENT_ALERT_IDENTIFIER ]
		unregistersActionIDs:@[ SPEAK_TEXT_ALERT_IDENTIFIER, SPEAK_EVENT_ALERT_IDENTIFIER ]];
}

- (void)testApplescriptContactAlertPluginUnregistersItsAction
{
	[self assertPlugin:[[ESApplescriptContactAlertPlugin alloc] init]
		  registersActionIDs:@[ APPLESCRIPT_CONTACT_ALERT_IDENTIFIER ]
		unregistersActionIDs:@[ APPLESCRIPT_CONTACT_ALERT_IDENTIFIER ]];
}

- (void)testDoNothingContactAlertPluginUnregistersItsAction
{
	[self assertPlugin:[[AIDoNothingContactAlertPlugin alloc] init]
		  registersActionIDs:@[ DO_NOTHING_ALERT_IDENTIFIER ]
		unregistersActionIDs:@[ DO_NOTHING_ALERT_IDENTIFIER ]];
}

- (void)testOpenMessageWindowContactAlertPluginUnregistersItsAction
{
	// installPlugin uses the literal @"OpenMessageWindow" (the header's CONTACT_ALERT_IDENTIFIER
	// macro is a different string), so assert against the literal.
	[self assertPlugin:[[ESOpenMessageWindowContactAlertPlugin alloc] init]
		  registersActionIDs:@[ @"OpenMessageWindow" ]
		unregistersActionIDs:@[ @"OpenMessageWindow" ]];
}

- (void)testUserNotificationPluginUnregistersItsAction
{
	[self assertPlugin:[[NEHUserNotificationPlugin alloc] init]
		  registersActionIDs:@[ USER_NOTIFICATION_ALERT_IDENTIFIER ]
		unregistersActionIDs:@[ USER_NOTIFICATION_ALERT_IDENTIFIER ]];
}

- (void)testSendMessageContactAlertPluginUnregistersItsAction
{
	[self assertPlugin:[[ESSendMessageContactAlertPlugin alloc] init]
		  registersActionIDs:@[ @"SendMessage" ]
		unregistersActionIDs:@[ @"SendMessage" ]];
}

- (void)testContactListShowBehaviorPluginUnregistersItsAction
{
	[self assertPlugin:[[SMContactListShowBehaviorPlugin alloc] init]
		  registersActionIDs:@[ SHOW_CONTACT_LIST_BEHAVIOR_ALERT_IDENTIFIER ]
		unregistersActionIDs:@[ SHOW_CONTACT_LIST_BEHAVIOR_ALERT_IDENTIFIER ]];
}

- (void)testDockNameOverlayUnregistersItsAction
{
	[self assertPlugin:[[AIDockNameOverlay alloc] init]
		  registersActionIDs:@[ DOCK_OVERLAY_ALERT_IDENTIFIER ]
		unregistersActionIDs:@[ DOCK_OVERLAY_ALERT_IDENTIFIER ]];
}

@end
