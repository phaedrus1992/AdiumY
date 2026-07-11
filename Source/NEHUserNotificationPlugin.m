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

#import "NEHUserNotificationPlugin.h"
#import <AIUtilities/AIImageAdditions.h>
#import <Adium/AIChat.h>
#import <Adium/AIChatControllerProtocol.h>
#import <Adium/AIContactAlertsControllerProtocol.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIContentObject.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIListContact.h>
#import <Adium/AIListObject.h>
#import <Adium/AIStatus.h>
#import <Adium/AIStatusControllerProtocol.h>
#import <Adium/ESFileTransfer.h>

// UserNotifications requires macOS 10.14+. Runtime guards are in place below.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"

#define KEY_FILE_TRANSFER_ID @"fileTransferUniqueID"
#define KEY_CHAT_ID @"uniqueChatID"
#define KEY_LIST_OBJECT_ID @"internalObjectID"

@interface NEHUserNotificationPlugin ()
- (void)adiumFinishedLaunching:(NSNotification *)notification;
- (void)beginNotifications;
- (UNMutableNotificationContent *)contentForEventID:(NSString *)eventID
									  forListObject:(AIListObject *)listObject
										withDetails:(NSDictionary *)details
										   userInfo:(id)userInfo;
@end

@implementation NEHUserNotificationPlugin

/*!
 * @brief Initialize the plugin
 *
 * Waits for Adium to finish launching before requesting notification authorization
 * so all events are registered.
 */
- (void)installPlugin
{
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(adiumFinishedLaunching:)
												 name:AIApplicationDidFinishLoadingNotification
											   object:nil];
}

- (void)uninstallPlugin
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

/*!
 * @brief Adium finished launching
 *
 * Delays one more run loop to ensure all events are registered before requesting authorization.
 */
- (void)adiumFinishedLaunching:(NSNotification *)notification
{
	[self performSelector:@selector(beginNotifications) withObject:nil afterDelay:0];

	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:AIApplicationDidFinishLoadingNotification
												  object:nil];
}

/*!
 * @brief Begin accepting notifications
 */
- (void)beginNotifications
{
	if (![UNUserNotificationCenter class]) {
		AILog(@"UserNotifications framework not available (macOS < 10.14)");
		return;
	}

	UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
	center.delegate = self;

	// Request authorization. We need alert and sound for notification display.
	[center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound |
											 UNAuthorizationOptionBadge)
						  completionHandler:^(BOOL granted, NSError *error) {
							  if (error) {
								  AILog(@"UserNotification authorization error: %@", error);
							  }
						  }];

	// Register the action handler
	[adium.contactAlertsController registerActionID:USER_NOTIFICATION_ALERT_IDENTIFIER withHandler:self];
}

#pragma mark AIActionHandler

/*!
 * @brief Returns a short description of the notification action
 */
- (NSString *)shortDescriptionForActionID:(NSString *)actionID
{
	return AILocalizedString(@"Display a notification", nil);
}

/*!
 * @brief Returns a long description
 */
- (NSString *)longDescriptionForActionID:(NSString *)actionID withDetails:(NSDictionary *)details
{
	return AILocalizedString(@"Display a notification", nil);
}

/*!
 * @brief Returns the image associated with the notification action
 */
- (NSImage *)imageForActionID:(NSString *)actionID
{
	return [NSImage imageNamed:@"events-notification" forClass:[self class]];
}

/*!
 * @brief Post a notification for display
 */
- (BOOL)performActionID:(NSString *)actionID
		  forListObject:(AIListObject *)listObject
			withDetails:(NSDictionary *)details
	  triggeringEventID:(NSString *)eventID
			   userInfo:(id)userInfo
{
	// Don't show notifications if we're silencing notifications
	if ([adium.statusController.activeStatusState silencesGrowl]) {
		return NO;
	}

	if (![UNUserNotificationCenter class]) {
		return NO;
	}

	UNMutableNotificationContent *content = [self contentForEventID:eventID
													  forListObject:listObject
														withDetails:details
														   userInfo:userInfo];
	if (!content) {
		return NO;
	}

	// Use a unique identifier per notification
	NSString *identifier = [NSString stringWithFormat:@"%@-%@", eventID, [[NSUUID UUID] UUIDString]];
	UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier
																		  content:content
																		  trigger:nil];

	UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
	[center addNotificationRequest:request
			 withCompletionHandler:^(NSError *error) {
				 if (error) {
					 AILog(@"Notification request error: %@", error);
				 }
			 }];

	return YES;
}

/*!
 * @brief No detail pane — display-style preferences are not needed
 */
- (AIActionDetailsPane *)detailsPaneForActionID:(NSString *)actionID
{
	return nil;
}

/*!
 * @brief Allow multiple actions?
 */
