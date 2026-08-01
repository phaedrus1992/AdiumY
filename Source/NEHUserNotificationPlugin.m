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
#import <AIUtilities/AIStringUtilities.h>
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
 * @brief Install the plugin
 *
 * Registers our action with the contact alerts controller and waits for Adium to finish
 * launching before requesting notification authorization so all events are registered.
 */
- (void)installPlugin
{
	[adium.contactAlertsController registerActionID:USER_NOTIFICATION_ALERT_IDENTIFIER withHandler:self];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(adiumFinishedLaunching:)
												 name:AIApplicationDidFinishLoadingNotification
											   object:nil];
}

/*!
 * @brief Uninstall the plugin
 */
- (void)uninstallPlugin
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

/*!
 * @brief Adium finished launching
 *
 * Delays one more run loop so all events are registered before requesting authorization.
 */
- (void)adiumFinishedLaunching:(NSNotification *)notification
{
	[self performSelector:@selector(beginNotifications) withObject:nil afterDelay:0];

	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:AIApplicationDidFinishLoadingNotification
												  object:nil];
}

/*!
 * @brief Request notification authorization and become the notification center delegate
 */
- (void)beginNotifications
{
	if (@available(macOS 10.14, *)) {
		UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
		[center setDelegate:self];
		[center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
							  completionHandler:^(BOOL granted, NSError *error) {
								  if (error != nil) {
									  NSLog(@"User notification authorization failed: %@", error);
								  }
							  }];
	}
}

#pragma mark AIActionHandler

/*!
 * @brief Short description
 */
- (NSString *)shortDescriptionForActionID:(NSString *)actionID
{
	return AILocalizedString(@"User Notification", nil);
}

/*!
 * @brief Long description
 */
- (NSString *)longDescriptionForActionID:(NSString *)actionID withDetails:(NSDictionary *)details
{
	return AILocalizedString(@"Display a notification from the operating system", nil);
}

/*!
 * @brief Image
 */
- (NSImage *)imageForActionID:(NSString *)actionID
{
	return [NSImage imageNamed:@"events-contact" forClass:[self class]];
}

/*!
 * @brief Details pane
 */
- (AIActionDetailsPane *)detailsPaneForActionID:(NSString *)actionID
{
	return nil;
}

/*!
 * @brief Perform an action
 */
- (BOOL)performActionID:(NSString *)actionID
		  forListObject:(AIListObject *)listObject
			withDetails:(NSDictionary *)details
	  triggeringEventID:(NSString *)eventID
			   userInfo:(id)userInfo
{
	if (!@available(macOS 10.14, *)) {
		return NO;
	}

	UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
	[center setDelegate:self];

	UNMutableNotificationContent *content = [self contentForEventID:eventID
													  forListObject:listObject
														withDetails:details
														   userInfo:userInfo];
	if (content != nil) {
		UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[[NSUUID UUID] UUIDString]
																			  content:content
																			  trigger:nil];
		[center addNotificationRequest:request withCompletionHandler:nil];
	}

	return YES;
}

/*!
 * @brief Allow multiple actions?
 */
- (BOOL)allowMultipleActionsWithID:(NSString *)actionID
{
	return YES;
}

/*!
 * @brief Build the notification content for an event
 *
 * Message events pass an {AIChat, AIContentObject} dictionary; file transfer events pass the
 * ESFileTransfer itself. The click context records whatever identifiers are available so the
 * delegate can reopen the chat or reveal the file transfer.
 */
- (UNMutableNotificationContent *)contentForEventID:(NSString *)eventID
									  forListObject:(AIListObject *)listObject
										withDetails:(NSDictionary *)details
										   userInfo:(id)userInfo
{
	if (!@available(macOS 10.14, *)) {
		return nil;
	}

	UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
	NSMutableDictionary *clickContext = [NSMutableDictionary dictionary];

	AIChat *chat = nil;
	AIContentObject *contentObject = nil;
	NSString *title = nil;
	NSString *body = nil;

	if ([userInfo isKindOfClass:[NSDictionary class]]) {
		chat = [userInfo objectForKey:@"AIChat"];
		contentObject = [userInfo objectForKey:@"AIContentObject"];

		if (chat != nil) {
			NSString *uniqueChatID = [chat uniqueChatID];
			if (uniqueChatID) {
				[clickContext setObject:uniqueChatID forKey:KEY_CHAT_ID];
			}
		}

	} else if ([userInfo isKindOfClass:[ESFileTransfer class]]) {
		ESFileTransfer *fileTransfer = (ESFileTransfer *)userInfo;
		body = [fileTransfer displayFilename];

		NSString *fileTransferID = [fileTransfer uniqueID];
		if (fileTransferID) {
			[clickContext setObject:fileTransferID forKey:KEY_FILE_TRANSFER_ID];
		}
	}

	if (listObject != nil) {
		title = [listObject displayName];
	} else if (chat != nil) {
		title = [chat name];
	}

	if (contentObject != nil) {
		body = [contentObject messageString];
	}

	if ([listObject isKindOfClass:[AIListContact class]]) {
		NSString *internalObjectID = [listObject internalObjectID];
		if (internalObjectID) {
			[clickContext setObject:internalObjectID forKey:KEY_LIST_OBJECT_ID];
		}
	}

	if (title == nil) {
		title = @"Adium";
	}
	if (body == nil) {
		body = AILocalizedString(@"You have a new event", nil);
	}

	[content setTitle:title];
	[content setBody:body];
	[content setSound:[UNNotificationSound defaultSound]];
	if ([clickContext count] > 0) {
		[content setUserInfo:clickContext];
	}

	return content;
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