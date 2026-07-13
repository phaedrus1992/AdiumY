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

#import "AIAddressBookController.h"
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <AIUtilities/AIDictionaryAdditions.h>
#import <AIUtilities/AIFileManagerAdditions.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIMutableOwnerArray.h>
#import <AIUtilities/AIStringAdditions.h>
#import <Adium/AIAccount.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIControllerProtocol.h>
#import <Adium/AIListObject.h>
#import <Adium/AIMenuControllerProtocol.h>
#import <Adium/AIMetaContact.h>
#import <Adium/AIService.h>
#import <Adium/AIUserIcons.h>

#import "AIAddressBookUserIconSource.h"

#define IMAGE_LOOKUP_INTERVAL 0.01
#define SHOW_IN_AB_CONTEXTUAL_MENU_TITLE                                                                               \
	AILocalizedString(@"Show In Address Book", "Show In Address Book Contextual Menu")
#define EDIT_IN_AB_CONTEXTUAL_MENU_TITLE                                                                               \
	AILocalizedString(@"Edit In Address Book", "Edit In Address Book Contextual Menu")
#define ADD_TO_AB_CONTEXTUAL_MENU_TITLE AILocalizedString(@"Add To Address Book", "Add To Address Book Contextual Menu")

#define CONTACT_ADDED_SUCCESS_TITLE                                                                                    \
	AILocalizedString(@"Success",                                                                                      \
					  "Title of a panel shown after adding successfully adding a contact to the address book.")
#define CONTACT_ADDED_SUCCESS_Message                                                                                  \
	AILocalizedString(@"%@ had been successfully added to the Address Book.\nWould you like to edit the card now?", nil)
#define CONTACT_ADDED_ERROR_TITLE AILocalizedString(@"Error", nil)
#define CONTACT_ADDED_ERROR_Message                                                                                    \
	AILocalizedString(@"An error had occurred while adding %@ to the Address Book.", nil)

#define KEY_ADDRESS_BOOK_ACTIONS_INSTALLED @"Adium:Installed Adress Book Actions 1.3"

#define KEY_AB_TO_METACONTACT_DICT @"UniqueIDToMetaContactObjectIDDictionary"

#define KEY_AB_ME_CARD_IDENTIFIER @"ABMeCardIdentifier"

/// Default set of CNContact keys fetched for address book integration lookups.
static NSArray *ABDefaultContactKeys(void)
{
	static NSArray *keys = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		keys = [[NSArray alloc]
			initWithObjects:CNContactIdentifierKey, CNContactGivenNameKey, CNContactMiddleNameKey,
							CNContactFamilyNameKey, CNContactNicknameKey, CNContactPhoneticGivenNameKey,
							CNContactPhoneticMiddleNameKey, CNContactPhoneticFamilyNameKey, CNContactEmailAddressesKey,
							CNContactInstantMessageAddressesKey, CNContactUrlAddressesKey, CNContactImageDataKey,
							CNContactOrganizationNameKey, CNContactTypeKey, nil];
	});
	return keys;
}

@interface AIAddressBookController ()
+ (CNContact *)_searchForUID:(NSString *)UID serviceID:(NSString *)serviceID;
- (void)updateAllContacts;
- (void)updateSelfIncludingIcon:(BOOL)includeIcon;
- (NSString *)nameForPerson:(CNContact *)person phonetic:(NSString **)phonetic;
- (void)rebuildAddressBookDict;
- (void)showInAddressBook;
- (void)editInAddressBook;
- (void)addToAddressBookDict:(NSArray *)people;
- (void)removeFromAddressBookDict:(NSArray *)identifiers;
- (void)installAddressBookActions;
- (NSString *)meContactIdentifier;

- (void)adiumFinishedLaunching:(NSNotification *)notification;
- (void)addToAddressBook;
- (void)contactStoreChanged:(NSNotification *)notification;
- (void)accountListChanged:(NSNotification *)notification;
@end

/*!
 * @class AIAddressBookController
 * @brief Provides Contacts framework integration
 *
 * This class allows Adium to seamlessly interact with the system Contacts database, pulling names and icons, storing
 * icons if desired, and generating metaContacts based on screen name grouping.  It relies upon cards having screen
 * names listed in the appropriate instant message service fields in the Contacts database.
 */
@implementation AIAddressBookController

static AIAddressBookController *addressBookController = nil;
static CNContactStore *contactStore;
static NSMutableDictionary *addressBookDict;
static NSDictionary *serviceDict;

NSString *serviceIDForOscarUID(NSString *UID);
NSString *serviceIDForJabberUID(NSString *UID);

+ (BOOL)isAddressBookAccessGranted
{
	return [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts] == CNAuthorizationStatusAuthorized;
}

+ (void)startAddressBookIntegration
{
	if (addressBookController)
		return;

	CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
	if (status == CNAuthorizationStatusNotDetermined) {
		// Request access — will create controller asynchronously on grant
		CNContactStore *store = [[CNContactStore alloc] init];
		[store requestAccessForEntityType:CNEntityTypeContacts
						completionHandler:^(BOOL granted, NSError *error) {
							if (granted) {
								dispatch_async(dispatch_get_main_queue(), ^{
									addressBookController = [[self alloc] init];
								});
							}
						}];
		[store release];
	} else if (status == CNAuthorizationStatusAuthorized) {
		addressBookController = [[self alloc] init];
	}
}

