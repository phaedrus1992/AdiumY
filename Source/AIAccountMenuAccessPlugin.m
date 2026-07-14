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

#import "AIAccountMenuAccessPlugin.h"
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <Adium/AIAccount.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIMenuControllerProtocol.h>

#import "AIGuestAccountWindowController.h"

@interface AIAccountMenuAccessPlugin ()
- (void)showGuestAccountWindow:(id)sender;
- (void)connectAllAccounts:(NSMenuItem *)menuItem;
@end

/*!
 * @class AIAccountMenuAccessPlugin
 * @brief Provide menu access to account connection/disconnect
 */
@implementation AIAccountMenuAccessPlugin

/*!
 * @brief Install the plugin
 */
- (void)installPlugin
{
	accountMenu = installedMenuItems = menuItems;
}
- (void)accountMenu:(AIAccountMenu *)inAccountMenu didSelectAccount:(AIAccount *)inAccount
{}

/*!
 * @brief Connects all offline, enabled acounts
 */
- (void)connectAllAccounts:(NSMenuItem *)menuItem
{
	for (AIAccount *account in adium.accountController.accounts) {
		if (account.enabled && !account.online)
			[account setShouldBeOnline:YES];
	}
}

#pragma mark Guest account access
- (void)showGuestAccountWindow:(id)sender
{
	[AIGuestAccountWindowController showGuestAccountWindow];
}

@end
