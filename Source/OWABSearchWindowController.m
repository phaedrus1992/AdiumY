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

#import "OWABSearchWindowController.h"
#import <Adium/AIAccountControllerProtocol.h>

#import "AIAddressBookController.h"
#import <AIUtilities/AIImageViewWithImagePicker.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIPopUpButtonAdditions.h>
#import <Adium/AIService.h>
#import <Adium/AIServiceIcons.h>
#import <Adium/AIServiceMenu.h>
#import <Contacts/Contacts.h>
#import <ContactsUI/ContactsUI.h>

#define AB_SEARCH_NIB @"ABSearch"

@interface NSObject (OWABSearchWindowControllerDelegate_Weak)
- (void)OWABSearchWindowControllerDidSelectPerson:(OWABSearchWindowController *)controller;
@end

@interface OWABSearchWindowController () {
	IBOutlet id peoplePicker; // Kept for nib compatibility — unused after Contacts.framework migration
}
- (id)initWithWindowNibName:(NSString *)windowNibName initialService:(AIService *)inService;
- (void)_configurePeoplePicker;
- (void)_setCarryingWindow:(NSWindow *)inWindow;
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)buildContactTypeMenu;
- (void)ensureValidContactTypeSelection;
- (void)configureForCurrentServiceType;
- (IBAction)selectServiceType:(id)sender;
- (void)_setService:(AIService *)inService;
- (void)_setPerson:(CNContact *)inPerson;
- (void)_setScreenName:(NSString *)inName;
@end

/*!
 * @class OWABSearchWindowController
 * @brief Window controller for searching people in the Address Book database.
 */
@implementation OWABSearchWindowController

/*!
 * @brief Prompt for searching a person within the AB database.
 *
 * @param parentWindow Window on which to show the prompt as a sheet. Pass nil for a panel prompt.
 * @param inService The AIService to display initially
 */
+ (id)promptForNewPersonSearchOnWindow:(NSWindow *)parentWindow initialService:(AIService *)inService
{
	OWABSearchWindowController *newABSearchWindow;

	newABSearchWindow = [[self alloc] initWithWindowNibName:AB_SEARCH_NIB initialService:inService];

	if (parentWindow) {
		[NSApp beginSheet:[newABSearchWindow window]
			modalForWindow:parentWindow
			 modalDelegate:newABSearchWindow
			didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
			   contextInfo:nil];
		[newABSearchWindow _setCarryingWindow:parentWindow];
	} else {
		[newABSearchWindow showWindow:nil];
	}
}

/*!
 * @brief Initialize
 */
- (id)initWithWindowNibName:(NSString *)windowNibName initialService:(AIService *)inService
{
	self = [super initWithWindowNibName:windowNibName];

	if (self) {
		delegate = nil;
		person = nil;
		screenName = nil;
		carryingWindow = nil;
		contactImage = nil;
		service = inService;
	}

	return self;
}

/*!
{
	[self setDelegate:nil];

/*!
 * @brief Setup the window before it is displayed
 */
- (void)windowDidLoad
{
	[[self window] center];

	// Localized strings
	// Search window
	[[self window] setTitle:AILocalizedString(@"Search In Address Book", nil)];
	[selectButton setLocalizedString:AILocalizedString(@"Select Buddy", nil)];
	[cancelButton setLocalizedString:AILocalizedString(@"Cancel", nil)];
	[newPersonButton setLocalizedString:AILocalizedString(@"New Person", nil)];
	// New contact window
	[newContactPanel setTitle:AILocalizedString(@"Create New Person", nil)];
	[label_mainTitle setLocalizedString:AILocalizedString(@"Enter the contact's type and screen name/number:", nil)];
	[label_contactType
		setLocalizedString:AILocalizedString(@"Contact Type:", "Contact type service dropdown label in Add Contact")];
	[label_secondaryTitle setLocalizedString:AILocalizedString(@"Address Book Information (optional):", nil)];
	[label_firstName setLocalizedString:AILocalizedString(@"First Name:", nil)];
	[label_lastName setLocalizedString:AILocalizedString(@"Last Name:", nil)];
	[label_nickname setLocalizedString:AILocalizedString(@"Nickname:", nil)];
	[label_email setLocalizedString:AILocalizedString(@"Email:", nil)];
	[label_contactIcon
		setLocalizedString:AILocalizedString(@"Contact Icon", "Contact icon label in create new AB person")];
	[addContactButton setLocalizedString:AILocalizedString(@"Add Contact", nil)];
	[addContactCancelButton setLocalizedString:AILocalizedString(@"Cancel", nil)];

	[imageView_contactIcon setMaxSize:NSMakeSize(256, 256)];

	[self _configurePeoplePicker];
}

