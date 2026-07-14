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

#import "BGEmoticonMenuPlugin.h"
#import "AIEmoticonController.h"
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIImageDrawingAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIToolbarUtilities.h>
#import <AIUtilities/MVMenuButton.h>
#import <Adium/AIEmoticon.h>
#import <Adium/AIMenuControllerProtocol.h>
#import <Adium/AIToolbarControllerProtocol.h>

@interface BGEmoticonMenuPlugin ()
- (void)registerToolbarItem;
- (IBAction)dummyTarget:(id)sender;
- (void)insertEmoticon:(id)sender;
@end

/*!
 * @class BGEmoticonMenuPlugin
 * @brief Component to manage the Emoticons menu in its various forms
 */
@implementation BGEmoticonMenuPlugin

#define PREF_GROUP_EMOTICONS @"Emoticons"

#define TITLE_INSERT_EMOTICON AILocalizedString(@"Insert Emoticon", nil)
#define TOOLTIP_INSERT_EMOTICON AILocalizedString(@"Insert an emoticon into the text", nil)
#define TITLE_EMOTICON AILocalizedString(@"Emoticon", nil)

#define TOOLBAR_EMOTICON_IDENTIFIER @"InsertEmoticon"

/*!
 * @brief Install
 */
- (void)installPlugin
{
	// init the menus and menuItems
	quickMenuItem =
}
}
}

// Menu Control
// ---------------------------------------------------------------------------------------------------------
#pragma mark Menu Control
/*!
 * @brief Insert an emoticon into the first responder if possible
 *
 * First responder must be an editable NSTextView.
 *
 * @param sender An NSMenuItem whose representedObject is an AIEmoticon
 */
- (void)insertEmoticon:(id)sender
{
	if ([sender isKindOfClass:[NSMenuItem class]]) {
		NSString *emoString = [[[sender representedObject] textEquivalents] objectAtIndex:0];

		NSResponder *responder = [[[NSApplication sharedApplication] keyWindow] firstResponder];
		if (emoString && [responder isKindOfClass:[NSTextView class]] && [(NSTextView *)responder isEditable]) {
			NSRange tmpRange = [(NSTextView *)responder selectedRange];
			if (0 != tmpRange.length) {
				[(NSTextView *)responder setSelectedRange:NSMakeRange((tmpRange.location + tmpRange.length), 0)];
			}
			[responder insertText:emoString];
		}
	}
}

/*!
 * @brief Just a target so we get the validateMenuItem: call for the emoticon menu
 */
- (IBAction)dummyTarget:(id)sender
{
	// Empty
}

/*!
 * @brief Validate menu item
 *
 * Disable the emoticon menu if a text field is not active
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem == quickMenuItem || menuItem == quickContextualMenuItem) {
		BOOL haveEmoticons = ([[adium.emoticonController activeEmoticonPacks] count] != 0);

		// Disable the main emoticon menu items if no emoticons are available
		return haveEmoticons;

	} else {
		// Disable the emoticon menu items if we're not in a text field
		NSResponder *responder = [[[NSApplication sharedApplication] keyWindow] firstResponder];
		if (responder && [responder isKindOfClass:[NSText class]]) {
			return [(NSText *)responder isEditable];
		} else {
			return NO;
		}
	}
}

/*!
 * @brief We don't want to get -menuNeedsUpdate: called on every keystroke. This method suppresses that.
 */
- (BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent *)event target:(id *)target action:(SEL *)action
{
	*target = nil;  // use menu's target
	*action = NULL; // use menu's action
	return NO;
}

/*!
 * @brief Update our menus if necessary
 *
 * Called each time before any of our menus are displayed.
 * This rebuilds menus incrementally, in place, and only updating items that need it.
 *
 */
- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(NSInteger)idx shouldCancel:(BOOL)shouldCancel
{
	NSArray *activePacks = [adium.emoticonController activeEmoticonPacks];
	AIEmoticonPack *pack;

	/* We need special voodoo here to identify if the menu belongs to a toolbar,
	 * add the necessary pad item, and then adjust the index accordingly.
	 * this shouldn't be necessary, but NSToolbar is evil.
	 */
	if ([[[menu itemAtIndex:0] title] isEqualToString:TITLE_EMOTICON]) {
		if (idx == 0) {
			return YES;
		} else {
			--idx;
		}
	}

	// Add in flat emoticon menu
	if ([activePacks count] == 1) {
		pack = [activePacks objectAtIndex:0];
		AIEmoticon *emoticon = [[pack enabledEmoticons] objectAtIndex:idx];
		if ([emoticon isEnabled] && ![[item representedObject] isEqualTo:emoticon]) {
			[item setTitle:[emoticon name]];
			[item setTarget:self];
			[item setAction:@selector(insertEmoticon:)];
			[item setKeyEquivalent:@""];
			[item setImage:[[emoticon image] imageByScalingForMenuItem]];
			[item setRepresentedObject:emoticon];
			[item setSubmenu:nil];
		}
		// Add in multi-pack menu
	} else if ([activePacks count] > 1) {
		pack = [activePacks objectAtIndex:idx];
		if (![[item title] isEqualToString:[pack name]]) {
			[item setTitle:[pack name]];
			[item setTarget:nil];
			[item setAction:nil];
			[item setKeyEquivalent:@""];
			[item setImage:[[pack menuPreviewImage] imageByScalingForMenuItem]];
			[item setRepresentedObject:nil];
			[item setSubmenu:[self flatEmoticonMenuForPack:pack]];
		}
	}

	return YES;
}

/*!
 * @brief Set the number of items that should be in the menu.
 *
 * Toolbars need one empty item to display properly.  We increase the number by 1, if the menu
 * is in a toolbar
 *
 */
- (NSInteger)numberOfItemsInMenu:(NSMenu *)menu
{
	NSArray *activePacks = [adium.emoticonController activeEmoticonPacks];
	NSInteger itemCounts = -1;

	itemCounts = [activePacks count];

	if (itemCounts == 1)
		itemCounts = [[[activePacks objectAtIndex:0] enabledEmoticons] count];

	if ([menu numberOfItems] > 0) {
		if ([[[menu itemAtIndex:0] title] isEqualToString:TITLE_EMOTICON]) {
			++itemCounts;
		}
	}

	return itemCounts;
}

@end