- (id)init
{
	if ((self = [super init])) {
		meTag = -1;
		addressBookDict = nil;
		createMetaContacts = NO;

		personUniqueIdToMetaContactDict = [[NSMutableDictionary alloc] init];

		// Configure our preferences
		[adium.preferenceController registerDefaults:[NSDictionary dictionaryNamed:AB_DISPLAYFORMAT_DEFAULT_PREFS
																		  forClass:[self class]]
											forGroup:PREF_GROUP_ADDRESSBOOK];

		// We want the enableImport preference immediately (without waiting for the preferences observer to be
		// registered in adiumFinishedLaunching:)
		enableImport = [[adium.preferenceController preferenceForKey:KEY_AB_ENABLE_IMPORT
															   group:PREF_GROUP_ADDRESSBOOK] boolValue];

		// If Contacts integration is enabled, we need those preferences to determine contact's names
		if (enableImport) {
			displayFormat = [[adium.preferenceController preferenceForKey:KEY_AB_DISPLAYFORMAT
																	group:PREF_GROUP_ADDRESSBOOK] retain];
			useFirstName = [[adium.preferenceController preferenceForKey:KEY_AB_USE_FIRSTNAME
																   group:PREF_GROUP_ADDRESSBOOK] boolValue];
			useNickNameOnly = [[adium.preferenceController preferenceForKey:KEY_AB_USE_NICKNAME
																	  group:PREF_GROUP_ADDRESSBOOK] boolValue];
		}

		// If old format-menu preference is set, perform migration
		if ([adium.preferenceController preferenceForKey:@"AB Display Format" group:PREF_GROUP_ADDRESSBOOK]) {

			[displayFormat release];

			NSInteger oldPreference =
				[[adium.preferenceController preferenceForKey:@"AB Display Format"
														group:PREF_GROUP_ADDRESSBOOK] integerValue];

			switch (oldPreference) {
			case 0: // firstlast
				displayFormat = [[NSString alloc] initWithFormat:@"%@ %@", FORMAT_FIRST_FULL, FORMAT_LAST_FULL];
				break;
			case 1: // first
				displayFormat = [FORMAT_FIRST_FULL retain];
				break;
			case 2: // lastfirst
				displayFormat = [[NSString alloc] initWithFormat:@"%@, %@", FORMAT_LAST_FULL, FORMAT_FIRST_FULL];
				break;
			case 3: // lastfirstnocomma
				displayFormat = [[NSString alloc] initWithFormat:@"%@ %@", FORMAT_LAST_FULL, FORMAT_FIRST_FULL];
				break;
			case 4: // firstlastinitial
				displayFormat = [[NSString alloc] initWithFormat:@"%@ %@", FORMAT_FIRST_FULL, FORMAT_LAST_INITIAL];
				break;
			default:
				displayFormat = [[NSString alloc] initWithFormat:@"%@ %@", FORMAT_FIRST_FULL, FORMAT_LAST_FULL];
			}

			[adium.preferenceController setPreference:nil forKey:@"AB Display Format" group:PREF_GROUP_ADDRESSBOOK];
			[adium.preferenceController setPreference:displayFormat
											   forKey:KEY_AB_DISPLAYFORMAT
												group:PREF_GROUP_ADDRESSBOOK];
		}

		// Services dictionary: maps serviceID → CNInstantMessageService string
		serviceDict = [[NSDictionary alloc]
			initWithObjectsAndKeys:CNInstantMessageServiceAIM, @"AIM", CNInstantMessageServiceJabber, @"Jabber",
								   CNInstantMessageServiceMSN, @"MSN", CNInstantMessageServiceYahoo, @"Yahoo!",
								   CNInstantMessageServiceICQ, @"ICQ", nil];

		// Shared Contact Store
		contactStore = [[CNContactStore alloc] init];

		[self installAddressBookActions];

		// Wait for Adium to finish launching before we build the address book so the contact list will be ready
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(adiumFinishedLaunching:)
													 name:AIApplicationDidFinishLoadingNotification
												   object:nil];

		// Update self immediately so the information is available to plugins and interface elements as they load
		[self updateSelfIncludingIcon:YES];
	}
	return self;
}

- (void)installAddressBookActions
{
	NSNumber *installedActions =
		[[NSUserDefaults standardUserDefaults] objectForKey:KEY_ADDRESS_BOOK_ACTIONS_INSTALLED];

	if (!installedActions || ![installedActions boolValue]) {
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSArray *libraryDirectoryArray;
		NSString *libraryDirectory, *pluginDirectory;

		libraryDirectoryArray = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
		if ([libraryDirectoryArray count]) {
			libraryDirectory = [libraryDirectoryArray objectAtIndex:0];

		} else {
			// Ridiculous safety since everyone should have a Library folder...
			libraryDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@"Library"];
			[fileManager createDirectoryAtPath:libraryDirectory
				   withIntermediateDirectories:YES
									attributes:nil
										 error:NULL];
		}

		pluginDirectory = [[libraryDirectory stringByAppendingPathComponent:@"Address Book Plug-Ins"]
			stringByAppendingPathComponent:@"/"];
		[fileManager createDirectoryAtPath:pluginDirectory withIntermediateDirectories:YES attributes:nil error:NULL];

		for (NSString *name in [NSArray arrayWithObjects:@"AIM", @"MSN", @"Yahoo", @"ICQ", @"Jabber", @"SMS", nil]) {
			NSString *fullName = [NSString stringWithFormat:@"AdiumAddressBookAction_%@", name];
			NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:fullName ofType:@"scpt"];

			if (path) {
				NSString *destination =
					[pluginDirectory stringByAppendingPathComponent:[fullName stringByAppendingPathExtension:@"scpt"]];
				[fileManager trashFileAtPath:destination];
				[fileManager copyItemAtPath:path toPath:destination error:NULL];

				// Remove the old xtra if installed
				[fileManager
					trashFileAtPath:[pluginDirectory
										stringByAppendingPathComponent:[NSString
																		   stringWithFormat:@"%@-Adium.scpt", name]]];
			} else {
				AILogWithSignature(@"Warning: Could not find %@ in %p.", fullName, self);
			}
		}

		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES]
												  forKey:KEY_ADDRESS_BOOK_ACTIONS_INSTALLED];
	}
}

+ (void)stopAddressBookIntegration
{
	[[AIContactObserverManager sharedManager] unregisterListObjectObserver:addressBookController];
	[adium.preferenceController unregisterPreferenceObserver:addressBookController];
	[[NSNotificationCenter defaultCenter] removeObserver:addressBookController];

	[addressBookController release];
	addressBookController = nil;
}

