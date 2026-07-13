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

@class ESPurpleJabberAccount;

NS_ASSUME_NONNULL_BEGIN

/// XEP-0393 Message Styling controller
///
/// Handles the protocol-level aspects of XEP-0393: advertising the feature in
/// service discovery and detecting the <unstyled/> element in incoming messages.
///
/// The companion class AMPurpleJabberMessageStylingParser provides the parsing
/// logic that converts message body text with styling markers into NSAttributedString.
@interface AMPurpleJabberMessageStyling : NSObject {
    ESPurpleJabberAccount *_account;
    BOOL _lastMessageHadUnstyled;
}

/// Initialize with the owning Jabber account.
///
/// @param account The ESPurpleJabberAccount that owns this controller
/// @return An initialized instance
- (id)initWithAccount:(ESPurpleJabberAccount *)account;

/// Check whether the last incoming message had an <unstyled/> element.
///
/// This check is one-shot: the flag is cleared after reading.
/// Call this right before processing the body text for a received message.
///
/// @return YES if the last message contained <unstyled/>, NO otherwise
- (BOOL)lastMessageHadUnstyled;

@end

NS_ASSUME_NONNULL_END
