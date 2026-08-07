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

// clang-format off
// Import order is load-bearing for the standalone test target (no prefix header):
// AIPlugin must precede AIAdvancedPreferencesPlugin.h, whose interface inherits from it. clang-format
// would sort the quoted own-header first.
#import <AdiumY/AIPlugin.h>
#import "AIAdvancedPreferencesPlugin.h"
// clang-format on

// clang-format off
// The standalone test target has no Adium.pch, which provides AIPreferenceControllerProtocol.h
// app-wide; import it here so adium.preferenceController's selectors resolve without the pch.
#import <AdiumY/AIPreferenceControllerProtocol.h>
// clang-format on
#import "AIAdvancedPreferences.h"
#import "AIConfirmationsAdvancedPreferences.h"
#import "AIMessageAlertsAdvancedPreferences.h"

@implementation AIAdvancedPreferencesPlugin

- (void)installPlugin
{
	advancedPreferences = (AIAdvancedPreferences *)[AIAdvancedPreferences preferencePane];

	// Generic advanced panes with no specific plugins.
	messageAlertsPreferences =
		(AIMessageAlertsAdvancedPreferences *)[AIMessageAlertsAdvancedPreferences preferencePane];
	confirmationsPreferences =
		(AIConfirmationsAdvancedPreferences *)[AIConfirmationsAdvancedPreferences preferencePane];
}

- (void)uninstallPlugin
{
	// Remove the preference panes installPlugin registered so an uninstalled plugin stops appearing
	// in the preferences window (removal is nil-safe).
	if (advancedPreferences != nil) {
		[adium.preferenceController removePreferencePane:advancedPreferences];
		advancedPreferences = nil;
	}
	if (messageAlertsPreferences != nil) {
		[adium.preferenceController removeAdvancedPreferencePane:messageAlertsPreferences];
		messageAlertsPreferences = nil;
	}
	if (confirmationsPreferences != nil) {
		[adium.preferenceController removeAdvancedPreferencePane:confirmationsPreferences];
		confirmationsPreferences = nil;
	}
}

@end