- (void)dealloc
{
	[serviceDict release];
	serviceDict = nil;

	[contactStore release];
	contactStore = nil;
	[personUniqueIdToMetaContactDict release];
	personUniqueIdToMetaContactDict = nil;

	[[AIContactObserverManager sharedManager] unregisterListObjectObserver:self];
	[adium.preferenceController unregisterPreferenceObserver:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[displayFormat release];
	displayFormat = nil;

	[super dealloc];
}

/*!
 * @brief Adium finished launching
 *
 * Register our observers for the contact store changing externally and for the account list changing.
 * Register our preference observers. This will trigger initial building of the address book dictionary.
 */
- (void)adiumFinishedLaunching:(NSNotification *)notification
{
	// Create our contextual menus
	showInABContextualMenuItem =
		[[[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:SHOW_IN_AB_CONTEXTUAL_MENU_TITLE
															  action:@selector(showInAddressBook)
													   keyEquivalent:@""] autorelease];
	[showInABContextualMenuItem setTarget:self];
	[showInABContextualMenuItem setTag:AIRequiresAddressBookEntry];

	editInABContextualMenuItem =
		[[[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:EDIT_IN_AB_CONTEXTUAL_MENU_TITLE
															  action:@selector(editInAddressBook)
													   keyEquivalent:@""] autorelease];
	[editInABContextualMenuItem setTarget:self];
	[editInABContextualMenuItem setKeyEquivalentModifierMask:NSAlternateKeyMask];
	[editInABContextualMenuItem setAlternate:YES];
	[editInABContextualMenuItem setTag:AIRequiresAddressBookEntry];

	addToABContexualMenuItem =
		[[[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:ADD_TO_AB_CONTEXTUAL_MENU_TITLE
															  action:@selector(addToAddressBook)
													   keyEquivalent:@""] autorelease];
	[addToABContexualMenuItem setTarget:self];
	[addToABContexualMenuItem setTag:AIRequiresNoAddressBookEntry];

	// Install our menus
	[adium.menuController addContextualMenuItem:addToABContexualMenuItem toLocation:Context_Contact_Action];
	[adium.menuController addContextualMenuItem:showInABContextualMenuItem toLocation:Context_Contact_Action];
	[adium.menuController addContextualMenuItem:editInABContextualMenuItem toLocation:Context_Contact_Action];

	// Observe external contact store changes — full re-enumeration on change
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(contactStoreChanged:)
												 name:CNContactStoreDidChangeNotification
											   object:nil];

	// Observe account changes
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(accountListChanged:)
												 name:Account_ListChanged
											   object:nil];

	// Observe preferences changes
	id<AIPreferenceController> preferenceController = adium.preferenceController;
	[preferenceController registerPreferenceObserver:self forGroup:PREF_GROUP_ADDRESSBOOK];
	[preferenceController registerPreferenceObserver:self forGroup:PREF_GROUP_USERICONS];

	addressBookUserIconSource = [[AIAddressBookUserIconSource alloc] init];
	[AIUserIcons registerUserIconSource:addressBookUserIconSource];
}

/*!
 * @brief Used as contacts are created and icons are changed.
 *
 * When first created, load a contact's address book information from our dict.
 * When an icon as a property changes, if desired, write the changed icon out to the appropriate contact card.
 */
- (NSSet *)updateListObject:(AIListObject *)inObject keys:(NSSet *)inModifiedKeys silent:(BOOL)silent
{
	AIListContact *listContact;
	NSSet *modifiedAttributes = nil;

	// Just stop here if we don't have an address book dict to work with
	if (!addressBookDict)
		return nil;

	// We handle accounts separately; doing updates here causes chaos in addition to being inefficient.
	if ([inObject isKindOfClass:[AIAccount class]])
		return nil;

	// Only contacts have associated address book info
	if (![inObject isKindOfClass:[AIListContact class]])
		return nil;
	listContact = (AIListContact *)inObject;

	if (inModifiedKeys == nil) { // Only perform this when updating for all list objects or when a contact is created
		CNContact *person = [listContact contactPerson];

		if (person && enableImport) {
			// Load the name if appropriate
			AIMutableOwnerArray *displayNameArray, *phoneticNameArray;
			NSString *displayName, *phoneticName = nil;

			displayNameArray = [listContact displayArrayForKey:@"Display Name"];

			displayName = [self nameForPerson:person phonetic:&phoneticName];

			// Apply the values
			NSString *oldValue = [displayNameArray objectWithOwner:self];
			if (!oldValue || ![oldValue isEqualToString:displayName]) {
				[displayNameArray setObject:displayName withOwner:self];
				modifiedAttributes = [NSSet setWithObject:@"Display Name"];
			}

			if (phoneticName) {
				phoneticNameArray = [listContact displayArrayForKey:@"Phonetic Name"];

				// Apply the values
				oldValue = [phoneticNameArray objectWithOwner:self];
				if (!oldValue || ![oldValue isEqualToString:phoneticName]) {
					[phoneticNameArray setObject:phoneticName withOwner:self];
					modifiedAttributes = [NSSet setWithObjects:@"Display Name", @"Phonetic Name", nil];
				}
			} else {
				phoneticNameArray = [listContact displayArrayForKey:@"Phonetic Name" create:NO];
				// Clear any stored value
				if ([phoneticNameArray objectWithOwner:self]) {
					[displayNameArray setObject:nil withOwner:self];
					modifiedAttributes = [NSSet setWithObjects:@"Display Name", @"Phonetic Name", nil];
				}
			}

		} else {
			AIMutableOwnerArray *displayNameArray, *phoneticNameArray;

			displayNameArray = [listContact displayArrayForKey:@"Display Name" create:NO];

			// Clear any stored value
			if ([displayNameArray objectWithOwner:self]) {
				[displayNameArray setObject:nil withOwner:self];
				modifiedAttributes = [NSSet setWithObject:@"Display Name"];
			}

			phoneticNameArray = [listContact displayArrayForKey:@"Phonetic Name" create:NO];
			// Clear any stored value
			if ([phoneticNameArray objectWithOwner:self]) {
				[phoneticNameArray setObject:nil withOwner:self];
				modifiedAttributes = [NSSet setWithObjects:@"Display Name", @"Phonetic Name", nil];
			}
		}

		// If we changed anything, request an update of the alias / long display name
		if (modifiedAttributes) {
			[[NSNotificationCenter defaultCenter]
				postNotificationName:Contact_ApplyDisplayName
							  object:listContact
							userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:silent]
																 forKey:@"Notify"]];
		}

		// Add this contact to the CNContact's metacontact if it's not already there.
		if (person) {
			AIMetaContact *personMetaContact;
			if ((personMetaContact = [personUniqueIdToMetaContactDict objectForKey:person.identifier]) &&
				(personMetaContact != listContact) && ![personMetaContact containsObject:listContact]) {
				AILog(@"AIAddressBookController: personMetaContact = %@; listContact = %@; performing metacontact "
					  @"grouping",
					  personMetaContact, listContact);
				[adium.contactController groupContacts:[NSArray arrayWithObjects:personMetaContact, listContact, nil]];
			}
		}
	}

	return modifiedAttributes;
}

- (void)listObjectAttributesChanged:(NSNotification *)notification
{
	if (!automaticUserIconSync)
		return;

	AIListObject *inObject = [notification object];
	NSSet *keys = [[notification userInfo] objectForKey:@"Keys"];

	if ([keys containsObject:KEY_USER_ICON] && [inObject isKindOfClass:[AIListContact class]]) {
		AIListContact *listContact = (AIListContact *)inObject;
		CNContact *person = [listContact contactPerson];

		if (person && ![[self meContactIdentifier] isEqualToString:person.identifier]) {
			NSData *existingImageData = person.imageData;
			NSImage *existingImage =
				(existingImageData ? [[[NSImage alloc] initWithData:existingImageData] autorelease] : nil);
			NSImage *objectUserIcon = [listContact userIcon];

			if (!existingImage || objectUserIcon) {
				NSData *objectUserIconData = [objectUserIcon PNGRepresentation];

				if (![objectUserIconData isEqualToData:existingImageData]) {
					CNMutableContact *mutablePerson = [person mutableCopy];
					mutablePerson.imageData = objectUserIconData;

					CNSaveRequest *saveRequest = [[CNSaveRequest alloc] init];
					[saveRequest updateContact:mutablePerson];

					NSError *error = nil;
					if (![contactStore executeSaveRequest:saveRequest error:&error]) {
						AILogWithSignature(@"Error saving image to contact %@: %@", person.identifier, error);
					}

					[mutablePerson release];
					[saveRequest release];
				}
			}
		}
	}
}

/*!
 * @brief Return the name of a CNContact in the way Adium should display it
 *
 * @param person A <tt>CNContact</tt>
 * @param phonetic A pointer to an <tt>NSString</tt> which will be filled with the phonetic display name if available
 * @result A string based on the first name, middle name, last name, and/or nickname of the person, as specified via
 * preferences.
 */
