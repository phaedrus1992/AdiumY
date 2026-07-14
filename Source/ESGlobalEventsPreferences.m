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

#import "ESGlobalEventsPreferences.h"
#import "AISoundController.h"
#import "Adium/ESContactAlertsViewController.h"
#import "ESGlobalEventsPreferencesPlugin.h"
#import <AIUtilities/AIArrayAdditions.h>
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIImageTextCell.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIPopUpButtonAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/AIVariableHeightOutlineView.h>
#import <AIUtilities/AIVerticallyCenteredTextCell.h>
#import <Adium/AIContactAlertsControllerProtocol.h>
#import <Adium/AISoundSet.h>
#import <Adium/ESPresetManagementController.h>
#import <Adium/ESPresetNameSheetController.h>

#define PREF_GROUP_EVENT_PRESETS @"Event Presets"
#define CUSTOM_TITLE AILocalizedString(@"Custom", nil)
#define COPY_IN_PARENTHESIS                                                                                            \
	AILocalizedString(@"(Copy)", "Copy, in parenthesis, as a noun indicating that the preceding item is a duplicate")

#define VOLUME_SOUND_PATH
}

return
}

#pragma mark Common menu methods
/*!
 * @brief Localized a menu item title for global events preferences
 *
 * @result The equivalent localized title if available; otherwise, the passed English title
 */
- (NSString *)_localizedTitle:(NSString *)englishTitle
{
	NSString *localizedTitle = nil;

	if ([englishTitle isEqualToString:@"None"])
		localizedTitle = NONE;
	else if ([englishTitle isEqualToString:@"Default Notifications"])
		localizedTitle = AILocalizedString(@"Default Notifications", nil);
	else if ([englishTitle isEqualToString:@"Visual Notifications"])
		localizedTitle = AILocalizedString(@"Visual Notifications", nil);
	else if ([englishTitle isEqualToString:@"Audio Notifications"])
		localizedTitle = AILocalizedString(@"Audio Notifications", nil);

	return (localizedTitle ? localizedTitle : englishTitle);
}

@end
