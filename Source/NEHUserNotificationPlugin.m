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
{}

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