- (NSString *)nameForPerson:(CNContact *)person phonetic:(NSString **)phonetic
{
	NSString *firstName = person.givenName;
	NSString *middleName = person.middleName;
	NSString *lastName = person.familyName;
	NSString *nickName = person.nickname;
	NSString *phoneticFirstName = person.phoneticGivenName;
	NSString *phoneticMiddleName = person.phoneticMiddleName;
	NSString *phoneticLastName = person.phoneticFamilyName;

	NSString *displayName = displayFormat;

	// Fallback if format string is empty or unexpected
	if (!displayName || ![displayName isKindOfClass:[NSString class]] || [displayName isEqualToString:@""]) {
		displayName = FORMAT_FIRST_FULL;
	}

	// If the record is for a company, return the company name if present
	if (person.contactType == CNContactTypeOrganization) {
		NSString *companyName = person.organizationName;
		if (companyName && [companyName length]) {
			return companyName;
		}
	}

	BOOL havePhonetic = ((phonetic != NULL) && (phoneticFirstName || phoneticMiddleName || phoneticLastName));

	if (useNickNameOnly && nickName && [nickName length] != 0)
		return nickName;

	if (useFirstName && (!nickName || [nickName isEqualToString:@""]) && firstName)
		nickName = firstName;

	displayName = [displayName stringByReplacingOccurrencesOfString:FORMAT_FIRST_FULL
														 withString:firstName ? firstName : @""];
	displayName = [displayName
		stringByReplacingOccurrencesOfString:FORMAT_FIRST_INITIAL
								  withString:([firstName length] > 0) ? [firstName substringToIndex:1] : @""];

	displayName = [displayName stringByReplacingOccurrencesOfString:FORMAT_MIDDLE_FULL
														 withString:middleName ? middleName : @""];
	displayName = [displayName
		stringByReplacingOccurrencesOfString:FORMAT_MIDDLE_INITIAL
								  withString:([middleName length] > 0) ? [middleName substringToIndex:1] : @""];

	displayName = [displayName stringByReplacingOccurrencesOfString:FORMAT_LAST_FULL
														 withString:lastName ? lastName : @""];
	displayName = [displayName
		stringByReplacingOccurrencesOfString:FORMAT_LAST_INITIAL
								  withString:([lastName length] > 0) ? [lastName substringToIndex:1] : @""];

	displayName = [displayName stringByReplacingOccurrencesOfString:FORMAT_NICK_FULL
														 withString:nickName ? nickName : @""];
	displayName = [displayName
		stringByReplacingOccurrencesOfString:FORMAT_NICK_INITIAL
								  withString:([nickName length] > 0) ? [nickName substringToIndex:1] : @""];

	if (havePhonetic) {
		*phonetic = displayFormat;

		*phonetic = [*phonetic stringByReplacingOccurrencesOfString:FORMAT_FIRST_FULL
														 withString:phoneticFirstName ? phoneticFirstName : @""];
		*phonetic = [*phonetic stringByReplacingOccurrencesOfString:FORMAT_FIRST_INITIAL
														 withString:([phoneticFirstName length] > 0)
																		? [phoneticFirstName substringToIndex:1]
																		: @""];

		*phonetic = [*phonetic stringByReplacingOccurrencesOfString:FORMAT_MIDDLE_FULL
														 withString:phoneticMiddleName ? phoneticMiddleName : @""];
		*phonetic = [*phonetic stringByReplacingOccurrencesOfString:FORMAT_MIDDLE_INITIAL
														 withString:([phoneticMiddleName length] > 0)
																		? [phoneticMiddleName substringToIndex:1]
																		: @""];

		*phonetic = [*phonetic stringByReplacingOccurrencesOfString:FORMAT_LAST_FULL
														 withString:phoneticLastName ? phoneticLastName : @""];
		*phonetic = [*phonetic
			stringByReplacingOccurrencesOfString:FORMAT_LAST_INITIAL
									  withString:([phoneticLastName length] > 0) ? [phoneticLastName substringToIndex:1]
																				 : @""];

		*phonetic = [*phonetic stringByReplacingOccurrencesOfString:FORMAT_NICK_FULL withString:@""];
		*phonetic = [*phonetic stringByReplacingOccurrencesOfString:FORMAT_NICK_INITIAL withString:@""];
	}

	return displayName;
}

/*!
 * @brief Observe preference changes
 *
 * On first call, this method builds the addressBookDict. Subsequently, it rebuilds the dict only if the "create
 * metaContacts" option is toggled, as metaContacts are created while building the dict.
 *
 * If the user set a new image as a preference for an object, write it out to the contact's card if desired.
 */
- (void)preferencesChangedForGroup:(NSString *)group
							   key:(NSString *)key
							object:(AIListObject *)object
					preferenceDict:(NSDictionary *)prefDict
						 firstTime:(BOOL)firstTime
{
	if (object) {
		[[AIContactObserverManager sharedManager] updateContacts:[NSSet setWithObject:object] forObserver:self];
		return;
	}

	if (![group isEqualToString:PREF_GROUP_ADDRESSBOOK] || [key isEqualToString:KEY_AB_TO_METACONTACT_DICT])
		return;

	BOOL oldCreateMetaContacts = createMetaContacts;

	// load new displayFormat
	enableImport = [[prefDict objectForKey:KEY_AB_ENABLE_IMPORT] boolValue];
	automaticUserIconSync = [[prefDict objectForKey:KEY_AB_IMAGE_SYNC] boolValue];
	useFirstName = [[prefDict objectForKey:KEY_AB_USE_FIRSTNAME] boolValue];
	useNickNameOnly = [[prefDict objectForKey:KEY_AB_USE_NICKNAME] boolValue];
	displayFormat = [[prefDict objectForKey:KEY_AB_DISPLAYFORMAT] retain];

	createMetaContacts = [[prefDict objectForKey:KEY_AB_CREATE_METACONTACTS] boolValue];

	if (firstTime) {
		// Build the address book dictionary, which will also trigger metacontact grouping as appropriate
		[self rebuildAddressBookDict];

		// Register ourself as a listObject observer, which will update all objects
		[[AIContactObserverManager sharedManager] registerListObjectObserver:self];

		// Note: we don't need to call updateSelfIncludingIcon: because it was already done in installPlugin
	} else {
		// This isn't the first time through

		// If we weren't creating meta contacts before but we are now
		if (!oldCreateMetaContacts && createMetaContacts) {
			/*
			 Build the address book dictionary, which will also trigger metacontact grouping as appropriate
			 Delay to the next run loop to give better UI responsiveness
			 */
			[self performSelector:@selector(rebuildAddressBookDict) withObject:nil afterDelay:0];
		}

		// Update all contacts, which will update objects and then our "me" card information
		[self updateAllContacts];
	}

	if (automaticUserIconSync) {
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(listObjectAttributesChanged:)
													 name:ListObject_AttributesChanged
												   object:nil];
	} else {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:ListObject_AttributesChanged object:nil];
	}
}

/*!
 * @brief Returns the appropriate service for the property.
 *
 * @param property - a CNInstantMessageService string.
 */
+ (AIService *)serviceFromProperty:(NSString *)property
{
	NSString *serviceID = nil;

	if ([property isEqualToString:CNInstantMessageServiceAIM])
		serviceID = @"AIM";

	else if ([property isEqualToString:CNInstantMessageServiceICQ])
		serviceID = @"ICQ";

	else if ([property isEqualToString:CNInstantMessageServiceMSN])
		serviceID = @"MSN";

	else if ([property isEqualToString:CNInstantMessageServiceJabber])
		serviceID = @"Jabber";

	else if ([property isEqualToString:CNInstantMessageServiceYahoo])
		serviceID = @"Yahoo!";

	return (serviceID ? [adium.accountController firstServiceWithServiceID:serviceID] : nil);
}

/*!
 * @brief Returns the appropriate property for the service.
 */
