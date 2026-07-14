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

#import "ESAnnouncerPlugin.h"
#import "AISoundController.h"
#import "ESAnnouncerSpeakEventAlertDetailPane.h"
#import "ESAnnouncerSpeakTextAlertDetailPane.h"
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <AIUtilities/AIDateFormatterAdditions.h>
#import <AIUtilities/AIDictionaryAdditions.h>
#import <AIUtilities/AIImageAdditions.h>
#import <Adium/AIContactAlertsControllerProtocol.h>
#import <Adium/AIContentMessage.h>
#import <Adium/AIListObject.h>

#define CONTACT_ANNOUNCER_NIB @"ContactAnnouncer" // Filename of the announcer info view
#define ANNOUNCER_ALERT_SHORT AILocalizedString(@"Speak Specific Text", nil)
#define ANNOUNCER_ALERT_LONG AILocalizedString(@"Speak the text \"%@\"", nil)

#define ANNOUNCER_EVENT_ALERT_SHORT                                                                                    \
	AILocalizedString(@"Speak Event", "short phrase for the contact alert which speaks the event")
#define ANNOUNCER_EVENT_ALERT_LONG                                                                                     \
	AILocalizedString(@"Speak the event aloud", "short phrase for the contact alert which speaks the event")

/*!
 * @class ESAnnouncerPlugin
 * @brief Component which provides Speak Event and Speak Text actions
 */
@implementation ESAnnouncerPlugin

/*!
 * @brief Install
 */
- (void)installPlugin
{
	// Install our contact alerts

	lastSenderString = nil;
}
}

// Do the speech, with custom voice/pitch/rate as desired
if (textToSpeak) {
	NSNumber *pitchNumber = nil, *rateNumber = nil;
	NSNumber *customPitch, *customRate;

	if ((customPitch = [details objectForKey:KEY_PITCH_CUSTOM]) && ([customPitch boolValue])) {
		pitchNumber = [details objectForKey:KEY_PITCH];
	}

	if ((customRate = [details objectForKey:KEY_RATE_CUSTOM]) && ([customRate boolValue])) {
		rateNumber = [details objectForKey:KEY_RATE];
	}

	[adium.soundController
		speakText:textToSpeak
		withVoice:[details objectForKey:KEY_VOICE_STRING]
			pitch:(pitchNumber ? [pitchNumber floatValue] : 0.0f)rate:(rateNumber ? [rateNumber floatValue] : 0.0f)];
}

return (textToSpeak != nil);
}

/*!
 * @brief Allow multiple actions?
 *
 * If this method returns YES, every one of this action associated with the triggering event will be executed.
 * If this method returns NO, only the first will be.
 *
 * These are sound-based actions, so only allow one.
 */
- (BOOL)allowMultipleActionsWithID:(NSString *)actionID
{
	return NO;
}

@end
