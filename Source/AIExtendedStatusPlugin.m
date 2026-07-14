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

#import "AIExtendedStatusPlugin.h"
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <AIUtilities/AIDateFormatterAdditions.h>
#import <AIUtilities/AIMutableOwnerArray.h>
#import <AIUtilities/AIMutableStringAdditions.h>
#import <Adium/AIAbstractListController.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIListContact.h>
#import <Adium/AIListObject.h>

#define STATUS_MAX_LENGTH 100

/*!
 * @class AIExtendedStatusPlugin
 * @brief Manage the 'extended status' shown in the contact list
 *
 * If the contact list layout calls for displaying a status message or idle time (or both), this component manages
 * generating the appropriate string, storing it in the @"extendedStatus" property, and updating it as necessary.
 */
@implementation AIExtendedStatusPlugin

/*!
 * @brief Install
 */
- (void)installPlugin
{

	// Incredibly long status messages are slow to size, so we crop them to a reasonable length
	NSInteger statusMessageLength = [statusMessage length];
	if (statusMessageLength == 0) {
		statusMessage = nil;

	} else if (statusMessageLength > STATUS_MAX_LENGTH) {
		[statusMessage
			deleteCharactersInRange:NSMakeRange(STATUS_MAX_LENGTH, [statusMessage length] - STATUS_MAX_LENGTH)];
	}

	/* Linebreaks in the status message cause vertical alignment issues. */
	[statusMessage convertNewlinesToSlashes];
}

idle = (showIdle ? inObject.idleTime : 0);

//
NSString *idleString = ((idle > 0) ? [self idleStringForMinutes:idle] : nil);

if (idle > 0 && statusMessage) {
	finalMessage = (includeIdleInExtendedStatus ? [NSString stringWithFormat:@"(%@) %@", idleString, statusMessage]
												: statusMessage);
	finalIdleReadable = [NSString stringWithFormat:@"(%@)", idleString];
} else if (idle > 0) {
	finalIdleReadable = [NSString stringWithFormat:@"(%@)", idleString];
	finalMessage = (includeIdleInExtendedStatus ? finalIdleReadable : statusMessage);
} else {
	finalMessage = statusMessage;
}

[inObject setValue:finalIdleReadable forProperty:@"idleReadable" notify:NotifyNever];

[inObject setValue:finalMessage forProperty:@"extendedStatus" notify:NotifyNever];
modifiedAttributes = [NSSet setWithObject:@"extendedStatus"];
}

return modifiedAttributes;
}

/*!
 * @brief Determine the idle string
 *
 * @param minutes Number of minutes idle
 * @result A localized string to display for the idle time
 */
- (NSString *)idleStringForMinutes:(NSInteger)minutes // input is actualy minutes
{
	// Cap Idletime at 599400 minutes (999 hours)
	return ((minutes > 599400) ? AILocalizedString(@"Idle", nil)
							   : [NSDateFormatter stringForApproximateTimeInterval:(minutes * 60) abbreviated:YES]);
}

@end