- (BOOL)allowMultipleActionsWithID:(NSString *)actionID
{
	return NO;
}

#pragma mark Notification Content

/*!
 * @brief Build the notification content for an event
 */
- (UNMutableNotificationContent *)contentForEventID:(NSString *)eventID
									  forListObject:(AIListObject *)listObject
										withDetails:(NSDictionary *)details
										   userInfo:(id)userInfo
{
	NSString *title = nil;
	NSString *body = nil;
	NSMutableDictionary *clickContext = [NSMutableDictionary dictionary];
	AIChat *chat = nil;
	AIContentObject *contentObject = nil;

	// For message events, extract the source and chat
	if ([userInfo respondsToSelector:@selector(objectForKey:)]) {
		chat = [userInfo objectForKey:@"AIChat"];
		contentObject = [userInfo objectForKey:@"AIContentObject"];
		if (contentObject.source) {
			listObject = contentObject.source;
		}
	}

	[clickContext setObject:eventID forKey:@"eventID"];

	if (listObject) {
		if ([listObject isKindOfClass:[AIListContact class]]) {
			listObject = [(AIListContact *)listObject parentContact];
			title = [listObject longDisplayName];
		} else {
			title = listObject.displayName;
		}

		if (chat) {
			[clickContext setObject:chat.uniqueChatID forKey:KEY_CHAT_ID];

			if (chat.isGroupChat) {
				title = [NSString stringWithFormat:@"%@ (%@)", title, chat.displayName];
			}
		} else {
			if ([userInfo isKindOfClass:[ESFileTransfer class]] && [eventID isEqualToString:FILE_TRANSFER_COMPLETE]) {
				[clickContext setObject:[(ESFileTransfer *)userInfo uniqueID] forKey:KEY_FILE_TRANSFER_ID];
			} else {
				[clickContext setObject:listObject.internalObjectID forKey:KEY_LIST_OBJECT_ID];
			}
		}

	} else {
		if (chat) {
			title = chat.displayName;
			[clickContext setObject:chat.uniqueChatID forKey:KEY_CHAT_ID];
		} else {
			title = @"Adium";
		}
	}

	body = [[adium contactAlertsController] naturalLanguageDescriptionForEventID:eventID
																	  listObject:listObject
																		userInfo:userInfo
																  includeSubject:NO];

	if (!title && !body) {
		return nil;
	}

	UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
	content.title = title ?: @"";
	content.body = body ?: @"";
	content.userInfo = clickContext;
	content.sound = [UNNotificationSound defaultSound];

	return [content autorelease];
}

#pragma mark UNUserNotificationCenterDelegate

/*!
 * @brief Show notifications even when the app is in the foreground
 */
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
	   willPresentNotification:(UNNotification *)notification
		 withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler
{
	if (@available(macOS 10.14, *)) {
		completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound);
	} else {
		completionHandler(0);
	}
}

/*!
 * @brief Handle notification click
 */
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
	didReceiveNotificationResponse:(UNNotificationResponse *)response
			 withCompletionHandler:(void (^)(void))completionHandler
{
	if (!@available(macOS 10.14, *)) {
		completionHandler();
		return;
	}

	NSDictionary *clickContext = response.notification.request.content.userInfo;
	NSString *internalObjectID = [clickContext objectForKey:KEY_LIST_OBJECT_ID];
	NSString *uniqueChatID = [clickContext objectForKey:KEY_CHAT_ID];
	AIListObject *listObject = nil;
	AIChat *chat = nil;

	if (internalObjectID) {
		listObject = [adium.contactController existingListObjectWithUniqueID:internalObjectID];
		if ([listObject isKindOfClass:[AIListContact class]]) {
			chat = [adium.chatController existingChatWithContact:(AIListContact *)listObject];
			if (!chat) {
				chat = [adium.chatController openChatWithContact:(AIListContact *)listObject onPreferredAccount:YES];
			}
		}

	} else if (uniqueChatID) {
		chat = [adium.chatController existingChatWithUniqueChatID:uniqueChatID];
		if (!chat) {
			listObject = [adium.contactController existingListObjectWithUniqueID:uniqueChatID];
			if ([listObject isKindOfClass:[AIListContact class]]) {
				chat = [adium.chatController openChatWithContact:(AIListContact *)listObject onPreferredAccount:YES];
			}
		}
	}

	NSString *fileTransferID = [clickContext objectForKey:KEY_FILE_TRANSFER_ID];
	if (fileTransferID) {
		[[ESFileTransfer existingFileTransferWithID:fileTransferID] reveal];
	}

	if (chat) {
		[adium.interfaceController setActiveChat:chat];
	}

	[NSApp activateIgnoringOtherApps:YES];

	completionHandler();
}

#pragma clang diagnostic pop

@end