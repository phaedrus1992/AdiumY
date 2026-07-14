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

#import "AIContactIdlePlugin.h"
#import <AIUtilities/AIArrayAdditions.h>
#import <AIUtilities/AIDateFormatterAdditions.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIListObject.h>
#import <Adium/AIMetaContact.h>

#define IDLE_UPDATE_INTERVAL 60.0

@interface AIContactIdlePlugin ()
- (void)setIdleForObject:(AIListObject *)inObject silent:(BOOL)silent;
- (void)updateIdleObjectsTimer:(NSTimer *)inTimer;
@end

/*!
 * @class AIContactIdlePlugin
 * @brief Contact idle time updating, and idle time tooltip component
 */
@implementation AIContactIdlePlugin

/*!
 * @brief Install
 */
- (void)installPlugin
{
	idleObjectArray = nil;

	// Install our tooltip entry

	idleObjectArray = nil;
}

// Set the correct idle value
}

- (BOOL)shouldDisplayInContactInspector
{
	/* Accounts should be including this information in the profile already */
	return NO;
}

@end