/*!
 * @brief Present a CNContactPickerViewController as a sheet
 */
- (void)_configurePeoplePicker
{
	CNContactPicker *picker = [[CNContactPicker alloc] init];
	picker.delegate = self;
	picker.displayedKeys = @[ CNContactInstantMessageAddressesKey ];
	[picker showRelativeToRect:NSZeroRect ofView:selectButton preferredEdge:NSMinYEdge];
}

/*!
 * @brief Hide ourself and inform our delegate
 */
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (delegate && returnCode == NSOKButton)
		[delegate absearchWindowControllerDidSelectPerson:self];

	[sheet orderOut:nil];
}

/*!
 * @brief Cancel
 */
- (IBAction)cancel:(id)sender
{
	if ([self windowShouldClose:self.window]) {
		if ([[self window] isSheet]) {
			[NSApp endSheet:[self window] returnCode:NSCancelButton];
		} else {
			[[self window] close];
		}
	}
}

/*!
 * @brief Select a person
 *
 * With CNContactPicker, the selection is handled via the delegate callback.
 * This IBAction simply closes the window when the user clicks the Select button.
 */
- (IBAction)select:(id)sender
{
	// Close our window
	if ([self windowShouldClose:self.window]) {
		if ([[self window] isSheet]) {
			[NSApp endSheet:[self window] returnCode:NSOKButton];
		} else {
			[[self window] close];
			if (delegate)
				[delegate absearchWindowControllerDidSelectPerson:self];
		}
	}
}

#pragma mark CNContactPickerDelegate

- (void)contactPicker:(CNContactPicker *)picker didSelectContactProperty:(CNContactProperty *)contactProperty
{
	CNContact *selectedContact = contactProperty.contact;
	CNInstantMessageAddress *imAddress = contactProperty.value;

	if ([imAddress isKindOfClass:[CNInstantMessageAddress class]]) {
		[self _setScreenName:imAddress.username];
		[self _setService:[AIAddressBookController serviceFromProperty:imAddress.service]];
	}
	[self _setPerson:selectedContact];

	// Close our window
	if ([[self window] isSheet]) {
		[NSApp endSheet:[self window] returnCode:NSOKButton];
	} else {
		[[self window] close];
		if (delegate)
			[delegate absearchWindowControllerDidSelectPerson:self];
	}
}

/*!
 * @brief Close the people search sheet, and display the create new person sheet
 */
- (IBAction)createNewPerson:(id)sender
{
	// Close the first sheet
	[self cancel:nil];

	// Setup our new window,
	[self setWindow:newContactPanel];
	[newContactPanel setDelegate:self];

	// and show it
	if (carryingWindow) {
		[NSApp beginSheet:newContactPanel
			modalForWindow:carryingWindow
			 modalDelegate:self
			didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
			   contextInfo:nil];
	} else {
		[self showWindow:nil];
		[[self window] center];
	}

	// Configure the views of our new window
	[self buildContactTypeMenu];
	[self configureForCurrentServiceType];
}

/*!
 * @brief Create a new person and add it to the address book database
 */
