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

#import "AIAliasSupportPlugin.h"
#import "AIContactInfoWindowController.h"
#import "AIContactListEditorPlugin.h"
#import <AIUtilities/AIDictionaryAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIMutableOwnerArray.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIListContact.h>
#import <Adium/AIListObject.h>
#import <Adium/AIMenuControllerProtocol.h>

#define ALIASES_DEFAULT_PREFS @"Alias Defaults"
#define DISPLAYFORMAT_DEFAULT_PREFS @"Display Format Defaults"

#define CONTACT_NAME_MENU_TITLE AILocalizedString(@"Contact Name Format", nil)
#define ALIAS AILocalizedString(@"Alias", nil)
#define ALIAS_SCREENNAME AILocalizedString(@"Alias (User Name)", nil)
#define SCREENNAME_ALIAS AILocalizedString(@"User Name (Alias)", nil)
#define SCREENNAME AILocalizedString(@"User Name", nil)

@interface AIAliasSupportPlugin ()
- (NSSet *)_applyAlias:(NSString *)inAlias toObject:(AIListObject *)inObject notify:(BOOL)notify;
- (NSMenu *)_contactNameMenu;
- (void)applyAliasRequested:(NSNotification *)notification;
@end

/*!
 * @class AIAliasSupportPlugin
 * @brief Plugin to handle applying aliases to contacts
 *
 * This plugin applies aliases to contacts.  It also responsible for generating the "long display name"
 * used in the contact list which may include some combination of alias and screen name.
 */
@implementation AIAliasSupportPlugin

/*!
 * @brief Install plugin
 */
- (void)installPlugin
{
	// Register our default preferences

	[menuItem setTag:AINameFormat_ScreenName];
	[choicesMenu addItem:menuItem];

	return choicesMenu;
}

@end
