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

#import "AIListController.h"
#import "AIAnimatingListOutlineView.h"
#import "AIListWindowController.h"
#import "AIMessageViewController.h"
#import <AIUtilities/AIApplicationAdditions.h>
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <AIUtilities/AIAutoScrollView.h>
#import <AIUtilities/AIEventAdditions.h>
#import <AIUtilities/AIFunctions.h>
#import <AIUtilities/AIOSCompatibility.h>
#import <AIUtilities/AIObjectAdditions.h>
#import <AIUtilities/AIOutlineViewAdditions.h>
#import <AIUtilities/AIPasteboardAdditions.h>
#import <AIUtilities/AIWindowAdditions.h>
#import <Adium/AIChat.h>
#import <Adium/AIChatControllerProtocol.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIContactList.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIContentMessage.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIListBookmark.h>
#import <Adium/AIListContact.h>
#import <Adium/AIListGroup.h>
#import <Adium/AIListObject.h>
#import <Adium/AIListOutlineView.h>
#import <Adium/AIMetaContact.h>
#import <Adium/AIProxyListObject.h>
#import <Adium/AISortController.h>
#import <Adium/AITextAttachmentExtension.h>
#import <Adium/ESFileTransfer.h>

#define EDGE_CATCH_X 40.0f
#define EDGE_CATCH_Y 40.0f

#define MENU_BAR_HEIGHT 22

#define KEY_CONTACT_LIST_DOCKED_TO_BOTTOM_OF_SCREEN
}

AIChat *chat = [adium.chatController openChatWithContact:(AIListContact *)(item.listObject) onPreferredAccount:YES];

[chat.chatContainer.messageViewController addToTextEntryView:mutableString];

[adium.interfaceController setActiveChat:chat];
[NSApp activateIgnoringOtherApps:YES];
[NSApp arrangeInFront:nil];
}
else
{
	AILogWithSignature(@"No contact available to receive files");
	NSBeep();
}
}
else if ((availableType = [[info draggingPasteboard]
			  availableTypeFromArray:[NSArray
										 arrayWithObjects:NSRTFPboardType, NSURLPboardType, NSStringPboardType, nil]]))
{
	// Drag and drop text sending via the contact list.
	if ([item isKindOfClass:[AIListContact class]]) {
		/* This will send the message. Alternately, we could just insert it into the text view... */
		NSAttributedString *messageAttributedString = nil;

		if ([availableType isEqualToString:NSRTFPboardType]) {
			// for RTF data, we want to preserve the formatting, so use dataForType:
			messageAttributedString =
				[NSAttributedString stringWithData:[[info draggingPasteboard] dataForType:NSRTFPboardType]];
		} else if ([availableType isEqualToString:NSURLPboardType]) {
			// NSURLPboardType contains an NSURL object
			messageAttributedString = [NSAttributedString
				stringWithString:[[NSURL URLFromPasteboard:[info draggingPasteboard]] absoluteString]];
		} else if ([availableType isEqualToString:NSStringPboardType]) {
			// this is just plain text, so stringForType: works fine
			messageAttributedString =
				[NSAttributedString stringWithString:[[info draggingPasteboard] stringForType:NSStringPboardType]];
		}

		if (messageAttributedString && [messageAttributedString length] != 0) {
			AIChat *chat =
				[adium.chatController openChatWithContact:(AIListContact *)(item.listObject) onPreferredAccount:YES];

			[chat.chatContainer.messageViewController addToTextEntryView:messageAttributedString];

			[adium.interfaceController setActiveChat:chat];
			[NSApp activateIgnoringOtherApps:YES];
			[NSApp arrangeInFront:nil];
		} else {
			success = NO;
		}

	} else {
		success = NO;
	}
}

[super outlineView:outlineView acceptDrop:info item:item childIndex:idx];

return success;
}

- (void)promptToCombineItems:(NSArray *)items withContact:(AIListContact *)inContact
{
	for (AIListContact *listContact in [items arrayByAddingObject:inContact]) {
		// Make sure all of the items can join the contact.
		if (!listContact.canJoinMetaContacts) {
			NSRunAlertPanel(AILocalizedString(@"Unable to Combine", nil),
							AILocalizedString(@"%@ is not able to be combined into a meta contact.", nil),
							AILocalizedStringFromTable(@"OK", @"Buttons", "Verb 'OK' on a button"), nil, nil,
							listContact.displayName);
			return;
		}
	}

	NSString *promptTitle;

	// Appropriate prompt
	if ([items count] == 1) {
		promptTitle = [NSString
			stringWithFormat:
				AILocalizedString(
					@"Combine %@ and %@?",
					"Title of the prompt when combining two contacts. Each %@ will be filled with a contact name."),
				[[items objectAtIndex:0] displayName], inContact.displayName];
	} else {
		promptTitle =
			[NSString stringWithFormat:AILocalizedString(@"Combine these contacts with %@?",
														 "Title of the prompt when combining two or more contacts with "
														 "another.  %@ will be filled with a contact name."),
									   inContact.displayName];
	}

	// Metacontact creation, prompt the user
	NSDictionary *context =
		[NSDictionary dictionaryWithObjectsAndKeys:inContact, @"destinationListContact", items, @"dragitems", nil];

	NSBeginInformationalAlertSheet(
		promptTitle,
		AILocalizedString(@"Combine",
						  "Button title for accepting the action of combining multiple contacts into a metacontact"),
		AILocalizedString(@"Cancel", nil), nil, nil, self, @selector(mergeContactSheetDidEnd:returnCode:contextInfo:),
		nil,
		context, // we're responsible for retaining the content object
		AILocalizedString(
			@"Once combined, Adium will treat these contacts as a single individual both on your contact list and when "
			@"sending messages.\n\nYou may un-combine these contacts by getting info on the combined contact.",
			"Explanation of metacontact creation"));
}

- (void)mergeContactSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	NSDictionary *context = (NSDictionary *)contextInfo;

	if (returnCode == 1) {
		AIListObject *destinationListContact = [context objectForKey:@"destinationListContact"];
		NSArray *draggedItems = [context objectForKey:@"dragitems"];

		// Group the destination and then the dragged items into a metaContact
		[adium.contactController
			groupContacts:[[NSArray arrayWithObject:destinationListContact]
							  arrayByAddingObjectsFromArray:[self arrayOfAllContactsFromArray:draggedItems]]];

		// XXX multiple containers: we need to make sure that the metacontacts respect manual ordering correctly

		[[NSNotificationCenter defaultCenter] postNotificationName:Contact_OrderChanged object:nil];
	}

	; // We are responsible for retaining & releasing the context dict
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
						change:(NSDictionary *)change
					   context:(void *)context
{
	if (object == contactListView && [keyPath isEqualToString:@"desiredHeight"]) {
		if ([[change objectForKey:NSKeyValueChangeNewKey] integerValue] !=
			[[change objectForKey:NSKeyValueChangeOldKey] integerValue])
			[self contactListDesiredSizeChanged];
	}
}

#pragma mark Preferences

- (AIContactListWindowStyle)windowStyle
{
	NSNumber *windowStyleNumber = [adium.preferenceController preferenceForKey:KEY_LIST_LAYOUT_WINDOW_STYLE
																		 group:PREF_GROUP_APPEARANCE];
	return (windowStyleNumber ? [windowStyleNumber intValue] : AIContactListWindowStyleStandard);
}

@end
