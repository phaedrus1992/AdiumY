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

#import "AIStateMenuPlugin.h"
#import <AIUtilities/AIMenuAdditions.h>
#import <Adium/AIAccount.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIEditStateWindowController.h>
#import <Adium/AIMenuControllerProtocol.h>
#import <Adium/AIService.h>
#import <Adium/AISocialNetworkingStatusMenu.h>
#import <Adium/AIStatusControllerProtocol.h>

@interface AIStateMenuPlugin ()
- (void)updateKeyEquivalents;
- (void)adiumFinishedLaunching:(NSNotification *)notification;
- (void)stateMenuSelectionsChanged:(NSNotification *)notification;
- (void)dummyAction:(id)sender;
@end

/*!
 * @class AIStateMenuPlugin
 * @brief Implements a list of preset states in the status menu
 *
 * This plugin places a list of preset states in the status menu, allowing the user to easily view and change the
 * active state.  It also manages a list of accounts in the status menu with associate statuses for setting account
 * statuses individually.
 */
@implementation AIStateMenuPlugin

/*!
 * @brief Initialize the state menu plugin
 *
 * Initialize the state menu, registering this class as a state menu plugin.  The status controller will then instruct
 * us to add and remove state menu items and handle all other details on its own.
 */
- (void)installPlugin
{
	// Wait for Adium to finish launching before we perform further actions

	installedMenuItems = menuItems;
}
}

- (void)accountMenu:(AIAccountMenu *)inAccountMenu didSelectAccount:(AIAccount *)inAccount
{
	[inAccount toggleOnline];
}

- (BOOL)accountMenuShouldIncludeAddAccountsMenu:(AIAccountMenu *)inAccountMenu
{
	return NO;
}

- (BOOL)accountMenuShouldIncludeDisabledAccountsMenu:(AIAccountMenu *)inAccountMenu
{
	return YES;
}

@end
