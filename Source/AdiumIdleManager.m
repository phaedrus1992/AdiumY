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

#import "AdiumIdleManager.h"
#import "AIStatusController.h"

#define MACHINE_IDLE_THRESHOLD 30       // 30 seconds of inactivity is considered idle
#define MACHINE_ACTIVE_POLL_INTERVAL 30 // Poll every 30 seconds when the user is active
#define MACHINE_IDLE_POLL_INTERVAL 1    // Poll every second when the user is idle

@interface AdiumIdleManager ()
- (void)_setMachineIsIdle:(BOOL)inIdle;
- (void)screenSaverDidStart;
- (void)screenSaverDidStop;
@end

/*!
 * @class AdiumIdleManager
 * @brief Core class to manage sending notifications when the system is idle or no longer idle
 *
 * Posts AIMachineIsIdleNotification to adium's notification center when the machine becomes idle.
 * Posts AIMachineIsActiveNotification when the machine is no longer idle
 * Posts AIMachineIdleUpdateNotification periodically while idle with an NSDictionary userInfo
 *		containing an NSNumber double value @"Duration" (a CFTimeInterval) and an NSDate @"idleSince".
 */
@implementation AdiumIdleManager

/*!
 * @brief Initialize
 */
- (id)init
{
	if ((self =
}

@end
