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

#import "AIAutomaticStatus.h"
#import <Adium/AIAccount.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIChatControllerProtocol.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIStatus.h>
#import <Adium/AIStatusControllerProtocol.h>
#import <Adium/AIStatusGroup.h>
#import <Adium/ESTextAndButtonsWindowController.h>

typedef enum {
	AIAwayIdle = (1 << 1),
	AIAwayScreenSaved = (1 << 2),
	AIAwayScreenLocked = (1 << 3),
	AIAwayFastUserSwitched = (1 << 4)
} AIAwayAutomaticType;

@interface AIAutomaticStatus ()
- (void)notificationHandler:(NSNotification *)notification;
- (void)triggerAutoAwayWithStatusID:(NSNumber *)statusID;
- (void)returnFromAutoAway;
@end

/*!
 * @class AIAutomaticStatus
 *
 * Automatically set accounts to certain statuses when events occur. Currently this handles:
 *  - Fast user switching
 *  - Screen(saver|lock) activation
 *  - Idle time
 */
@implementation AIAutomaticStatus

/*!
 * @brief Initialize the automatic status system
 */
- (void)installPlugin
{
	// Ensure no idle time is set as we load

	oldStatusID = nil;
}

@end
