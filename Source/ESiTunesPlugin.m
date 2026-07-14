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
// Thanks to GrowlTunes from the Growl project for demonstrating how to receive notifications when
// the iTunes track changes.

#import "ESiTunesPlugin.h"
#import "AIStatusController.h"
#import <AIUtilities/AIApplicationAdditions.h>
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/AIToolbarUtilities.h>
#import <AIUtilities/AIWindowAdditions.h>
#import <AIUtilities/MVMenuButton.h>
#import <Adium/AIAccount.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIHTMLDecoder.h>
#import <Adium/AIMenuControllerProtocol.h>
#import <Adium/AIStatus.h>
#import <Adium/AIToolbarControllerProtocol.h>
#import <WebKit/WebKit.h>

#define STRING_TRIGGERS_MENU                                                                                           \
	AILocalizedString(@"Insert iTunes Token", "Label used for edit and contextual menus of iTunes triggers")
#define STRING_TRIGGERS_TOOLBAR AILocalizedString(@"iTunes", "Label for iTunes toolbar menu item.")
#define STRING_ALBUM AILocalizedString(@"Album", "Album of current song")
#define STRING_ARTIST AILocalizedString(@"Artist", "Artist of current song")
#define STRING_COMPOSER AILocalizedString(@"Composer", "Composer of current song")
#define STRING_GENRE AILocalizedString(@"Genre", "Genre of current song")
#define STRING_STATUS AILocalizedString(@"Player State", "Playing-status of current song (e.g. paused, playing)")
#define STRING_TRACK AILocalizedString(@"Track", "Track name of current song")
#define STRING_YEAR AILocalizedString(@"Year", "Year of current song")
#define STRING_STORE_URL AILocalizedString(@"iTunes Music Store Link", "iTUnes Music Store link for current song")
#define STRING_MUSIC AILocalizedString(@"Listening Status", "Listening status string (*is listening to XXX by YYY)")
#define STRING_CURRENT_TRACK AILocalizedString(@"iTunes Status", "Current track information (Track - Artist)")

#pragma mark -

#define ITUNES_MINIMUM_VERSION 4.6f
#define ITUNES_STATUS_ID -8000
#define ITUNES_ITMS_SEARCH_URL @"itms://itunes.com/link?"

#pragma mark -

#define KEY_ITUNES_PLAYING @"Playing"
#define KEY_ITUNES_PAUSED @"Paused"
#define KEY_ITUNES_STOPPED @"Stopped"

#pragma mark -

@interface ESiTunesPlugin ()
- (NSMenuItem *)menuItemWithTitle:(NSString *)title
						   action:(SEL)action
				representedObject:(id)representedObject
							 kind:(KGiTunesPluginMenuItemKind)itemKind;
- (void)createiTunesCurrentTrackStatusState;
- (void)updateiTunesCurrentTrackFormat;
- (void)createiTunesToolbarItemWithPath:(NSString *)path;
- (void)createiTunesToolbarItemMenuItems:(NSMenu *)iTunesMenu;
- (NSMenu *)createTriggerMenu;
- (void)insertTriggerMenu;
- (void)insertStringIntoMessageEntryView:(NSString *)inString;
- (void)insertAttributedStringIntoMessageEntryView:(NSAttributedString *)inString;
- (void)loadiTunesCurrentInfoViaApplescript;

- (void)insertFilteredString:(id)sender;
- (void)filterAndInsertString:(NSString *)inString;
- (NSAttributedString *)filterAttributedString:(NSAttributedString *)inAttributedString context:(id)context;
- (CGFloat)filterPriority;

- (void)fireUpdateiTunesInfo;
- (void)iTunesUpdate:(NSNotification *)aNotification;
- (void)currentTrackFormatDidChange:(NSNotification *)aNotification;
- (void)insertUnfilteredString:(id)sender;
- (void)insertiTMSLink;
- (void)gatherSelection;
- (void)bringiTunesToFront;
@end

/*!
 * @class ESiTunesPlugin
 * @brief Fiiltering component to provide triggers which are replaced by information from the current iTunes track
 */
@implementation ESiTunesPlugin

#pragma mark -
#pragma mark Accessor Methods

/*!
 * @brief Is iTunes stopped?
 */
- (BOOL)iTunesIsStopped
{
	// Get the info if we don't already have it
	if (!iTunesCurrentInfo)
}

@end
