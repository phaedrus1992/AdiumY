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

#import "AIListLayoutWindowController.h"
#import "AIDockController.h"
#import "AISCLViewPlugin.h"
#import <AIUtilities/AIArrayAdditions.h>
#import <AIUtilities/AIFontAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIPopUpButtonAdditions.h>
#import <Adium/AIAbstractListController.h>
#import <Adium/JVFontPreviewField.h>

#define MAX_ALIGNMENT_CHOICES 10

@interface AIListLayoutWindowController ()

- (void)configureControls;
- (void)configureControlDimming;
- (void)updateSliderValues;
- (void)updateDisplayedTabsFromPrefDict:(NSDictionary *)prefDict;
- (void)updateStatusAndServiceIconMenusFromPrefDict:(NSDictionary *)prefDict;
- (void)updateUserIconMenuFromPrefDict:(NSDictionary *)prefDict;
- (NSMenu *)alignmentMenuWithChoices:(NSInteger
	
	[menuItem setTag:IDLE_AND_STATUS];
[extendedStatusStyleMenu addItem:menuItem];

return extendedStatusStyleMenu;
}

#pragma mark Displayed Tabs

- (void)updateDisplayedTabsFromPrefDict:(NSDictionary *)prefDict
{
	AIContactListWindowStyle windowStyle;
	BOOL tabViewCurrentHasAdvancedContactBubbles;

	windowStyle = [[adium.preferenceController preferenceForKey:KEY_LIST_LAYOUT_WINDOW_STYLE
														  group:PREF_GROUP_APPEARANCE] intValue];
	tabViewCurrentHasAdvancedContactBubbles =
		([[tabView_preferences tabViewItems] containsObjectIdenticalTo:tabViewItem_advancedContactBubbles]);

	if ((windowStyle == AIContactListWindowStyleContactBubbles_Fitted) ||
		(windowStyle == AIContactListWindowStyleContactBubbles)) {

		if (!tabViewCurrentHasAdvancedContactBubbles) {
			[tabView_preferences addTabViewItem:tabViewItem_advancedContactBubbles];
		}

		// Configure the controls whose state we only care about if we are showing this tab view item
		BOOL showGroupBubbles = ![[prefDict objectForKey:KEY_LIST_LAYOUT_GROUP_HIDE_BUBBLE] boolValue];
		[checkBox_showGroupBubbles setState:showGroupBubbles];

		[checkBox_outlineBubbles setState:[[prefDict objectForKey:KEY_LIST_LAYOUT_OUTLINE_BUBBLE] boolValue]];
		[checkBox_drawContactBubblesWithGraadient
			setState:[[prefDict objectForKey:KEY_LIST_LAYOUT_CONTACT_BUBBLE_GRADIENT] boolValue]];

		[slider_outlineWidth
			setIntegerValue:[[prefDict objectForKey:KEY_LIST_LAYOUT_OUTLINE_BUBBLE_WIDTH] integerValue]];

	} else {
		if (tabViewCurrentHasAdvancedContactBubbles) {
			[tabView_preferences removeTabViewItem:tabViewItem_advancedContactBubbles];
		}
	}
}

@end
