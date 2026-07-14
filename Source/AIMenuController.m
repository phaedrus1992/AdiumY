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

#import "AIMenuController.h"
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <Adium/AIAccount.h>
#import <Adium/AIChat.h>
#import <Adium/AIListBookmark.h>
#import <Adium/AIListContact.h>
#import <Adium/AIListObject.h>
#import <Adium/AIMetaContact.h>

@interface AIMenuController ()
- (void)localizeMenuTitles;
- (void)updateAccountSpecificMenu:(NSMenu *)menu;
- (NSMenu *)contextualMenuWithLocations:(NSArray *)inLocationArray usingMenu:(NSMenu *)inMenu;
- (void)addMenuItemsForContact:(AIListContact *)inContact
						toMenu:(NSMenu *)workingMenu
				 separatorItem:(BOOL *)separatorItem;
- (void)addMenuItemsForChat:(AIChat *)inContact toMenu:(NSMenu *)workingMenu separatorItem:(BOOL *)separatorItem;
@end

@implementation AIMenuController

- (id)init
{
	if ((self = 
	currentContextMenuChat = inChat;

	return 
	NSMenuItem *menuItem;
	for (menuItem in menuItems) {
		id target = [menuItem target];
		if ([target respondsToSelector:@selector(menu:needsUpdateForMenuItem:)])
			[target menu:menu needsUpdateForMenuItem:menuItem];
	}

	if (menu == menu_Contact_Manage) {
		[self updateAccountSpecificMenu:menu];
	}
}

/*!
 * @brief Add account-specific menu items to the main Contact menu.
 *
 * These begin at the menu item by the id menu_Contact_AccountSpecific.
 */
- (void)updateAccountSpecificMenu:(NSMenu *)menu
{
	NSInteger separatorIndex = [menu indexOfItem:menu_Contact_AccountSpecific];
	[menu removeAllItemsAfterIndex:separatorIndex];

	BOOL separatorItem = NO;
	// Add all items for this contact, if one exists.
	AIListObject *inObject = adium.interfaceController.selectedListObject;
	if ([inObject isKindOfClass:[AIMetaContact class]]) {
		for (AIListContact *aListContact in ((AIMetaContact *)inObject).uniqueContainedObjects) {
			[self addMenuItemsForContact:aListContact toMenu:menu separatorItem:&separatorItem];
		}

	} else if ([inObject isKindOfClass:[AIListContact class]] && ![inObject isKindOfClass:[AIListBookmark class]]) {
		[self addMenuItemsForContact:(AIListContact *)inObject toMenu:menu separatorItem:&separatorItem];
	} else if (adium.interfaceController.activeChat.isGroupChat) {
		[self addMenuItemsForChat:adium.interfaceController.activeChat toMenu:menu separatorItem:&separatorItem];
	}

	// If no account specific items, hide the separator item.
	[menu_Contact_AccountSpecific setHidden:(menu.numberOfItems == separatorIndex + 1)];
}

@end
