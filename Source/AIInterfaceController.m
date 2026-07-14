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

#import "AIInterfaceController.h"

#import "AIListOutlineView.h"
#import "KNShelfSplitView.h"
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <AIUtilities/AIColorAdditions.h>
#import <AIUtilities/AIFontAdditions.h>
#import <AIUtilities/AIImageDrawingAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/AITextAttributes.h>
#import <AIUtilities/AITooltipUtilities.h>
#import <AIUtilities/AIWindowAdditions.h>
#import <AIUtilities/AIWindowControllerAdditions.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIAuthorizationRequestsWindowController.h>
#import <Adium/AIChat.h>
#import <Adium/AIChatControllerProtocol.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIContactList.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIListContact.h>
#import <Adium/AIListGroup.h>
#import <Adium/AIListObject.h>
#import <Adium/AIMenuControllerProtocol.h>
#import <Adium/AIMessageTabViewItem.h>
#import <Adium/AIMessageWindowController.h>
#import <Adium/AIMetaContact.h>
#import <Adium/AIService.h>
#import <Adium/AIServiceIcons.h>
#import <Adium/AISortController.h>

#import "AIMessageViewController.h"

#define ERROR_MESSAGE_WINDOW_TITLE AILocalizedString(@"Adium : Error", "Error message window title")
#define LABEL_ENTRY_SPACING 4.0f
#define DISPLAY_IMAGE_ON_RIGHT NO

#define PREF_GROUP_FORMATTING @"Formatting"
#define KEY_FORMATTING_FONT @"Default Font"

#define MESSAGES_WINDOW_MENU_TITLE AILocalizedString(@"Chats", "Title for the messages window menu item")

// #define	LOG_RESPONDER_CHAIN

@interface NSObject (AIInterfaceController_WindowPrefsTarget)
- (void)selectedWindowLevel:(id)sender;
@end

@interface AIInterfaceController ()
- (void)_resetOpenChatsCache;
- (void)_addItemToMainMenuAndDock:(NSMenuItem *)item;
- (NSMutableAttributedString *)_tooltipTitleForObject:(AIListObject *)object;
- (NSMutableAttributedString *)_tooltipBodyForObject:(AIListObject *)object;
- (void)_pasteWithPreferredSelector:(SEL)preferredSelector sender:(id)sender;
- (void)updateCloseMenuKeys;

- (void)saveContainers;
- (void)restoreSavedContainers;
- (void)saveContainersOnQuit:(NSNotification *)notification;

- (void)toggleUserlist:(id)sender;
- (void)toggleUserlistSide:(id)sender;
- (void)clearDisplay:(id)sender;
- (IBAction)closeContextualChat:(id)sender;
- (void)openAuthorizationWindow:(id)sender;
- (void)didReceiveContent:(NSNotification *)notification;
- (void)adiumDidFinishLoading:(NSNotification *)inNotification;
- (void)flashTimer:(NSTimer *)inTimer;

// Window Menu
- (void)updateActiveWindowMenuItem;
- (void)buildWindowMenu;

- (AIChat *)mostRecentActiveChat;
@end

/*!
 * @class AIInterfaceController
 * @brief Interface controller
 *
 * Chat window related requests, such as opening and closing chats, are routed through the interface controller
 * to the appropriate component. The interface controller keeps track of the most recently active chat, handles chat
 * cycling (switching between chats), chat sorting, and so on.  The interface controller also handles switching to
 * an appropriate window or chat when the dock icon is clicked for a 'reopen' event.
 *
 * Contact list window requests, such as toggling window visibilty are routed to the contact list controller component.
 *
 * Error messages are routed through the interface controller.
 *
 * Tooltips, such as seen on hover in the contact list are generated and displayed here.  Tooltip display components and
 * plugins register with the interface controller to be queried for contact information when a tooltip is displayed.
 *
 * When displays in Adium flash, such as in the dock or the contact list for unviewed content, the interface controller
 * manages keeping the flashing synchronized.
 *
 * Finally, the interface controller manages many menu items, providing better menu item validation and target routing
 * than the responder chain alone would do.
 */
@implementation AIInterfaceController

- (id)init
{
	if ((self =
}

- (void)toggleUserlist:(id)sender
{
	[self.activeChat.chatContainer.chatViewController toggleUserList];
}

- (void)toggleUserlistSide:(id)sender
{
	[self.activeChat.chatContainer.chatViewController toggleUserListSide];
}

- (void)clearDisplay:(id)sender
{
	[self.activeChat.chatContainer.messageViewController.messageDisplayController clearView];
}

@end
