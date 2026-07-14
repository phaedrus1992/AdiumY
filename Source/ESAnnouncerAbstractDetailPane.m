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

#import "ESAnnouncerAbstractDetailPane.h"
#import "AISoundController.h"
#import "ESAnnouncerPlugin.h"
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIPopUpButtonAdditions.h>
#import <Adium/AIContactAlertsControllerProtocol.h>
#import <Adium/AILocalizationButton.h>

@interface ESAnnouncerAbstractDetailPane ()
- (NSMenu *)voicesMenu;
@end

/*!
 * @class ESAnnouncerAbstractDetailPane
 * @brief Abstract superclass for Announcer action (Speak Event and Speak Text) detail panes
 */
@implementation ESAnnouncerAbstractDetailPane

/*!
 * @brief View did load
 */
- (void)viewDidLoad
{}

/*!
 * @brief Preference changed
 */
- (IBAction)changePreference:(id)sender
{
	NSString *voice = [[popUp_voices selectedItem] representedObject];
	// If the Default voice is selected, also set the pitch and rate to defaults
	if (sender == popUp_voices) {
		if (!voice) {
			[slider_pitch setFloatValue:[adium.soundController defaultPitch]];
			[slider_rate setFloatValue:[adium.soundController defaultRate]];
			voice = [NSSpeechSynthesizer defaultVoice];
		}
	}

	if (sender == popUp_voices || (sender == slider_pitch || sender == checkBox_customPitch) ||
		(sender == slider_rate || sender == checkBox_customRate)) {
		[adium.soundController
			speakDemoTextForVoice:voice
						withPitch:([checkBox_customPitch state] ? [slider_pitch floatValue] : 0.0f)andRate
								 :([checkBox_customRate state] ? [slider_rate floatValue] : 0.0f)];
	}

	[super changePreference:sender];
}

@end