- (IBAction)addPerson:(id)sender
{
	CNMutableContact *newPerson = [[CNMutableContact alloc] init];
	NSString *contactID = [[textField_contactID stringValue]
		stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	// Create the new contact
	if (![contactID isEqualToString:@""]) {
		NSString *serviceIdentifier = [AIAddressBookController propertyFromService:service];

		if (serviceIdentifier) {
			NSString *email = [[textField_email stringValue]
				stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

			// Set the person's instant message address
			CNInstantMessageAddress *imAddress = [[CNInstantMessageAddress alloc] initWithUsername:contactID
																						   service:serviceIdentifier];
			CNLabeledValue *labeledIM = [CNLabeledValue labeledValueWithLabel:CNLabelInstantMessage value:imAddress];
			newPerson.instantMessageAddresses = @[ labeledIM ];

			// Set the person's email address
			if (![email isEqualToString:@""]) {
				CNLabeledValue *labeledEmail = [CNLabeledValue labeledValueWithLabel:CNLabelEmail value:email];
				newPerson.emailAddresses = @[ labeledEmail ];
			}

			// Set the person's first name
			newPerson.givenName = [textField_firstName stringValue];
			// Set the person's last name
			newPerson.familyName = [textField_lastName stringValue];
			// Set the person's nickname
			newPerson.nickname = [textField_nickname stringValue];
			// Set the person's image
			if (contactImage)
				newPerson.imageData = contactImage;

			// Add our newly created person to the Contacts database
			CNContactStore *store = [[CNContactStore alloc] init];
			CNSaveRequest *saveRequest = [[CNSaveRequest alloc] init];
			[saveRequest addContact:newPerson toContainerWithIdentifier:nil];

			NSError *error = nil;
			if ([store executeSaveRequest:saveRequest error:&error]) {
				[self _setPerson:newPerson];
				[self _setScreenName:contactID];

				// Close our window
				if ([self windowShouldClose:self.window]) {
					if ([[self window] isSheet]) {
						[NSApp endSheet:[self window] returnCode:NSOKButton];
					} else {
						[[self window] close];
						if (delegate)
							[delegate absearchWindowControllerDidSelectPerson:self];
					}
				}
			} else {
				// Cancel if we can't add our person to the Contacts database.
				[self cancel:nil];
			}

		} else {
			// Unknown service type
			[self cancel:nil];
		}
	} else {
		// We didn't get a contact id.
		// This is equal to pressing the cancel button.
		[self cancel:nil];
	}
}

/*!
 * @brief Set our delegat
 */
- (void)setDelegate:(id)newDelegate
{
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

	if (delegate) {
		[nc removeObserver:delegate name:OWABSearchWindowControllerDidSelectPersonNotification object:self];
	}

	if (newDelegate) {
		[nc addObserver:newDelegate
			   selector:@selector(OWABSearchWindowControllerDidSelectPerson:)
				   name:OWABSearchWindowControllerDidSelectPersonNotification
				 object:self];
	}

	delegate = newDelegate;
}

/*!
 * @brief Returns our delegate
 */
- (id)delegate
{
	return delegate;
}

#pragma mark -

/*!
 * @brief Returns the selected person.
 */
- (CNContact *)selectedPerson
{
	return person;
}

/*!
 * @brief Returns the selected person's screen name/number.
 */
- (NSString *)selectedScreenName
{
	return screenName;
}

/*!
 * @brief Returns the selected person's name like it's displayed in AB.
 */
- (NSString *)selectedName
{
	return [CNContactFormatter stringFromContact:person style:CNContactFormatterStyleFullName];
}

/*!
 * @brief Returns the selected person's nickname.
 */
- (NSString *)selectedAlias
{
	return person.nickname;
}

/*!
 * @brief Returns the service of the selected screen name/number.
 */
- (AIService *)selectedService
{
	return service;
}

#pragma mark -
#pragma mark Private

/*!
 * @brief Build and configure the menu of contact service types
 */
- (void)buildContactTypeMenu
{
	// Rebuild the menu
	[popUp_contactType setMenu:[AIServiceMenu menuOfServicesWithTarget:self
													activeServicesOnly:YES
													   longDescription:NO
																format:nil]];

	// Ensure our selection is still valid
	[self ensureValidContactTypeSelection];
}

/*!
 * @brief Called by AIServiceMenu to determine what services should be included
 */
- (BOOL)serviceMenuShouldIncludeService:(AIService *)inService
{
	return (
		([AIAddressBookController propertyFromService:inService] &&
		 [[[adium.accountController accountsCompatibleWithService:inService] valueForKeyPath:@"@sum.online"] boolValue])
			? YES
			: NO);
}

/*!
 * @breif Ensures that the selected contact type is valid, selecting another if it isn't
 */
- (void)ensureValidContactTypeSelection
{
	NSInteger serviceIndex = -1;

	// Force our menu to update.. it needs to be correctly validated for the code below to work
	[[popUp_contactType menu] update];

	// Find the menu item for our current service
	if (service)
		serviceIndex = [popUp_contactType indexOfItemWithRepresentedObject:service];

	// If our service is not available we'll have to pick another one
	if (service && (serviceIndex == -1 || ![[popUp_contactType itemAtIndex:serviceIndex] isEnabled])) {
		[self _setService:nil];
	}

	// If we don't have a service, pick the first availbale one
	if (!service) {
		[self _setService:[[[popUp_contactType menu] firstEnabledMenuItem] representedObject]];
	}

	// Update our menu and window for the current service
	[popUp_contactType selectItemWithRepresentedObject:service];
	[self configureForCurrentServiceType];
}

/*!
 * @brief Configure any service-dependent controls in our window for the current service
 */
- (void)configureForCurrentServiceType
{
	NSString *userNameLabel = [service userNameLabel];

	[label_contactID
		setStringValue:[(userNameLabel ? userNameLabel : AILocalizedString(@"Contact ID", nil))
						   stringByAppendingString:AILocalizedString(@":",
																	 "Colon which will be appended after a label such "
																	 "as 'User Name', before an input field")]];
}

/*!
 * @brief User selected a new service type
 */
- (IBAction)selectServiceType:(id)sender
{
	[self _setService:[[popUp_contactType selectedItem] representedObject]];
	[self configureForCurrentServiceType];
}

/*!
 * @brief Set the current service
 */
- (void)_setService:(AIService *)inService
{
	if (inService != service) {
		service = inService;
	}
}

/*!
 * @brief Set the current person
 */
- (void)_setPerson:(CNContact *)inPerson
{
	if (inPerson != person) {
		person = inPerson;
	}
}

/*!
 * @brief Set the screen name/id
 */
- (void)_setScreenName:(NSString *)inName
{
	if (inName != screenName) {
		screenName = inName;
	}
}

/*!
 * @brief Set the carrying window. This is the window that our sheet is attached to.
 */
- (void)_setCarryingWindow:(NSWindow *)inWindow
{
	if (carryingWindow != inWindow) {
		carryingWindow = inWindow;
	}
}

// AIImageViewWithImagePicker Delegate ---------------------------------------------------------------------
#pragma mark AIImageViewWithImagePicker Delegate
- (void)imageViewWithImagePicker:(AIImageViewWithImagePicker *)sender didChangeToImageData:(NSData *)imageData
{
	if (contactImage != imageData) {
		contactImage = imageData;
	}
}

- (void)deleteInImageViewWithImagePicker:(AIImageViewWithImagePicker *)sender
{
	contactImage = nil;
}

@end

#pragma mark -
@implementation NSObject (OWABSearchWindowControllerDelegate)

/*!
 * @brief A delegate method that is sent when the user has selected a person/value.
 */
- (void)absearchWindowControllerDidSelectPerson:(OWABSearchWindowController *)controller
{
	// Do nothing by default
}

@end
