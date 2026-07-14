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
#import "AISCLViewPlugin.h"
#import "AIBorderlessListWindowController.h"
#import "AIListOutlineView.h"
#import "AIStandardListWindowController.h"
#import "ESContactListAdvancedPreferences.h"
#import <AIUtilities/AIDictionaryAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <Adium/AIContactList.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIListContact.h>
#import <Adium/AIListGroup.h>
#import <Adium/AIMenuControllerProtocol.h>

#define PREF_GROUP_APPEARANCE @"Appearance"

#define DETACHED_DEFAULT_WINDOW @"Default Window"
#define DETACHED_WINDOWS @"Windows"
#define DETACHED_WINDOW_GROUPS @"Groups"
#define DETACHED_WINDOW_LOCATION @"Location"

@interface AISCLViewPlugin ()
- (NSString *)humanReadableNameForGroup:(AIListGroup *)listGroup;
- (void)moveListGroup:(AIListGroup *)listGroup toContactList:(AIContactList *)destinationGroup;

- (void)loadDetachedGroups;
- (void)loadWindowPreferences:(NSDictionary *)windowPreferences;
- (void)saveAndCloseDetachedGroups;

- (void)detachFromWindow:(id)sender;
- (void)contactListIsEmpty:(NSNotification *)notification;
- (void)attachToWindow:(id)sender;
- (void)closeAndReopencontactList;
- (void)dummyAction:(id)sender;
@end

/*!
 * @class AISCLViewPlugin
 * @brief This component plugin is responsible for controlling the main contact list and detached contact lists window
 * and view.
 *
 * Either an AIStandardListWindowController or AIBorderlessListWindowController, each of which is a subclass of
 * AIListWindowController, is instantiated. This window controller, with the help of the plugin, will be responsible for
 * display of an AIListOutlineView. The borderless window controller uses an AIBorderlessListOutlineView.
 *
 * In either case, the outline view itself is controlled by an instance of AIListController.
 *
 * AISCLViewPlugin's class methods also manage ListLayout and ListTheme preference sets. ListLayout sets determine the
 * contents and layout of the contact list; ListTheme sets control the colors used in the contact list.
 */
@implementation AISCLViewPlugin

- (void)installPlugin
{
	// List of windows
	contactLists =
}

/*!
 * @brief Loads main contact list window if not already loaded and if this
 * is the first time that that we are loading the contact list we detached
 * groups and place them in the correct location
 */
- (void)loadDetachedGroups
{
	if (!defaultController && windowStyle == AIContactListWindowStyleStandard) {
		defaultController =
			[AIStandardListWindowController listWindowControllerForContactList:adium.contactController.contactList];
	} else if (!defaultController) {
		defaultController =
			[AIBorderlessListWindowController listWindowControllerForContactList:adium.contactController.contactList];
	}

	if (!hasLoaded) {
		NSArray *detachedWindowsDict = [adium.preferenceController preferenceForKey:DETACHED_WINDOWS
																			  group:PREF_DETACHED_GROUPS];
		NSDictionary *windowPreferenceDict;

		for (windowPreferenceDict in detachedWindowsDict) {
			[self loadWindowPreferences:windowPreferenceDict];
		}

		hasLoaded = YES;
	}
}

/*!
 * @brief Loads detached window based on saved preferences
 */
- (void)loadWindowPreferences:(NSDictionary *)windowPreferences
{
	NSArray *groups = [windowPreferences objectForKey:DETACHED_WINDOW_GROUPS];

	if ([groups count] == 0)
		return;

	AIContactList *contactList = [adium.contactController createDetachedContactList];

	for (NSString *groupUID in groups) {
		AIListGroup *group = [adium.contactController groupWithUID:groupUID];

		[adium.contactController moveGroup:group fromContactList:group.contactList toContactList:contactList];
	}

	[self detachContactList:contactList];
}

@end
