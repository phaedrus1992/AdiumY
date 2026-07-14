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

#import "LNAboutBoxController.h"
#import "AISoundController.h"
#import <AIUtilities/AIApplicationAdditions.h>
#import <AIUtilities/AIDateFormatterAdditions.h>
#import <AIUtilities/AIEventAdditions.h>
#import <AIUtilities/AIWindowAdditions.h>

#define ABOUT_BOX_NIB @"AboutBox"
#define ADIUM_SITE_LINK                                                                                                \
	AILocalizedString(@"https://github.com/phaedrus1992/adiumy",                                                       \
					  "Adium homepage. Only localize if a translated version of the page exists.")

@interface LNAboutBoxController ()
- (id)initWithWindowNibName:(NSString *)windowNibName;

- (NSString *)AI_applicationVersion:(BOOL)withBuild;
- (NSString *)AI_applicationDate;
@end

@implementation LNAboutBoxController

// Returns the shared about box instance
LNAboutBoxController *sharedAboutBoxInstance = nil;

+ (LNAboutBoxController *)aboutBoxController
{
	if (!sharedAboutBoxInstance) {
		sharedAboutBoxInstance =
	}

#pragma mark Software License

	// Display the software license sheet
	-(IBAction)showLicense : (id)sender
	{
		NSURL *licenseURL = [NSURL fileURLWithPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"License"
																									ofType:@"txt"]];
		[textView_license setString:[NSString stringWithContentsOfURL:licenseURL
															 encoding:NSUTF8StringEncoding
																error:NULL]];

		[NSApp beginSheet:panel_licenseSheet
			modalForWindow:[self window]
			 modalDelegate:nil
			didEndSelector:nil
			   contextInfo:nil];
	}

	// Close the software license sheet
	-(IBAction)hideLicense : (id)sender
	{
		[panel_licenseSheet orderOut:nil];
		[NSApp endSheet:panel_licenseSheet returnCode:0];
	}

#pragma mark Sillyness

	// Flap the duck when clicked
	-(IBAction)adiumDuckClicked : (id)sender
	{
		numberOfDuckClicks++;

#define PATH_TO_SOUNDS                                                                                                 \
	[NSString pathWithComponents:[NSArray arrayWithObjects:[[NSBundle mainBundle] bundlePath], @"Contents",            \
														   @"Resources", @"Sounds", @"Adium.AdiumSoundset", nil]]

		if (numberOfDuckClicks == 10) {
			numberOfDuckClicks = -1;
			[adium.soundController
				playSoundAtPath:[PATH_TO_SOUNDS stringByAppendingPathComponent:@"Feather Ruffle.aif"]];
		} else {
			[adium.soundController playSoundAtPath:[PATH_TO_SOUNDS stringByAppendingPathComponent:@"Quack.aif"]];
		}
	}

	@end
