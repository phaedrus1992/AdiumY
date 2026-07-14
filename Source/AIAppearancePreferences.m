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

#import "AIAppearancePreferences.h"
#import "AIAppearancePreferencesPlugin.h"
#import "AIDockIconSelectionSheet.h"
#import "AIEmoticonPack.h"
#import "AIEmoticonPreferences.h"
#import "AIListLayoutWindowController.h"
#import "AIListThemeWindowController.h"
#import "AIMenuBarIcons.h"
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIImageDrawingAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIPopUpButtonAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <Adium/AIAbstractListController.h>
#import <Adium/AIDockControllerProtocol.h>
#import <Adium/AIEmoticonControllerProtocol.h>
#import <Adium/AIIconState.h>
#import <Adium/AIServiceIcons.h>
#import <Adium/AIStatusIcons.h>
#import <Adium/ESPresetManagementController.h>
#import <Adium/ESPresetNameSheetController.h>

typedef enum { AIEmoticonMenuNone = 1, AIEmoticonMenuMultiple } AIEmoticonMenuTag;

@interface AIAppearancePreferences ()
- (NSMenu *)_windowStyleMenu;
- (NSMenu *)_emoticonPackMenu;
- (NSMenu *)_listLayoutMenu;
- (NSMenu *)_colorThemeMenu;
- (void)_rebuildEmoticonMenuAndSelectActivePack;
- (void)_addWindowStyleOption:(NSString *)option withTag:(NSInteger)tag toMenu:(NSMenu *)menu;
- (void)_updateSliderValues;
- (void)_editListThemeWithName:(NSString *)name;
- (void)_editListLayoutWithName:(NSString *)name;
- (void)xtrasChanged:(NSNotification *)notification;

- (void)configureDockIconMenu;
- (void)configureStatusIconsMenu;
- (void)configureServiceIconsMenu;
- (void)configureMenuBarIconsMenu;
@end

@implementation AIAppearancePreferences

/*!
 * @brief Preference pane properties
 */
- (NSString *)paneIdentifier
{
	return @"Appearance";
}
- (NSString *)paneName
{
	return AILocalizedString(@"Appearance", "Appearance preferences label");
}
- (NSString *)nibName
{
	return @"AppearancePrefs";
}
- (NSImage *)paneIcon
{
	return NSString * iconPath;
	NSString *activePackName = [adium.preferenceController preferenceForKey:KEY_MENU_BAR_ICONS
																	  group:PREF_GROUP_APPEARANCE];
	iconPath = [adium pathOfPackWithName:activePackName
							   extension:@"AdiumMenuBarIcons"
					  resourceFolderName:@"Menu Bar Icons"];

	if (!iconPath) {
		activePackName = [adium.preferenceController defaultPreferenceForKey:KEY_MENU_BAR_ICONS
																	   group:PREF_GROUP_APPEARANCE
																	  object:nil];

		iconPath = [adium pathOfPackWithName:activePackName
								   extension:@"AdiumMenuBarIcons"
						  resourceFolderName:@"Menu Bar Icons"];
	}
	[tempMenu addItem:[self menuItemForIconPackAtPath:iconPath class:[AIMenuBarIcons class]]];
	[tempMenu setDelegate:self];
	[tempMenu setTitle:@"Temporary Menu Bar Icons Menu"];

	[popUp_menuBarIcons setMenu:tempMenu];
	[popUp_menuBarIcons selectItemWithRepresentedObject:activePackName];
}

#pragma mark Menu delegate
- (void)menuNeedsUpdate:(NSMenu *)menu
{
	NSString *title = [menu title];
	NSString *repObject = nil;
	NSArray *menuItemArray = nil;
	NSPopUpButton *popUpButton;

	if ([title isEqualToString:@"Temporary Dock Icon Menu"]) {
		// If the menu has @"Temporary Dock Icon Menu" as its title, we should update it to have all dock icons, not
		// just our selected one
		menuItemArray = [self _dockIconMenuArray];
		repObject = [adium.preferenceController preferenceForKey:KEY_ACTIVE_DOCK_ICON group:PREF_GROUP_APPEARANCE];
		popUpButton = popUp_dockIcon;

	} else if ([title isEqualToString:@"Temporary Status Icons Menu"]) {
		menuItemArray = [self _iconPackMenuArrayForPacks:[adium allResourcesForName:@"Status Icons"
																	 withExtensions:@"AdiumStatusIcons"]
												   class:[AIStatusIcons class]];
		repObject = [adium.preferenceController preferenceForKey:KEY_STATUS_ICON_PACK group:PREF_GROUP_APPEARANCE];
		popUpButton = popUp_statusIcons;

	} else if ([title isEqualToString:@"Temporary Service Icons Menu"]) {
		menuItemArray = [self _iconPackMenuArrayForPacks:[adium allResourcesForName:@"Service Icons"
																	 withExtensions:@"AdiumServiceIcons"]
												   class:[AIServiceIcons class]];
		repObject = [adium.preferenceController preferenceForKey:KEY_SERVICE_ICON_PACK group:PREF_GROUP_APPEARANCE];
		popUpButton = popUp_serviceIcons;

	} else if ([title isEqualToString:@"Temporary Menu Bar Icons Menu"]) {
		menuItemArray = [self _iconPackMenuArrayForPacks:[adium allResourcesForName:@"Menu Bar Icons"
																	 withExtensions:@"AdiumMenuBarIcons"]
												   class:[AIMenuBarIcons class]];
		repObject = [adium.preferenceController preferenceForKey:KEY_MENU_BAR_ICONS group:PREF_GROUP_APPEARANCE];
		popUpButton = popUp_menuBarIcons;
	}

	if (menuItemArray) {
		NSMenuItem *menuItem;

		// Remove existing items
		[menu removeAllItems];

		// Clear the title so we know we don't need to do this again
		[menu setTitle:@""];

		// Add the items
		for (menuItem in menuItemArray) {
			[menu addItem:menuItem];
		}

		// Clear the title so we know we don't need to do this again
		[menu setTitle:@""];

		// Put a checkmark by the appropriate menu item
		[popUpButton selectItemWithRepresentedObject:repObject];
	}
}

@end
