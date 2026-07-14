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

#import "AIInfoInspectorPane.h"
#import "AIContactInfoImageViewWithImagePicker.h"
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <AIUtilities/AIDateFormatterAdditions.h>
#import <AIUtilities/AIDelayedTextField.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/AITextAttributes.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIHTMLDecoder.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIListBookmark.h>
#import <Adium/AIListContact.h>
#import <Adium/AIListGroup.h>
#import <Adium/AIListObject.h>
#import <Adium/AIMetaContact.h>
#import <Adium/AIService.h>
#import <Adium/AIServiceIcons.h>
#import <Adium/AIStatusIcons.h>
#import <Contacts/Contacts.h>

#define WIDTH_PROFILE_HEADER 100.0f

@interface AIInfoInspectorPane ()
- (void)updateUserIcon:(AIListObject *)inObject;
- (void)updateAccountName:(AIListObject *)inObject;
- (void)updateStatusIcon:(AIListObject *)inObject;
- (void)updateAlias:(AIListObject *)inObject;
- (void)addAddressBookInfoToProfileArray:(NSMutableArray *)profileArray forContact:(AIListContact *)inContact;
- (void)addTooltipEntriesToProfileArray:(NSMutableArray *)profileArray forContact:(AIListContact *)inContact;
- (NSAttributedString *)attributedStringProfileForListObject:(AIListObject *)inObject;
- (void)updateProfile:(NSAttributedString *)infoString context:(AIListObject *)object;
- (void)setAttributedString:(NSAttributedString *)infoString intoTextView:(NSTextView *)textView;
@end

@implementation AIInfoInspectorPane

- (id)init
{
	self =
}

- (void)addTooltipEntriesToProfileArray:(NSMutableArray *)profileArray forContact:(AIListContact *)inContact
{
	NSArray *tooltipEntries = [[adium.interfaceController contactListTooltipPrimaryEntries]
		arrayByAddingObjectsFromArray:[adium.interfaceController contactListTooltipSecondaryEntries]];
	for (id<AIContactListTooltipEntry> tooltipEntry in tooltipEntries) {
		if ([tooltipEntry shouldDisplayInContactInspector]) {
			id label, value;
			if ((label = [tooltipEntry labelForObject:inContact]) &&
				(value = [tooltipEntry entryForObject:inContact])) {
				[profileArray
					addObject:[NSDictionary dictionaryWithObjectsAndKeys:label, KEY_KEY, value, KEY_VALUE, nil]];
			}
		}
	}
}

@end
