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

#import "CBContactLastSeenPlugin.h"
#import <AIUtilities/AIDateFormatterAdditions.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIListObject.h>
#import <Adium/AIMetaContact.h>

#define PREF_GROUP_LAST_SEEN @"Last Seen"
#define KEY_LAST_SEEN_STATUS @"Last Seen Status"
#define KEY_LAST_SEEN_DATE @"Last Seen Date"

/*!
 * @class CBContactLastSeenPlugin
 * @brief Component to track and display as a tooltip the last time contacts were seen online
 */
@implementation CBContactLastSeenPlugin

/*!
 * @brief Install
 */
- (void)installPlugin
{
	// Install our tooltip entry
}

- (BOOL)shouldDisplayInContactInspector
{
	return YES;
}

@end