+ (NSString *)propertyFromService:(AIService *)inService
{
	NSString *result;
	NSString *serviceID = inService.serviceID;

	result = [serviceDict objectForKey:serviceID];

	// Check for some special cases
	if (!result) {
		if ([serviceID isEqualToString:@"GTalk"]) {
			result = CNInstantMessageServiceJabber;
		} else if ([serviceID isEqualToString:@"LiveJournal"]) {
			result = CNInstantMessageServiceJabber;
		} else if ([serviceID isEqualToString:@"Mac"]) {
			result = CNInstantMessageServiceAIM;
		} else if ([serviceID isEqualToString:@"MobileMe"]) {
			result = CNInstantMessageServiceAIM;
		}
	}

	return result;
}

#pragma mark Searching
/*!
 * @brief Find a CNContact corresponding to an AIListObject
 *
 * @param inObject The object for which it search
 * @result A CNContact if one is found, or nil if none is found
 */
+ (CNContact *)personForListObject:(AIListObject *)inObject
{
	CNContact *contact = nil;

	if (!contactStore) {
		AILogWithSignature(@"contactStore not initialized — address book integration not yet available");
		return nil;
	}

	NSString *identifier = [inObject preferenceForKey:KEY_AB_UNIQUE_ID group:PREF_GROUP_ADDRESSBOOK];
	if (!identifier)
		identifier = [inObject valueForProperty:KEY_AB_UNIQUE_ID];

	if (identifier) {
		NSError *error = nil;
		contact = [contactStore unifiedContactWithIdentifier:identifier
												 keysToFetch:ABDefaultContactKeys()
													   error:&error];
		if (error) {
			AILogWithSignature(@"Error fetching contact %@: %@", identifier, error);
		}
	}

	if (!contact) {
		if ([inObject isKindOfClass:[AIMetaContact class]]) {
			// Search for the first CNContact for a listContact within the metaContact
			for (AIListContact *listContact in [(AIMetaContact *)inObject listContactsIncludingOfflineAccounts]) {
				contact = [self personForListObject:listContact];
				if (contact)
					break;
			}
		} else {
			NSString *UID = inObject.UID;
			NSString *serviceID = inObject.service.serviceID;

			contact = [self _searchForUID:UID serviceID:serviceID];

			/* If we don't find anything yet, look at alternative service possibilities:
			 *    AIM <--> ICQ
			 */
			if (!contact) {
				if ([serviceID isEqualToString:@"AIM"]) {
					contact = [self _searchForUID:UID serviceID:@"ICQ"];
				} else if ([serviceID isEqualToString:@"ICQ"]) {
					contact = [self _searchForUID:UID serviceID:@"AIM"];
				}
			}
		}
	}

	return contact;
}

/*!
 * @brief Find a CNContact for a given UID and serviceID combination
 *
 * Uses our addressBookDict cache created in rebuildAddressBook.
 *
 * @param UID The UID for the contact
 * @param serviceID The serviceID for the contact
 * @result A corresponding <tt>CNContact</tt>
 */

+ (CNContact *)_searchForUID:(NSString *)UID serviceID:(NSString *)serviceID
{
	CNContact *contact = nil;
	NSDictionary *dict;

	if ([serviceID isEqualToString:@"Mac"] || [serviceID isEqualToString:@"MobileMe"]) {
		dict = [addressBookDict objectForKey:@"AIM"];

	} else if ([serviceID isEqualToString:@"GTalk"]) {
		dict = [addressBookDict objectForKey:@"Jabber"];

	} else if ([serviceID isEqualToString:@"LiveJournal"]) {
		dict = [addressBookDict objectForKey:@"Jabber"];

	} else if ([serviceID isEqualToString:@"Yahoo! Japan"]) {
		dict = [addressBookDict objectForKey:@"Yahoo!"];

	} else {
		dict = [addressBookDict objectForKey:serviceID];
	}

	if (dict) {
		NSString *identifier = [dict objectForKey:[UID compactedString]];
		if (identifier) {
			NSError *error = nil;
			contact = [contactStore unifiedContactWithIdentifier:identifier
													 keysToFetch:ABDefaultContactKeys()
														   error:&error];
			if (error) {
				AILogWithSignature(@"Error fetching contact %@: %@", identifier, error);
			}
		}
	}

	return contact;
}

#pragma mark -

- (NSSet *)contactsForPerson:(CNContact *)person
{
	NSString *serviceID;
	NSMutableSet *contactSet = [NSMutableSet set];
	NSInteger i, count;

	// A CNContact may have multiple emails; iterate through them looking for @mac.com addresses
	count = [person.emailAddresses count];
	for (i = 0; i < count; i++) {
		CNLabeledValue *labeledValue = [person.emailAddresses objectAtIndex:i];
		NSString *email = labeledValue.value;

		if ([email hasSuffix:@"@mac.com"]) {
			// Retrieve all appropriate contacts
			NSSet *contacts = [adium.contactController
				allContactsWithService:[adium.accountController firstServiceWithServiceID:@"Mac"]
								   UID:email];

			// Add them to our set
			[contactSet unionSet:contacts];

		} else if ([email hasSuffix:@"me.com"]) {
			// Retrieve all appropriate contacts
			NSSet *contacts = [adium.contactController
				allContactsWithService:[adium.accountController firstServiceWithServiceID:@"MobileMe"]
								   UID:email];

			// Add them to our set
			[contactSet unionSet:contacts];

		} else if ([email hasSuffix:@"gmail.com"] || [email hasSuffix:@"googlemail.com"]) {
			// Retrieve all appropriate contacts
			NSSet *contacts = [adium.contactController
				allContactsWithService:[adium.accountController firstServiceWithServiceID:@"GTalk"]
								   UID:email];

			// Add them to our set
			[contactSet unionSet:contacts];
		} else if ([email hasSuffix:@"hotmail.com"]) {
			// Retrieve all appropriate contacts
			NSSet *contacts = [adium.contactController
				allContactsWithService:[adium.accountController firstServiceWithServiceID:@"MSN"]
								   UID:email];

			// Add them to our set
			[contactSet unionSet:contacts];
		}
	}

	// A CNContact may have multiple URLs; iterate through them looking for fb:// addresses
	count = [person.urlAddresses count];
	for (i = 0; i < count; i++) {
		CNLabeledValue *labeledValue = [person.urlAddresses objectAtIndex:i];
		NSURL *homepage = [NSURL URLWithString:(NSString *)labeledValue.value];
		if ([[homepage scheme] isEqualToString:@"fb"]) {
			// Retrieve all appropriate contacts
			// This will be fb://profile/XXX where XXX is the UID
			NSString *facebookNumber = (NSString *)[(NSString *)labeledValue.value lastPathComponent];
			if (![facebookNumber length])
				continue;
			NSString *facebookUID = [NSString stringWithFormat:@"-%@@chat.facebook.com", facebookNumber];

			NSSet *contacts = [adium.contactController
				allContactsWithService:[adium.accountController firstServiceWithServiceID:@"Facebook"]
								   UID:facebookUID];

			// Add them to our set
			[contactSet unionSet:contacts];
		}
	}

	// Iterate instant message addresses
	count = [person.instantMessageAddresses count];
	for (i = 0; i < count; i++) {
		CNLabeledValue *labeledIM = [person.instantMessageAddresses objectAtIndex:i];
		CNInstantMessageAddress *imAddress = labeledIM.value;
		NSString *imService = imAddress.service;
		NSString *UID = imAddress.username;

		if (![UID length])
			continue;

		if ([imService isEqualToString:CNInstantMessageServiceAIM]) {
			serviceID = serviceIDForOscarUID(UID);

		} else if ([imService isEqualToString:CNInstantMessageServiceJabber]) {
			serviceID = serviceIDForJabberUID(UID);

		} else if ([imService isEqualToString:CNInstantMessageServiceMSN]) {
			serviceID = @"MSN";

		} else if ([imService isEqualToString:CNInstantMessageServiceYahoo]) {
			serviceID = @"Yahoo!";

		} else if ([imService isEqualToString:CNInstantMessageServiceICQ]) {
			serviceID = @"ICQ";

		} else {
			continue;
		}

		NSSet *contacts = [adium.contactController
			allContactsWithService:[adium.accountController firstServiceWithServiceID:serviceID]
							   UID:[UID compactedString]];

		// Add them to our set
		[contactSet unionSet:contacts];
	}

	return contactSet;
}

