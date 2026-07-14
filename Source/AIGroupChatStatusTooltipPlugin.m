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

#import "AIGroupChatStatusTooltipPlugin.h"
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <Adium/AIChat.h>
#import <Adium/AIChatControllerProtocol.h>
#import <Adium/AIGroupChatStatusIcons.h>
#import <Adium/AIListContact.h>

/*!
 * @class AIGroupChatStatusTooltipPlugin
 * @brief Displays a tooltip with details of the contact's status in group chats
 */
@implementation AIGroupChatStatusTooltipPlugin
- (void)installPlugin
{}

return entry;
}

- (BOOL)shouldDisplayInContactInspector
{
	// This should already be displayed by the account.
	return NO;
}

@end
