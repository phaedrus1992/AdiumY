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

#import <Foundation/Foundation.h>

@class ESPurpleJabberAccount, AIChat;

NS_ASSUME_NONNULL_BEGIN

/// XEP-0308 Message Correction stanza handler
///
/// Intercepts incoming message stanzas via the \c jabber-receiving-xmlnode signal,
/// tracks the last stanza ID per chat+sender, and posts a notification when a
/// correction (a message containing a \c <replace> element) is detected.
@interface AMPurpleJabberCorrection : NSObject {
	ESPurpleJabberAccount *_account;
	NSMutableDictionary *_trackedStanzaIDs;
}

/// Initialize with the owning Jabber account.
///
/// @param account The ESPurpleJabberAccount that owns this controller
/// @return An initialized instance
- (id)initWithAccount:(ESPurpleJabberAccount *)account;

@end

/// Posted when a message correction is detected.
///
/// userInfo keys:
///   AICorrectionChatKey  — the AIChat in which the correction occurred
///   AICorrectionSenderKey — the bare JID of the sender (NSString)
///   AICorrectionDOMIdKey  — the DOM id of the message element to correct (NSString)
///   AICorrectionHTMLKey   — the corrected message HTML (NSString)
extern NSString *const AICorrectionNotificationName;
extern NSString *const AICorrectionChatKey;
extern NSString *const AICorrectionSenderKey;
extern NSString *const AICorrectionDOMIdKey;
extern NSString *const AICorrectionHTMLKey;

/// Posted when a normal message stanza ID is tracked.
///
/// userInfo keys:
///   AICorrectionSenderKey — the bare JID of the sender (NSString)
///   AICorrectionStanzaIDKey — the tracked stanza ID (NSString)
extern NSString *const AICorrectionStanzaTrackedNotification;
extern NSString *const AICorrectionStanzaIDKey;

NS_ASSUME_NONNULL_END