#pragma mark Contact store changed
/*!
 * @brief Contact store changed externally
 *
 * Full re-enumeration — rebuilds the entire address book cache and updates all contacts.
 */
- (void)contactStoreChanged:(NSNotification *)notification
{
	[[AIContactObserverManager sharedManager] delayListObjectNotifications];

	[self rebuildAddressBookDict];

	[[AIContactObserverManager sharedManager] endListObjectNotificationsDelay];

	[self updateSelfIncludingIcon:YES];
}

/*!
 * @brief Update all existing contacts and accounts
 */
- (void)updateAllContacts
{
	[[AIContactObserverManager sharedManager] updateAllListObjectsForObserver:self];
	[self updateSelfIncludingIcon:YES];
}

/*!
 * @brief Account list changed: Update all existing accounts
 */
- (void)accountListChanged:(NSNotification *)notification
{
	[self updateSelfIncludingIcon:NO];
}

/*!
 * @brief Returns the "me" contact identifier from the system Contacts preferences.
 *
 * On macOS, the "My Card" setting in Contacts.app is stored in the com.apple.AddressBook defaults domain.
 */
- (NSString *)meContactIdentifier
{
	NSString *identifier = [[NSUserDefaults standardUserDefaults] stringForKey:KEY_AB_ME_CARD_IDENTIFIER];
	if (!identifier) {
		NSDictionary *abPrefs =
			[[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.apple.AddressBook"];
		identifier = [abPrefs objectForKey:KEY_AB_ME_CARD_IDENTIFIER];
	}
	return identifier;
}

/*!
 * @brief Update all existing accounts and default icon
 *
 * We use the "me" card to determine the default icon and account display name
 */
- (void)updateSelfIncludingIcon:(BOOL)includeIcon
{
	@try {
		NSString *meIdentifier = [self meContactIdentifier];
		if (!meIdentifier)
			return;

		NSError *error = nil;
		CNContact *me = [contactStore unifiedContactWithIdentifier:meIdentifier
													   keysToFetch:ABDefaultContactKeys()
															 error:&error];
		if (!me || error)
			return;

		// Default buddy icon
		if (includeIcon) {
			NSData *imageData = me.imageData;
			if (imageData) {
				[adium.preferenceController setPreference:imageData
												   forKey:KEY_DEFAULT_USER_ICON
													group:GROUP_ACCOUNT_STATUS];
			}
		}

		// Set account display names
		if (enableImport) {
			NSString *myPhonetic = nil;
			NSString *myDisplayName = [self nameForPerson:me phonetic:&myPhonetic];

			for (AIAccount *account in adium.accountController.accounts) {
				if (![account isTemporary]) {
					[[account displayArrayForKey:@"Display Name"] setObject:myDisplayName
																  withOwner:self
															  priorityLevel:Low_Priority];

					if (myPhonetic) {
						[[account displayArrayForKey:@"Phonetic Name"] setObject:myPhonetic
																	   withOwner:self
																   priorityLevel:Low_Priority];
					}
				}
			}

			[adium.preferenceController
				registerDefaults:[NSDictionary dictionaryWithObject:[[NSAttributedString stringWithString:myDisplayName]
																		dataRepresentation]
															 forKey:KEY_ACCOUNT_DISPLAY_NAME]
						forGroup:GROUP_ACCOUNT_STATUS];
		}
	} @catch (id exc) {
		NSLog(@"ABIntegration: Caught %@", exc);
	}
}

#pragma mark Address book caching
/*!
 * @brief rebuild our address book lookup dictionary
 */
- (void)rebuildAddressBookDict
{
	// Delay listObjectNotifications to speed up metaContact creation
	[[AIContactObserverManager sharedManager] delayListObjectNotifications];

	[addressBookDict release];
	addressBookDict = [[NSMutableDictionary alloc] init];

	// Fetch all contacts and populate the cache
	NSError *error = nil;
	CNContactFetchRequest *fetchRequest = [[CNContactFetchRequest alloc] initWithKeysToFetch:ABDefaultContactKeys()];
	[contactStore enumerateContactsWithFetchRequest:fetchRequest
											  error:&error
										 usingBlock:^(CNContact *contact, BOOL *stop) {
											 [self addToAddressBookDict:[NSArray arrayWithObject:contact]];
										 }];
	[fetchRequest release];

	if (error) {
		AILogWithSignature(@"Error enumerating contacts: %@", error);
	}

	// Stop delaying list object notifications since we are done
	[[AIContactObserverManager sharedManager] endListObjectNotificationsDelay];
}

/*!
 * @brief Service ID for an OSCAR UID
 *
 * If we are on an OSCAR service we need to resolve our serviceID into the appropriate string
 * because we may have a .Mac, an ICQ, or an AIM name in the field
 */
NSString *serviceIDForOscarUID(NSString *UID)
{
	NSString *serviceID;

	if (![UID length])
		return @"AIM";

	const char firstCharacter = [UID characterAtIndex:0];

	// Determine service based on UID
	if ([UID hasSuffix:@"@mac.com"]) {
		serviceID = @"Mac";
	} else if ([UID hasSuffix:@"@me.com"]) {
		serviceID = @"MobileMe";
	} else if (firstCharacter >= '0' && firstCharacter <= '9') {
		serviceID = @"ICQ";
	} else {
		serviceID = @"AIM";
	}

	return serviceID;
}

/*!
 * @brief Service ID for a Jabber UID
 *
 * If we are on the Jabber server, we need to distinguish between Google Talk (GTalk), LiveJournal, and the rest of the
 * Jabber world. serviceID is already Jabber, so we only need to change if we have a special UID.
 */
NSString *serviceIDForJabberUID(NSString *UID)
{
	NSString *serviceID;

	if ([UID hasSuffix:@"@gmail.com"] || [UID hasSuffix:@"@googlemail.com"] ||
		[UID hasSuffix:@"@public.talk.google.com"]) {
		serviceID = @"GTalk";
	} else if ([UID hasSuffix:@"@livejournal.com"]) {
		serviceID = @"LiveJournal";
	} else {
		serviceID = @"Jabber";
	}

	return serviceID;
}

/*!
 * @brief add people to our address book lookup dictionary
 *
 * Rather than continually searching the contact store, a lookup dictionary addressBookDict provides a quick and easy
 * way to look up a contact identifier for an CNContact based on the service and UID of a contact. addressBookDict
 * contains NSDictionary objects keyed by service ID. Each of these NSDictionary objects contains contact identifiers
 * keyed by compacted (that is, no spaces) UID. This means we can search while ignoring spaces.
 *
 * In the process of building we look for cards which have multiple screen names listed and, if desired, automatically
 * create metaContacts based on this information.
 */
- (void)addToAddressBookDict:(NSArray *)people
{
	CNContact *person;
	NSString *serviceID;
	NSMutableDictionary *dict;
	NSInteger i, count;

	for (person in people) {
		NSString *personID = person.identifier;
		NSMutableArray *UIDsArray = [NSMutableArray array];
		NSMutableArray *servicesArray = [NSMutableArray array];

		// A CNContact may have multiple emails; iterate through them looking for @mac.com addresses
		count = [person.emailAddresses count];
		for (i = 0; i < count; i++) {
			CNLabeledValue *labeledValue = [person.emailAddresses objectAtIndex:i];
			NSString *email = labeledValue.value;

			if ([email hasSuffix:@"@mac.com"]) {
				//@mac.com UIDs go into the AIM dictionary
				if (!(dict = [addressBookDict objectForKey:@"AIM"])) {
					dict = [[[NSMutableDictionary alloc] init] autorelease];
					[addressBookDict setObject:dict forKey:@"AIM"];
				}

				[dict setObject:personID forKey:email];

				// Internally we distinguish them as .Mac addresses (for metaContact purposes below)
				[UIDsArray addObject:email];
				[servicesArray addObject:@"Mac"];

			} else if ([email hasSuffix:@"me.com"]) {
				//@me.com UIDs go into the AIM dictionary
				if (!(dict = [addressBookDict objectForKey:@"AIM"])) {
					dict = [[[NSMutableDictionary alloc] init] autorelease];
					[addressBookDict setObject:dict forKey:@"AIM"];
				}

				[dict setObject:personID forKey:email];

				// Internally we distinguish them as .Mac addresses (for metaContact purposes below)
				[UIDsArray addObject:email];
				[servicesArray addObject:@"MobileMe"];

			} else if ([email hasSuffix:@"gmail.com"] || [email hasSuffix:@"googlemail.com"]) {
				// GTalk UIDs go into the Jabber dictionary
				if (!(dict = [addressBookDict objectForKey:@"Jabber"])) {
					dict = [[[NSMutableDictionary alloc] init] autorelease];
					[addressBookDict setObject:dict forKey:@"Jabber"];
				}

				[dict setObject:personID forKey:email];

				// Internally we distinguish them as Google Talk addresses (for metaContact purposes below)
				[UIDsArray addObject:email];
				[servicesArray addObject:@"GTalk"];

			} else if ([email hasSuffix:@"hotmail.com"]) {
				// Hotmail UIDs go into the MSN dictionary
				if (!(dict = [addressBookDict objectForKey:@"MSN"])) {
					dict = [[[NSMutableDictionary alloc] init] autorelease];
					[addressBookDict setObject:dict forKey:@"MSN"];
				}

				[dict setObject:personID forKey:email];

				[UIDsArray addObject:email];
				[servicesArray addObject:@"MSN"];
			}
		}

		// A CNContact may have multiple URLs; iterate through them looking for fb:// addresses
		count = [person.urlAddresses count];
		for (i = 0; i < count; i++) {
			CNLabeledValue *labeledValue = [person.urlAddresses objectAtIndex:i];
			NSURL *homepage = [NSURL URLWithString:(NSString *)labeledValue.value];
			if ([[homepage scheme] isEqualToString:@"fb"]) {
				// Retrieve all appropriate contacts
				// This will be fb://profile/XXX where XXX is the UID
				NSString *facebookNumber = (NSString *)[(NSString *)labeledValue.value lastPathComponent];
				if (![facebookNumber length])
					continue;
				NSString *facebookUID = [NSString stringWithFormat:@"-%@@chat.facebook.com", facebookNumber];
				if (!(dict = [addressBookDict objectForKey:@"Facebook"])) {
					dict = [[[NSMutableDictionary alloc] init] autorelease];
					[addressBookDict setObject:dict forKey:@"Facebook"];
				}

				[dict setObject:personID forKey:facebookUID];

				// Add them to our set
				[UIDsArray addObject:facebookUID];
				[servicesArray addObject:@"Facebook"];
			}
		}

		// Iterate instant message addresses
		count = [person.instantMessageAddresses count];
		for (i = 0; i < count; i++) {
			CNLabeledValue *labeledIM = [person.instantMessageAddresses objectAtIndex:i];
			CNInstantMessageAddress *imAddress = labeledIM.value;
			NSString *imService = imAddress.service;
			NSString *UID = imAddress.username;

			if (![UID length])
				continue;

			BOOL isOSCAR = NO;
			BOOL isJabber = NO;

			if ([imService isEqualToString:CNInstantMessageServiceAIM] ||
				[imService isEqualToString:CNInstantMessageServiceICQ]) {
				isOSCAR = YES;
				serviceID = @"AIM"; // Base service for OSCAR-related entries
			} else if ([imService isEqualToString:CNInstantMessageServiceJabber]) {
				isJabber = YES;
				serviceID = @"Jabber";
			} else if ([imService isEqualToString:CNInstantMessageServiceMSN]) {
				serviceID = @"MSN";
			} else if ([imService isEqualToString:CNInstantMessageServiceYahoo]) {
				serviceID = @"Yahoo!";
			} else {
				continue;
			}

			// Ensure we have a dictionary for this service
			if (!(dict = [addressBookDict objectForKey:serviceID])) {
				dict = [[NSMutableDictionary alloc] init];
				[addressBookDict setObject:dict forKey:serviceID];
				[dict release];
			}

			[dict setObject:personID forKey:[UID compactedString]];

			[UIDsArray addObject:UID];

			if (isOSCAR) {
				serviceID = serviceIDForOscarUID(UID);
			} else if (isJabber) {
				serviceID = serviceIDForJabberUID(UID);
			}

			[servicesArray addObject:serviceID];
		}

		if (([UIDsArray count] > 1) && createMetaContacts) {
			/* Got a record with multiple names. Group the names together, adding them to the meta contact. */
			AIMetaContact *metaContact, *metaContactHint;
			NSString *uniqueId = personID;

			metaContactHint = [adium.contactController knownMetaContactForGroupingUIDs:UIDsArray
																		   forServices:servicesArray];
			if (!metaContactHint) {
				/* Find a metacontact we used previously but which wasn't saved, if possible. This keeps us from
				 * creating a new metacontact with every launch when the metacontact is created by the address book
				 * rather than the user.
				 *
				 * We don't make address book metacontacts actually persistent because then we would persist them even
				 * if the address book card were modified or deleted or if the user disabled "Conslidate contacts listed
				 * on the card."
				 */
				NSDictionary *prefsDict = [adium.preferenceController preferenceForKey:KEY_AB_TO_METACONTACT_DICT
																				 group:PREF_GROUP_ADDRESSBOOK];
				NSNumber *metaContactObjectID = [prefsDict objectForKey:uniqueId];
				if (metaContactObjectID)
					metaContactHint = [adium.contactController metaContactWithObjectID:metaContactObjectID];
			}

			metaContact = [adium.contactController groupUIDs:UIDsArray
												 forServices:servicesArray
										usingMetaContactHint:metaContactHint];
			if (metaContact) {
				[metaContact setValue:uniqueId forProperty:KEY_AB_UNIQUE_ID notify:NotifyNever];

				[personUniqueIdToMetaContactDict setObject:metaContact forKey:uniqueId];
				if (metaContact != metaContactHint) {
					// Keep track of the use of this metacontact for this address book card
					NSMutableDictionary *prefsDict = [[[adium.preferenceController
						preferenceForKey:KEY_AB_TO_METACONTACT_DICT
								   group:PREF_GROUP_ADDRESSBOOK] mutableCopy] autorelease];
					if (!prefsDict)
						prefsDict = [NSMutableDictionary dictionary];
					[prefsDict setObject:[metaContact objectID] forKey:uniqueId];
					[adium.preferenceController setPreference:prefsDict
													   forKey:@"UniqueIDToMetaContactObjectIDDictionary"
														group:PREF_GROUP_ADDRESSBOOK];
				}
			}
		}
	}
}

/*!
 * @brief remove people from our address book lookup dictionary
 */
- (void)removeFromAddressBookDict:(NSArray *)identifiers
{
	for (NSString *identifier in identifiers) {
		// The same person may have multiple services; iterate through them and remove each one.
		for (NSString *serviceID in [serviceDict allKeys]) {

			NSMutableDictionary *dict = [addressBookDict objectForKey:serviceID];

			// The same person may have multiple accounts from the same service; we should remove them all.
			for (NSString *key in [dict allKeysForObject:identifier]) {
				[dict removeObjectForKey:key];
			}
		}

		// Also clean up Facebook entries (Facebook URLs are stored outside the serviceDict)
		NSMutableDictionary *fbDict = [addressBookDict objectForKey:@"Facebook"];
		for (NSString *key in [fbDict allKeysForObject:identifier]) {
			[fbDict removeObjectForKey:key];
		}
	}
}

#pragma mark AB contextual menu

/*!
 * @brief Does the specified listObject have information valid to be added to the address book?
 *
 * Specifically, this requires one or more contacts in the listObject to be on a service we know how
 * to parse into a CNContact.
 */
- (BOOL)contactMayBeAddedToAddressBook:(AIListObject *)contact
{
	BOOL mayBeAdded = NO;
	if ([contact isKindOfClass:[AIMetaContact class]]) {
		for (AIListObject *c in [(AIMetaContact *)contact uniqueContainedObjects]) {
			if ([AIAddressBookController propertyFromService:c.service] != nil) {
				mayBeAdded = YES;
				break;
			}
		}

	} else {
		mayBeAdded = ([AIAddressBookController propertyFromService:contact.service] != nil);
	}

	return mayBeAdded;
}

/*!
 * @brief Validate menu item
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	AIListObject *listObject = adium.menuController.currentContextMenuObject;
	BOOL hasABEntry = ([[self class] personForListObject:listObject] != nil);
	BOOL result = NO;

	if ([menuItem tag] == AIRequiresAddressBookEntry) {
		result = hasABEntry;
	} else if ([menuItem tag] == AIRequiresNoAddressBookEntry) {
		result = (!hasABEntry && [self contactMayBeAddedToAddressBook:listObject]);
	}

	return result;
}

/*!
 * @brief Shows the selected contact in Address Book
 */
- (void)showInAddressBook
{
	CNContact *selectedPerson = [[self class] personForListObject:adium.menuController.currentContextMenuObject];
	NSString *url = [NSString stringWithFormat:@"addressbook://%@", selectedPerson.identifier];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
}

/*!
 * @brief Edits the selected contact in Address Book
 */
- (void)editInAddressBook
{
	CNContact *selectedPerson = [[self class] personForListObject:adium.menuController.currentContextMenuObject];
	NSString *url = [NSString stringWithFormat:@"addressbook://%@?edit", selectedPerson.identifier];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
}

/*!
 * @brief Adds the selected contact to the Address Book
 */
- (void)addToAddressBook
{
	AIListObject *contact = adium.menuController.currentContextMenuObject;
	CNMutableContact *newContact = [[CNMutableContact alloc] init];
	NSArray *contacts =
		([contact isKindOfClass:[AIMetaContact class]] ? [(AIMetaContact *)contact uniqueContainedObjects]
													   : [NSArray arrayWithObject:contact]);
	BOOL validForAddition = NO;
	BOOL success = NO;

	// Set the name
	newContact.givenName = contact.displayName;
	if (![[contact phoneticName] isEqualToString:contact.displayName])
		newContact.phoneticGivenName = [contact phoneticName];

	for (AIListObject *c in contacts) {
		NSString *UID = c.formattedUID;
		NSString *serviceProperty = [AIAddressBookController propertyFromService:c.service];

		/* We may get here with a metacontact which contains one or more contacts ineligible for addition to the Address
		 * Book; skip these entries.
		 */
		if (!UID || !serviceProperty)
			continue;

		/* Gather existing instant message addresses or create a new array */
		NSMutableArray *imAddresses = [[newContact.instantMessageAddresses mutableCopy] autorelease];
		if (!imAddresses)
			imAddresses = [NSMutableArray array];

		CNInstantMessageAddress *imAddress = [[CNInstantMessageAddress alloc] initWithUsername:UID
																					   service:serviceProperty];
		[imAddresses addObject:[CNLabeledValue labeledValueWithLabel:CNLabelInstantMessage value:imAddress]];
		newContact.instantMessageAddresses = imAddresses;
		[imAddress release];

		validForAddition = YES;
	}

	if (validForAddition) {
		// Set the image
		newContact.imageData = [contact userIconData];

		// Add our newly created person to the Contacts database
		CNSaveRequest *saveRequest = [[CNSaveRequest alloc] init];
		[saveRequest addContact:newContact toContainerWithIdentifier:nil];

		NSError *error = nil;
		if ([contactStore executeSaveRequest:saveRequest error:&error]) {
			// Save the identifier of the new person
			[contact setPreference:newContact.identifier forKey:KEY_AB_UNIQUE_ID group:PREF_GROUP_ADDRESSBOOK];

			// Ask the user whether it would like to edit the new contact
			NSInteger alertResult = NSRunAlertPanel(CONTACT_ADDED_SUCCESS_TITLE, CONTACT_ADDED_SUCCESS_Message,
													AILocalizedString(@"Yes", nil), AILocalizedString(@"No", nil), nil,
													contact.displayName);

			if (alertResult == NSOKButton) {
				NSString *url = [[NSString alloc] initWithFormat:@"addressbook://%@?edit", newContact.identifier];
				[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
				[url release];
			}

			success = YES;
		} else {
			AILogWithSignature(@"Error adding contact: %@", error);
		}

		[saveRequest release];
	}

	if (!success)
		NSRunAlertPanel(CONTACT_ADDED_ERROR_TITLE, CONTACT_ADDED_ERROR_Message, nil, nil, nil, contact.displayName);

	// Clean up
	[newContact release];
}

@end
