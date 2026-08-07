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

typedef enum {
	AIContactsEventHandlerGroup = 0,
	AIMessageEventHandlerGroup,
	AIAccountsEventHandlerGroup,
	AIFileTransferEventHandlerGroup,
	AIOtherEventHandlerGroup
} AIEventHandlerGroupType;

@protocol AIEventHandler <NSObject>
@end

@protocol AIActionHandler <NSObject>
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
