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

/*
 * Stub for the standalone CoverageHost test target. Provides just enough of the real
 * AIContactAlertsController protocol for ErrorMessageHandlerPlugin.m to compile without an
 * AdiumY.framework binary. AIPlugin is pulled in here (not in the real header) because the plugin
 * TU has no prefix header and ErrorMessageHandlerPlugin.h declares its superclass; the shared
 * `adium` extern comes along via AISharedAdium.h. INTERFACE_ERROR_MESSAGE is defined in the real
 * AIAdiumProtocol.h — provided here because this header (not AIAdiumProtocol.h) is in the plugin
 * TU's import chain.
 */
#import <Foundation/Foundation.h>

#import <AdiumY/AIControllerProtocol.h>
#import <AdiumY/AIPlugin.h>

@class AIListObject, AIChat, AIActionDetailsPane;

#define KEY_ACTION_DETAILS @"ActionDetails"
#define INTERFACE_ERROR_MESSAGE @"Interface_ErrorMessageReceived"
#define KEY_EVENT_ID @"EventID"
#define KEY_ACTION_ID @"ActionID"
#define PREF_GROUP_CONTACT_ALERTS @"Contact Alerts"
#define KEY_CONTACT_ALERTS @"Contact Alerts"
#define KEY_DEFAULT_EVENT_ID @"Default Event ID"
#define KEY_DEFAULT_ACTION_ID @"Default Action ID"
#define KEY_ONE_TIME_ALERT @"OneTime"

// Stub of the enum in Frameworks/Adium/Source/AIContactAlertsControllerProtocol.h.
// The test bundle can't import the real header (it would drag in the AdiumY.framework
// declaration chain), so this hand-copy sizes ESContactAlertsController.m's register-side
// arrays. generate-xcodeproj.py's drift check (issue #324) fails regeneration/CI if this
// count diverges from the real header — update both together.
typedef enum {
	AIContactsEventHandlerGroup = 0,
	AIMessageEventHandlerGroup,
	AIAccountsEventHandlerGroup,
	AIFileTransferEventHandlerGroup,
	AIOtherEventHandlerGroup
} AIEventHandlerGroupType;
#define EVENT_HANDLER_GROUP_COUNT 5

/*
 * The AIEventHandler/AIActionHandler protocols are required by ESContactAlertsController.m's
 * register path (compiled into this bundle for #245): its static arrays are sized with
 * EVENT_HANDLER_GROUP_COUNT and it sends the handler methods below. The full required-method sets
 * match the real header; ErrorMessageHandlerPlugin implements every one of them.
 */
@protocol AIEventHandler <NSObject>
- (NSString *)shortDescriptionForEventID:(NSString *)eventID;
- (NSString *)globalShortDescriptionForEventID:(NSString *)eventID;
- (NSString *)englishGlobalShortDescriptionForEventID:(NSString *)eventID;
- (NSString *)longDescriptionForEventID:(NSString *)eventID forListObject:(AIListObject *)listObject;
- (NSString *)naturalLanguageDescriptionForEventID:(NSString *)eventID
										listObject:(AIListObject *)listObject
										  userInfo:(id)userInfo
									includeSubject:(BOOL)includeSubject;
- (NSImage *)imageForEventID:(NSString *)eventID;
- (NSString *)descriptionForCombinedEventID:(NSString *)eventID
							  forListObject:(AIListObject *)listObject
									forChat:(AIChat *)chat
								  withCount:(NSUInteger)count;
@end

@protocol AIActionHandler <NSObject>
- (NSString *)shortDescriptionForActionID:(NSString *)actionID;
- (NSString *)longDescriptionForActionID:(NSString *)actionID withDetails:(NSDictionary *)details;
- (NSImage *)imageForActionID:(NSString *)actionID;
- (AIActionDetailsPane *)detailsPaneForActionID:(NSString *)actionID;
- (BOOL)performActionID:(NSString *)actionID
		  forListObject:(AIListObject *)listObject
			withDetails:(NSDictionary *)details
	  triggeringEventID:(NSString *)eventID
			   userInfo:(id)userInfo;
- (BOOL)allowMultipleActionsWithID:(NSString *)actionID;
@end

@protocol AIContactAlertsController <AIController>
- (BOOL)isMessageEvent:(NSString *)eventID;
- (NSString *)naturalLanguageDescriptionForEventID:(NSString *)eventID
										listObject:(AIListObject *)listObject
										  userInfo:(id)userInfo
									includeSubject:(BOOL)includeSubject;
- (void)registerActionID:(NSString *)actionID withHandler:(id<AIActionHandler>)handler;
- (void)unregisterActionID:(NSString *)actionID;
- (void)registerEventID:(NSString *)eventID
			withHandler:(id<AIEventHandler>)handler
				inGroup:(AIEventHandlerGroupType)inGroup
			 globalOnly:(BOOL)global;
- (void)unregisterEventID:(NSString *)eventID;
- (NSString *)eventIDForEnglishDisplayName:(NSString *)displayName;
- (void)addGlobalAlert:(NSDictionary *)newAlert;
- (void)setAllGlobalAlerts:(NSArray *)allGlobalAlerts;
- (void)removeAllGlobalAlertsWithActionID:(NSString *)actionID;
- (NSSet *)generateEvent:(NSString *)eventID
				   forListObject:(AIListObject *)listObject
						userInfo:(id)userInfo
	previouslyPerformedActionIDs:(NSSet *)previouslyPerformedActionIDs;
@end
