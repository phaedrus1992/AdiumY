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

#import "AdiumOTREncryption.h"
#import "AIHTMLDecoder.h"
#import <AdiumY/AIAccount.h>
#import <AdiumY/AIAccountControllerProtocol.h>
#import <AdiumY/AIChat.h>
#import <AdiumY/AIChatControllerProtocol.h>
#import <AdiumY/AIContactAlertsControllerProtocol.h>
#import <AdiumY/AIContactControllerProtocol.h>
#import <AdiumY/AIContentControllerProtocol.h>
#import <AdiumY/AIContentMessage.h>
#import <AdiumY/AIInterfaceControllerProtocol.h>
#import <AdiumY/AIListContact.h>
#import <AdiumY/AIListObject.h>
#import <AdiumY/AILoginControllerProtocol.h>
#import <AdiumY/AIService.h>
#import <AdiumY/AIServiceIcons.h>

#import <AIUtilities/AIStringAdditions.h>

#import "ESOTRPreferences.h"
#import "ESOTRPrivateKeyGenerationWindowController.h"
#import "ESOTRUnknownFingerprintController.h"
#import "OTRCommon.h"

/* Order matters: proto.h and tlv.h declare the types message.h uses, and
 * libotr's headers include none of their own dependencies.
 * Fenced off because clang-format sorts includes alphabetically. */
// clang-format off
#import <libotr/instag.h>
#import <libotr/proto.h>
#import <libotr/tlv.h>
#import <libotr/message.h>
#import <libotr/privkey.h>
// clang-format on

#import <stdlib.h>

#define PRIVKEY_PATH [[adium.loginController userDirectory] stringByAppendingPathComponent:@"/OTR/privatekeys/"]
#define FINGERPRINT_PATH [[adium.loginController userDirectory] stringByAppendingPathComponent:@"/OTR/fingerprints.txt"]
#define INSTAG_PATH [[adium.loginController userDirectory] stringByAppendingPathComponent:@"/OTR/instags.txt"]

#define OTRL_INSTAG_MASTER_MAX 0x1FFFFFFFF

#define KEY_OTR_POLICY @"OTR Policy"
#define GROUP_OTR @"OTR"
#define KEY_OTR_PASSPHRASE @"OTR Passphrase"
#define GROUP_OTR_PASSPHRASE @"OTR Passphrase %@"
#define KEY_OTR_SMP_SECRETQUESTION @"OTR SMP Secret Question"
#define KEY_OTR_SMP_SECRETANSWER @"OTR SMP Secret Answer"

@interface AdiumOTREncryption ()
@property(nonatomic, copy) NSString *OTRPersistenceFilePath;
@property(nonatomic, strong) ESOTRPreferences *OTRWindowController;
@property(nonatomic, assign) BOOL keyReadSuccess;
- (void)createOTRFiles;
- (void)emptyPassphraseForAccount:(AIAccount *)inAccount;
- (NSString *)activeFingerprintForContact:(AIListContact *)inContact;
- (void)_accountConnected:(NSNotification *)notification;
- (void)upgradeV1Key:(NSString *)privkeyFilenameNew
		 accountName:(NSString *)newAccountName
		  accountUID:(NSString *)newAccountUID;
- (void)trustFingerprint:(NSString *)fingerprint forUsername:(NSString *)username accountName:(NSString *)accountName;
- (NSString *)pathForEncryptedMessage:(NSString *)messageExtension;
- (void)setSecurityDetails:(NSDictionary *)securityDetailsDict forChat:(AIChat *)inChat;
- (void)verifyUnknownFingerprint:(NSValue *)contextValue;

// Methods called from C functions (need forward declaration before @implementation)
+ (OtrlUserState)userState;
+ (NSString *)accountNameForOtrlAccount:(AIAccount *)inAccount;
- (NSString *)privKeyPathForAccount:(AIAccount *)inAccount;
- (void)showNotificationForContact:(AIListContact *)inContact message:(NSString *)message;
@end

// Static globals for C callbacks
static OtrlUserState otrg_plugin_userstate = NULL;
static AdiumOTREncryption *adiumOTREncryption = nil;

// -------------------------------------------------------------------------------------------------
#pragma mark Helper C functions
// -------------------------------------------------------------------------------------------------

// Forward declarations for functions used before definition
static void update_security_details_for_chat(AIChat *inChat);

static AIAccount *accountFromAccountID(const char *accountID)
{
	@autoreleasepool {
		NSString *accountIDString = [NSString stringWithUTF8String:accountID];
		NSString *internalObjectID = [[accountIDString componentsSeparatedByString:@"."] lastObject];
		return [adium.accountController accountWithInternalObjectID:internalObjectID];
	}
}

static AIService *serviceFromServiceID(const char *serviceID)
{
	@autoreleasepool {
		NSString *sid = [NSString stringWithUTF8String:serviceID];
		return [adium.accountController firstServiceWithServiceID:sid];
	}
}

static AIListContact *contactFromInfo(const char *accountID, const char *protocol, const char *username)
{
	@autoreleasepool {
		if (!accountID || !protocol || !username)
			return nil;

		AIAccount *account = accountFromAccountID(accountID);
		if (!account) {
			account = [adium.accountController accountWithInternalObjectID:[NSString stringWithUTF8String:accountID]];
		}
		if (!account) {
			NSString *protocolNS = [NSString stringWithUTF8String:protocol];
			for (AIAccount *acct in adium.accountController.accounts) {
				if ([acct.service.serviceID isEqualToString:protocolNS]) {
					account = acct;
					break;
				}
			}
		}
		if (!account)
			return nil;

		NSString *uid = [NSString stringWithUTF8String:username];
		return [adium.contactController contactWithService:account.service account:account UID:uid];
	}
}

static AIListContact *contactForContext(ConnContext *context)
{
	if (!context)
		return nil;
	return contactFromInfo(context->accountname, context->protocol, context->username);
}

static AIChat *chatForContext(ConnContext *context)
{
	@autoreleasepool {
		if (!context)
			return nil;

		AIListContact *contact = contactForContext(context);
		AIAccount *account = contact ? contact.account : accountFromAccountID(context->accountname);

		if (account && contact) {
			return [adium.chatController existingChatWithContact:contact];
		}
		return nil;
	}
}

static ConnContext *contextForChat(AIChat *chat)
{
	@autoreleasepool {
		AIAccount *account = [chat account];
		AIListContact *contact = (AIListContact *)[chat listObject];

		if (!account || !contact)
			return NULL;

		NSString *accountName = [AdiumOTREncryption accountNameForOtrlAccount:account];
		NSString *protocol = account.service.serviceID;
		NSString *username = contact.UID;

		return otrl_context_find(otrg_plugin_userstate, username.UTF8String, accountName.UTF8String,
								 protocol.UTF8String, OTRL_INSTAG_BEST, 0, NULL, NULL, NULL);
	}
}

// -------------------------------------------------------------------------------------------------
#pragma mark OTRL callback C functions
// -------------------------------------------------------------------------------------------------

static OtrlPolicy policyForContact(AIListContact *contact);

static OtrlPolicy policy_cb(void *opdata, ConnContext *context)
{
#pragma unused(opdata)
	@autoreleasepool {
		AIListContact *contact = contactForContext(context);
		if (contact) {
			return policyForContact(contact);
		}
		return OTRL_POLICY_MANUAL;
	}
}

static void create_privkey_cb(void *opdata, const char *accountname, const char *protocol)
{
#pragma unused(opdata)
	@autoreleasepool {
		AIAccount *account = accountFromAccountID(accountname);
		if (!account)
			return;

		AIService *service = serviceFromServiceID(protocol);
		NSString *identifier = [NSString stringWithFormat:@"%@ (%@)", account.formattedUID, [service shortDescription]];
		[ESOTRPrivateKeyGenerationWindowController startedGeneratingForIdentifier:identifier];

		NSString *privkeyPath = [adiumOTREncryption privKeyPathForAccount:account];
		NSString *fullPath = [privkeyPath stringByExpandingTildeInPath];
		otrl_privkey_generate(otrg_plugin_userstate, fullPath.UTF8String, accountname, protocol);

		[ESOTRPrivateKeyGenerationWindowController finishedGeneratingForIdentifier:identifier];
	}
}

static int is_logged_in_cb(void *opdata, const char *accountname, const char *protocol, const char *recipient)
{
#pragma unused(opdata)
	@autoreleasepool {
		AIListContact *contact = contactFromInfo(accountname, protocol, recipient);
		return (contact != nil && contact.online) ? 1 : 0;
	}
}

static void inject_message_cb(void *opdata, const char *accountname, const char *protocol, const char *recipient,
							  const char *message)
{
#pragma unused(opdata)
	@autoreleasepool {
		if (!message || !recipient || !protocol || !accountname)
			return;

		AIChat *chat = chatForContext(otrl_context_find(otrg_plugin_userstate, recipient, accountname, protocol,
														OTRL_INSTAG_BEST, 0, NULL, NULL, NULL));
		if (!chat)
			return;

		NSString *msg = [NSString stringWithUTF8String:message];
		AIListContact *contact = [chat listObject];
		if (!contact)
			return;

		AIAccount *account = [chat account];
		if (!account)
			account = accountFromAccountID(accountname);
		if (!account)
			return;

		NSAttributedString *attrMsg = [[NSAttributedString alloc] initWithString:msg];
		AIContentMessage *contentMessage = [AIContentMessage messageInChat:chat
																withSource:contact
															   destination:account
																	  date:[NSDate date]
																   message:attrMsg
																 autoreply:NO];
		[adium.contentController sendContentObject:contentMessage];
	}
}

static void update_context_list_cb(void *opdata)
{
#pragma unused(opdata)
	@autoreleasepool {
		if (adiumOTREncryption) {
			[adiumOTREncryption prefsShouldUpdateFingerprintsList];
			[adiumOTREncryption prefsShouldUpdatePrivateKeyList];
		}
	}
}

static void new_fingerprint_cb(void *opdata, OtrlUserState us, const char *accountname, const char *protocol,
							   const char *username, unsigned char fingerprint[20])
{
#pragma unused(opdata, us)
	@autoreleasepool {
		AIAccount *account = accountFromAccountID(accountname);
		if (!account)
			return;

		char our_hash[OTRL_PRIVKEY_FPRINT_HUMAN_LEN];
		char their_hash[OTRL_PRIVKEY_FPRINT_HUMAN_LEN];

		otrl_privkey_hash_to_human(their_hash, fingerprint);

		(void)otrl_context_find(otrg_plugin_userstate, username, accountname, protocol, OTRL_INSTAG_BEST, 0, NULL, NULL,
								NULL);
		if (otrl_privkey_fingerprint(otrg_plugin_userstate, our_hash, accountname, protocol)) {
			/* our_hash is now filled in */
		} else {
			our_hash[0] = '\0';
		}

		NSString *who = [NSString stringWithUTF8String:username];

		NSDictionary *responseInfo = @{
			@"AIAccount" : account,
			@"who" : who,
			@"Their Fingerprint" : [NSString stringWithUTF8String:their_hash],
			@"Our Fingerprint" : [NSString stringWithUTF8String:our_hash],
		};

		dispatch_async(dispatch_get_main_queue(), ^{
			[ESOTRUnknownFingerprintController showUnknownFingerprintPromptWithResponseInfo:responseInfo];
		});
	}
}

static void write_fingerprints_cb(void *opdata)
{
#pragma unused(opdata)
	@autoreleasepool {
		NSString *fingerprintPath = [FINGERPRINT_PATH stringByExpandingTildeInPath];
		otrl_privkey_write_fingerprints(otrg_plugin_userstate, fingerprintPath.UTF8String);
	}
}

static void gone_secure_cb(void *opdata, ConnContext *context)
{
#pragma unused(opdata)
	@autoreleasepool {
		AIListContact *contact = contactForContext(context);

		update_security_details_for_chat(chatForContext(context));
		otrg_ui_update_keylist();

		if (contact) {
			NSString *message =
				[NSString stringWithFormat:AILocalizedStringFromTableInBundle(
											   @"Private conversation started with %@", nil,
											   [NSBundle bundleForClass:[AdiumOTREncryption class]], nil),
										   contact.displayName];
			[adiumOTREncryption showNotificationForContact:contact message:message];
		}
	}
}

static void gone_insecure_cb(void *opdata, ConnContext *context)
{
#pragma unused(opdata)
	@autoreleasepool {
		AIListContact *contact = contactForContext(context);

		update_security_details_for_chat(chatForContext(context));
		otrg_ui_update_keylist();

		if (contact) {
			NSString *message =
				[NSString stringWithFormat:AILocalizedStringFromTableInBundle(
											   @"Private conversation ended with %@", nil,
											   [NSBundle bundleForClass:[AdiumOTREncryption class]], nil),
										   contact.displayName];
			[adiumOTREncryption showNotificationForContact:contact message:message];
		}
	}
}

static void still_secure_cb(void *opdata, ConnContext *context, int is_reply)
{
#pragma unused(opdata, is_reply)
	@autoreleasepool {
		update_security_details_for_chat(chatForContext(context));
	}
}

static int max_message_size_cb(void *opdata, ConnContext *context)
{
#pragma unused(opdata, context)
	return 0;
}

static const char *account_display_name_cb(void *opdata, const char *accountname, const char *protocol)
{
#pragma unused(opdata, protocol)
	@autoreleasepool {
		AIAccount *account = accountFromAccountID(accountname);
		if (!account)
			return strdup("");

		NSString *name = account.formattedUID;
		return strdup(name.UTF8String);
	}
}

static void account_display_name_free_cb(void *opdata, const char *name)
{
#pragma unused(opdata)
	if (name)
		free((void *)name);
}

static void create_instag_cb(void *opdata, const char *accountname, const char *protocol)
{
#pragma unused(opdata, accountname, protocol)
	@autoreleasepool {
		NSString *instagPath = [INSTAG_PATH stringByExpandingTildeInPath];
		otrl_instag_generate(otrg_plugin_userstate, instagPath.UTF8String, accountname, protocol);
	}
}

// ======== OtrlMessageAppOps struct ========
static OtrlMessageAppOps otrOps = {
	.policy = policy_cb,
	.create_privkey = create_privkey_cb,
	.is_logged_in = is_logged_in_cb,
	.inject_message = inject_message_cb,
	.update_context_list = update_context_list_cb,
	.new_fingerprint = new_fingerprint_cb,
	.write_fingerprints = write_fingerprints_cb,
	.gone_secure = gone_secure_cb,
	.gone_insecure = gone_insecure_cb,
	.still_secure = still_secure_cb,
	.max_message_size = max_message_size_cb,
	.account_name = account_display_name_cb,
	.account_name_free = account_display_name_free_cb,
	.create_instag = create_instag_cb,
};

// -------------------------------------------------------------------------------------------------
#pragma mark C helper functions
// -------------------------------------------------------------------------------------------------

static void send_default_query_to_chat(AIChat *inChat)
{
	@autoreleasepool {
		AIAccount *account = [inChat account];
		AIListContact *contact = (AIListContact *)[inChat listObject];
		if (!account || !contact)
			return;

		NSString *username = contact.UID;
		NSString *accountName = [AdiumOTREncryption accountNameForOtrlAccount:account];

		otrl_message_sending(otrg_plugin_userstate, &otrOps, NULL, accountName.UTF8String,
							 account.service.serviceID.UTF8String, username.UTF8String, OTRL_INSTAG_BEST, "?OTRv2?",
							 NULL, NULL, OTRL_FRAGMENT_SEND_SKIP, NULL, NULL, NULL);
	}
}

static void disconnect_from_context(ConnContext *context)
{
	@autoreleasepool {
		if (!context)
			return;

		otrl_message_disconnect(otrg_plugin_userstate, &otrOps, NULL, context->accountname, context->protocol,
								context->username, OTRL_INSTAG_BEST);
	}
}

static void disconnect_from_chat(AIChat *inChat)
{
	@autoreleasepool {
		ConnContext *context = contextForChat(inChat);
		if (context) {
			disconnect_from_context(context);
		}
	}
}

static void update_security_details_for_chat(AIChat *inChat)
{
	@autoreleasepool {
		ConnContext *context = contextForChat(inChat);
		if (!context) {
			[adiumOTREncryption setSecurityDetails:nil forChat:inChat];
			return;
		}

		NSMutableDictionary *details = [NSMutableDictionary dictionary];

		char hash[OTRL_PRIVKEY_FPRINT_HUMAN_LEN];
		Fingerprint *fingerprint = context->active_fingerprint;

		if (fingerprint) {
			otrl_privkey_hash_to_human(hash, fingerprint->fingerprint);
			[details setValue:[NSString stringWithUTF8String:hash] forKey:@"Their Fingerprint"];

			char our_hash[OTRL_PRIVKEY_FPRINT_HUMAN_LEN];
			if (otrl_privkey_fingerprint(otrg_plugin_userstate, our_hash, context->accountname, context->protocol)) {
				[details setValue:[NSString stringWithUTF8String:our_hash] forKey:@"Our Fingerprint"];
			}

			if (fingerprint->trust && fingerprint->trust[0]) {
				[details setValue:@(YES) forKey:@"Verified"];
			}
		}

		[details setValue:@(context->msgstate == OTRL_MSGSTATE_ENCRYPTED) forKey:@"Secure"];

		unsigned char *sessionId = context->sessionid;
		size_t sessionIdLength = context->sessionid_len;
		if (sessionId && sessionIdLength > 0) {
			NSMutableString *tempID = [NSMutableString string];
			for (size_t i = 0; i < sessionIdLength; i++) {
				[tempID appendFormat:@"%02X", sessionId[i]];
				if ((i + 1) % 8 == 0) {
					[tempID appendString:@" "];
				}
			}
			[details setValue:tempID forKey:@"Session ID"];
		}

		[adiumOTREncryption setSecurityDetails:details forChat:inChat];
	}
}

static void display_otr_message(const char *accountname, const char *protocol, const char *username, NSString *message)
{
	@autoreleasepool {
		if (!message)
			return;

		ConnContext *context = otrl_context_find(otrg_plugin_userstate, username, accountname, protocol,
												 OTRL_INSTAG_BEST, 0, NULL, NULL, NULL);
		AIChat *chat = chatForContext(context);
		if (!chat)
			return;

		AIListContact *contact = contactForContext(context);
		AIAccount *account = accountFromAccountID(accountname);
		if (!contact || !account)
			return;

		NSAttributedString *attrMsg = [[NSAttributedString alloc] initWithString:message];
		AIContentMessage *contentMessage = [AIContentMessage messageInChat:chat
																withSource:contact
															   destination:account
																	  date:[NSDate date]
																   message:attrMsg
																 autoreply:NO];
		[adium.contentController sendContentObject:contentMessage];
	}
}

// -------------------------------------------------------------------------------------------------
#pragma mark Public C functions (called from other files)
// -------------------------------------------------------------------------------------------------

TrustLevel otrg_plugin_context_to_trust(ConnContext *context)
{
	if (!context)
		return TRUST_NOT_PRIVATE;

	switch (context->msgstate) {
	case OTRL_MSGSTATE_ENCRYPTED:
		if (context->active_fingerprint && context->active_fingerprint->trust &&
			context->active_fingerprint->trust[0]) {
			return TRUST_PRIVATE;
		}
		return TRUST_UNVERIFIED;
	case OTRL_MSGSTATE_FINISHED:
		return TRUST_FINISHED;
	default:
		return TRUST_NOT_PRIVATE;
	}
}

void otrg_plugin_create_privkey(const char *accountname, const char *protocol)
{
	create_privkey_cb(NULL, accountname, protocol);
}

void otrg_ui_forget_fingerprint(Fingerprint *fingerprint)
{
	@autoreleasepool {
		if (!fingerprint || !fingerprint->context)
			return;

		const char *username = fingerprint->context->username;
		const char *accountname = fingerprint->context->accountname;
		const char *protocol = fingerprint->context->protocol;

		ConnContext *context =
			otrl_context_find(otrg_plugin_userstate, username, accountname, protocol, 0, 0, NULL, NULL, NULL);

		otrl_context_forget_fingerprint(fingerprint, 0);
		otrg_plugin_write_fingerprints();
		otrg_ui_update_keylist();

		AIChat *chat = chatForContext(context);
		if (chat) {
			update_security_details_for_chat(chat);
		}
	}
}

void otrg_plugin_write_fingerprints(void)
{
	write_fingerprints_cb(NULL);
}

void otrg_ui_update_keylist(void)
{
	@autoreleasepool {
		if (adiumOTREncryption) {
			[adiumOTREncryption prefsShouldUpdateFingerprintsList];
			[adiumOTREncryption prefsShouldUpdatePrivateKeyList];
		}
	}
}

void otrg_ui_update_fingerprint(void)
{
	@autoreleasepool {
		if (adiumOTREncryption) {
			[adiumOTREncryption prefsShouldUpdateFingerprintsList];
		}
	}
}

OtrlUserState otrg_get_userstate(void)
{
	return otrg_plugin_userstate;
}

// ======== Private helper: policyForContact ========
static OtrlPolicy policyForContact(AIListContact *contact)
{
	@autoreleasepool {
		if (!contact)
			return OTRL_POLICY_MANUAL;

		NSNumber *policyValue = [[adium preferenceController] preferenceForKey:KEY_OTR_POLICY group:GROUP_OTR];
		return (policyValue ? [policyValue intValue] : OTRL_POLICY_MANUAL);
	}
}

// -------------------------------------------------------------------------------------------------
#pragma mark -
// -------------------------------------------------------------------------------------------------

@implementation AdiumOTREncryption

@synthesize OTRPersistenceFilePath;
@synthesize OTRWindowController;

#pragma mark OtrlUserState operations

+ (OtrlUserState)userState
{
	static OtrlUserState userState = NULL;
	if (!userState) {
		userState = otrl_userstate_create();
	}

	return userState;
}

+ (NSString *)accountNameForOtrlAccount:(AIAccount *)inAccount
{
	return [NSString stringWithFormat:@"%@.%@", inAccount.service.serviceID, inAccount.internalObjectID];
}

#pragma mark OTR operations

- (id)init
{
	if ((self = [super init])) {
		OTRPersistenceFilePath = nil;
		OTRWindowController = nil;
		adiumOTREncryption = self;
	}

	return self;
}

- (void)controllerDidLoad
{
	// Initialize the static user state for C callbacks
	otrg_plugin_userstate = [[self class] userState];

	// Read fingerprints, instance tags, and private keys
	[self readFingerprintsAndPrivkeys];

	// Observe login status changes
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(_accountConnected:)
												 name:ACCOUNT_CONNECTED
											   object:nil];

	// Observe chat-related notifications
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(updateSecurityDetails:)
												 name:Chat_ParticipatingListObjectsChanged
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(adiumWillTerminate:)
												 name:AIAppWillTerminateNotification
											   object:nil];

	// If any accounts are already connected, finish our initialization
	for (AIAccount *account in adium.accountController.accounts) {
		if (account.online) {
			[self _accountConnected:[NSNotification notificationWithName:ACCOUNT_CONNECTED object:account]];
		}
	}
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)_accountConnected:(NSNotification *)notification
{
	[self createOTRFiles];

	if (!OTRWindowController) {
		OTRWindowController = (ESOTRPreferences *)[ESOTRPreferences preferencePaneForPlugin:self];
	}
}

#pragma mark OTR integration

- (OtrlPolicy)otrPolicyForUsername:(NSString *)username accountName:(NSString *)accountName
{
	AIAccount *account = [adium.accountController
		accountWithInternalObjectID:[[accountName componentsSeparatedByString:@"."] lastObject]];
	AIListContact *contact = [adium.contactController contactWithService:account.service account:account UID:username];

	return [self otrPolicyForContact:contact];
}

- (OtrlPolicy)otrPolicyForContact:(AIListContact *)contact
{
	NSNumber *policyValue = [[adium preferenceController] preferenceForKey:KEY_OTR_POLICY group:GROUP_OTR];

	return (policyValue ? [policyValue intValue] : OTRL_POLICY_MANUAL);
}

- (void)handleTLVsForUsername:(NSString *)username accountName:(NSString *)accountName tlvs:(OtrlTLV *)tlvs
{
	AIAccount *account = [adium.accountController
		accountWithInternalObjectID:[[accountName componentsSeparatedByString:@"."] lastObject]];
	AIListContact *contact = [adium.contactController contactWithService:account.service account:account UID:username];

	if (tlvs && (tlvs->type == OTRL_TLV_DISCONNECTED)) {
		NSString *message = [NSString
			stringWithFormat:AILocalizedString(
								 @"%@ has terminated the private conversation with you. You should do the same.", nil),
							 contact.displayName];
		[self showNotificationForContact:contact message:message];

	} else if (tlvs && (tlvs->type == OTRL_TLV_SMP1 || tlvs->type == OTRL_TLV_SMP2 || tlvs->type == OTRL_TLV_SMP3 ||
						tlvs->type == OTRL_TLV_SMP4)) {
		if ((tlvs->type == OTRL_TLV_SMP1) && [self secretQuestion] != nil &&
			![[self secretQuestion] isEqualToString:@""]) {
			[ESOTRUnknownFingerprintController showSMPRequestForContact:contact
															   question:[self secretQuestion]
																 plugin:self];
		} else if (tlvs->type == OTRL_TLV_SMP1) {
			[ESOTRUnknownFingerprintController showSMPRequestForContact:contact question:nil plugin:self];
		}

	} else if (tlvs && (tlvs->type == OTRL_TLV_SMP1Q)) {
		OtrlTLV *tlv = tlvs;
		uint32_t questionLen = 0;
		if (tlv->len >= 4) {
			memcpy(&questionLen, tlv->data, 4);
		}
		questionLen = ntohl(questionLen);
		if (questionLen > 0 && questionLen + 4 < tlv->len) {
			char *question = malloc(questionLen + 1);
			memcpy(question, tlv->data + 4, questionLen);
			question[questionLen] = '\0';

			char *smpMessage = malloc(tlv->len - questionLen - 4);
			memcpy(smpMessage, tlv->data + 4 + questionLen, tlv->len - questionLen - 4);

			[ESOTRUnknownFingerprintController showSMPRequestForContact:contact
															   question:[NSString stringWithUTF8String:question]
																 plugin:self
															 smpMessage:smpMessage
																 length:(tlv->len - questionLen - 4)];

			free(smpMessage);
			free(question);
		} else {
			char *smpMessage = malloc(tlv->len - 4);
			memcpy(smpMessage, tlv->data + 4, tlv->len - 4);

			[ESOTRUnknownFingerprintController showSMPRequestForContact:contact
															   question:nil
																 plugin:self
															 smpMessage:smpMessage
																 length:(tlv->len - 4)];

			free(smpMessage);
		}
	}
}

- (void)createOTRFiles
{
	NSFileManager *defaultFileManager = [NSFileManager defaultManager];

	NSString *OTRDir = [[adium.loginController userDirectory] stringByAppendingPathComponent:@"/OTR"];
	BOOL isDir = NO;
	if (![defaultFileManager fileExistsAtPath:OTRDir isDirectory:&isDir]) {
		[defaultFileManager createDirectoryAtPath:OTRDir withIntermediateDirectories:YES attributes:nil error:NULL];
	}

	NSString *privkeyDir = [PRIVKEY_PATH stringByExpandingTildeInPath];
	if (![defaultFileManager fileExistsAtPath:privkeyDir isDirectory:&isDir]) {
		[defaultFileManager createDirectoryAtPath:privkeyDir withIntermediateDirectories:YES attributes:nil error:NULL];
	}

	NSString *fingerprintPath = [FINGERPRINT_PATH stringByExpandingTildeInPath];
	if (![defaultFileManager fileExistsAtPath:fingerprintPath]) {
		[defaultFileManager createFileAtPath:fingerprintPath
									contents:[@"" dataUsingEncoding:NSUTF8StringEncoding]
								  attributes:nil];
	}

	NSString *instagPath = [INSTAG_PATH stringByExpandingTildeInPath];
	if (![defaultFileManager fileExistsAtPath:instagPath]) {
		[defaultFileManager createFileAtPath:instagPath
									contents:[@"" dataUsingEncoding:NSUTF8StringEncoding]
								  attributes:nil];
	}
}

- (void)requireOtrForChat:(AIChat *)chat
{
	AIAccount *account = [chat account];

	// Get or create private key if needed
	if (![self privateKeyExistsForAccount:account]) {
		[self generatePrivateKeyForAccount:account];
	}

	ConnContext *context = contextForChat(chat);
	if (context && context->msgstate == OTRL_MSGSTATE_ENCRYPTED) {
		// Already encrypted, do nothing
		return;
	}

	// Send OTR query message to initiate
	send_default_query_to_chat(chat);
}

#pragma mark Sending and Receiving

- (NSString *)decodeMessage:(NSString *)message
				   fromUser:(NSString *)username
			 forAccountName:(NSString *)accountName
			accountProtocol:(NSString *)accountProtocol
					  isOTR:(BOOL *)outIsOTR
{
	NSString *decodedMessage = nil;
	char *newMessage = NULL;
	OtrlTLV *tlvs = NULL;

	OtrlUserState userState = [[self class] userState];
	int ret = otrl_message_receiving(userState, &otrOps,
									 NULL,                       // opdata
									 username.UTF8String,        // accountname
									 accountName.UTF8String,     // protocol
									 accountProtocol.UTF8String, // sender
									 message.UTF8String,         // message
									 &newMessage,                // newmessagep
									 &tlvs,                      // tlvsp
									 NULL,                       // contextp
									 NULL,                       // add_appdata
									 NULL);                      // data

	if (ret == 1) {
		// OTR internal protocol message — suppress from display
		[self handleTLVsForUsername:username accountName:accountName tlvs:tlvs];
		otrl_tlv_free(tlvs);

		if (outIsOTR)
			*outIsOTR = YES;
		return nil;
	}

	if (ret && ret != OTRL_ERRCODE_ENCRYPTION_ERROR) {
		AILogWithSignature(@"libotr error when decoding message: %d", ret);
	}

	[self handleTLVsForUsername:username accountName:accountName tlvs:tlvs];
	otrl_tlv_free(tlvs);

	if (!ret && newMessage == NULL) {
		// Not an OTR message
		if (outIsOTR)
			*outIsOTR = NO;
		return nil;
	}

	// OTR-related message
	if (outIsOTR)
		*outIsOTR = YES;

	if (newMessage) {
		if (strcmp(newMessage, "?OTR") == 0 || strncmp(newMessage, "?OTRv", 5) == 0) {
			// OTR Error
			free(newMessage);
			newMessage = NULL;
		} else {
			decodedMessage = [NSString stringWithUTF8String:newMessage];
		}
	}

	if (newMessage) {
		free(newMessage);
	}

	return decodedMessage;
}

// AdiumMessageEncryptor protocol: called by the content controller
- (NSString *)decryptIncomingMessage:(NSString *)inString
						 fromContact:(AIListContact *)inListContact
						   onAccount:(AIAccount *)inAccount
{
	return [self decodeMessage:inString
					  fromUser:inListContact.UID
				forAccountName:[[self class] accountNameForOtrlAccount:inAccount]
			   accountProtocol:inAccount.service.serviceID
						 isOTR:NULL];
}

- (NSString *)encodeMessage:(NSString *)message
				forUsername:(NSString *)username
				accountName:(NSString *)accountName
			accountProtocol:(NSString *)accountProtocol
{
	NSString *encodedMessage = nil;
	gcry_error_t err;

	char *newMessage = NULL;

	OtrlUserState userState = [[self class] userState];

	err = otrl_message_sending(userState, &otrOps,
							   NULL,                       // opdata
							   username.UTF8String,        // accountname
							   accountName.UTF8String,     // protocol
							   accountProtocol.UTF8String, // recipient
							   OTRL_INSTAG_BEST, message.UTF8String,
							   NULL,        // tlvs
							   &newMessage, // messagep
							   OTRL_FRAGMENT_SEND_SKIP,
							   NULL,  // contextp
							   NULL,  // add_appdata
							   NULL); // data

	if (!err && newMessage) {
		encodedMessage = [NSString stringWithUTF8String:newMessage];
		free(newMessage);
	}

	return encodedMessage;
}

#pragma mark OTR Session Management

- (void)willSendContentMessage:(AIContentMessage *)inContentMessage
{
	AIChat *chat = [inContentMessage chat];
	if (!chat)
		return;

	ConnContext *context = contextForChat(chat);
	if (!context || context->msgstate != OTRL_MSGSTATE_ENCRYPTED) {
		return;
	}

	AIAccount *account = [chat account];
	AIListContact *contact = (AIListContact *)[chat listObject];
	if (!account || !contact)
		return;

	NSString *plaintext = [inContentMessage messageString];
	NSString *accountName = [[self class] accountNameForOtrlAccount:account];
	NSString *protocol = account.service.serviceID;
	NSString *username = contact.UID;

	gcry_error_t err;
	char *encryptedMessage = NULL;

	err = otrl_message_sending(otrg_plugin_userstate, &otrOps, NULL, username.UTF8String, accountName.UTF8String,
							   protocol.UTF8String, OTRL_INSTAG_BEST, plaintext.UTF8String, NULL, &encryptedMessage,
							   OTRL_FRAGMENT_SEND_ALL_BUT_LAST, NULL, NULL, NULL);

	if (!err && encryptedMessage) {
		NSString *encryptedString = [NSString stringWithUTF8String:encryptedMessage];

		// Replace the plaintext with the encrypted message
		NSAttributedString *attrMsg = [[NSAttributedString alloc] initWithString:encryptedString];
		AIContentMessage *encryptedContent = [AIContentMessage messageInChat:chat
																  withSource:[chat listObject]
																 destination:account
																		date:[NSDate date]
																	 message:attrMsg
																   autoreply:NO];
		[adium.contentController sendContentObject:encryptedContent];

		// Don't send the original plaintext
		inContentMessage.sendContent = NO;

		free(encryptedMessage);
	}
}

- (void)requestSecureOTRMessaging:(BOOL)inSecureMessaging inChat:(AIChat *)inChat
{
	if (inSecureMessaging) {
		send_default_query_to_chat(inChat);
	} else {
		disconnect_from_chat(inChat);
	}
}

- (void)promptToVerifyEncryptionIdentityInChat:(AIChat *)inChat
{
	ConnContext *context = contextForChat(inChat);
	if (!context)
		return;

	AIAccount *account = [inChat account];
	if (!account)
		return;

	char our_hash[OTRL_PRIVKEY_FPRINT_HUMAN_LEN] = "";
	char their_hash[OTRL_PRIVKEY_FPRINT_HUMAN_LEN] = "";

	Fingerprint *fingerprint = context->active_fingerprint;
	if (fingerprint) {
		otrl_privkey_hash_to_human(their_hash, fingerprint->fingerprint);
	}

	otrl_privkey_fingerprint(otrg_plugin_userstate, our_hash, context->accountname, context->protocol);

	AIListContact *contact = (AIListContact *)[inChat listObject];
	NSString *who = contact ? contact.UID : [NSString stringWithUTF8String:context->username];

	NSDictionary *responseInfo = @{
		@"AIAccount" : account,
		@"who" : who,
		@"Their Fingerprint" : [NSString stringWithUTF8String:their_hash],
		@"Our Fingerprint" : [NSString stringWithUTF8String:our_hash],
	};

	[ESOTRUnknownFingerprintController showVerifyFingerprintPromptWithResponseInfo:responseInfo];
}

- (void)verifyUnknownFingerprint:(NSValue *)contextValue
{
	ConnContext *context = [contextValue pointerValue];
	if (!context)
		return;

	AIAccount *account = accountFromAccountID(context->accountname);

	char our_hash[OTRL_PRIVKEY_FPRINT_HUMAN_LEN] = "";
	char their_hash[OTRL_PRIVKEY_FPRINT_HUMAN_LEN] = "";

	Fingerprint *fingerprint = context->active_fingerprint;
	if (fingerprint) {
		otrl_privkey_hash_to_human(their_hash, fingerprint->fingerprint);
	}

	otrl_privkey_fingerprint(otrg_plugin_userstate, our_hash, context->accountname, context->protocol);

	NSString *who = [NSString stringWithUTF8String:context->username];

	NSDictionary *responseInfo = @{
		@"AIAccount" : (account ? account : [NSNull null]),
		@"who" : who,
		@"Their Fingerprint" : [NSString stringWithUTF8String:their_hash],
		@"Our Fingerprint" : [NSString stringWithUTF8String:our_hash],
	};

	[ESOTRUnknownFingerprintController showUnknownFingerprintPromptWithResponseInfo:responseInfo];
}

- (void)disconnectFromUsername:(NSString *)username
				   accountName:(NSString *)accountName
			   accountProtocol:(NSString *)accountProtocol
{
	OtrlUserState userState = [[self class] userState];
	otrl_message_disconnect(userState, &otrOps, NULL, username.UTF8String, accountName.UTF8String,
							accountProtocol.UTF8String, OTRL_INSTAG_BEST);
}

- (void)disconnectFromAccount:(AIAccount *)inAccount
{
	NSEnumerator *enumerator;
	NSString *username;

	enumerator = [[[adium.contactController allContacts] valueForKey:@"UID"] objectEnumerator];

	OtrlUserState userState = [[self class] userState];
	while ((username = [enumerator nextObject])) {
		otrl_message_disconnect(userState, &otrOps, NULL, username.UTF8String,
								[[self class] accountNameForOtrlAccount:inAccount].UTF8String,
								inAccount.service.serviceID.UTF8String, OTRL_INSTAG_BEST);
	}
}

- (void)initiateSMPForContact:(AIListContact *)contact
{
	AIAccount *account = contact.account;

	OtrlUserState userState = [[self class] userState];
	ConnContext *context = otrl_context_find(
		userState, contact.UID.UTF8String, [[self class] accountNameForOtrlAccount:account].UTF8String,
		account.service.serviceID.UTF8String, OTRL_INSTAG_BEST, 0, NULL, NULL, NULL);
	if (context) {
		const char *question = [self secretQuestion].UTF8String;
		otrl_message_initiate_smp(userState, &otrOps, NULL, context, (unsigned const char *)question, strlen(question));
	}
}

- (void)respondSMPForContact:(AIListContact *)contact
{
	AIAccount *account = contact.account;

	OtrlUserState userState = [[self class] userState];
	ConnContext *context = otrl_context_find(
		userState, contact.UID.UTF8String, [[self class] accountNameForOtrlAccount:account].UTF8String,
		account.service.serviceID.UTF8String, OTRL_INSTAG_BEST, 0, NULL, NULL, NULL);
	if (context) {
		if ([self secretQuestion] && ![[self secretQuestion] isEqualToString:@""]) {
			otrl_message_respond_smp(userState, &otrOps, NULL, context,
									 (unsigned const char *)[self secretAnswer].UTF8String,
									 strlen([self secretAnswer].UTF8String));
		} else {
			otrl_message_respond_smp(userState, &otrOps, NULL, context,
									 (unsigned const char *)[self secretQuestion].UTF8String,
									 strlen([self secretQuestion].UTF8String));
		}
	}
}

- (void)abortSMPForContact:(AIListContact *)contact
{
	AIAccount *account = contact.account;

	OtrlUserState userState = [[self class] userState];
	ConnContext *context = otrl_context_find(
		userState, contact.UID.UTF8String, [[self class] accountNameForOtrlAccount:account].UTF8String,
		account.service.serviceID.UTF8String, OTRL_INSTAG_BEST, 0, NULL, NULL, NULL);
	if (context) {
		otrl_message_abort_smp(userState, &otrOps, NULL, context);
	}
}

#pragma mark OTR fingerprint acceptance

- (void)acceptFingerprintForContact:(AIListContact *)contact
{
	AIAccount *account = contact.account;

	[self trustFingerprint:[self activeFingerprintForContact:contact]
			   forUsername:contact.UID
			   accountName:[[self class] accountNameForOtrlAccount:account]];
}

- (void)trustFingerprint:(NSString *)fingerprint forUsername:(NSString *)username accountName:(NSString *)accountName
{
	AIAccount *account = [adium.accountController
		accountWithInternalObjectID:[[accountName componentsSeparatedByString:@"."] lastObject]];

	OtrlUserState userState = [[self class] userState];
	ConnContext *context =
		otrl_context_find(userState, username.UTF8String, accountName.UTF8String, account.service.serviceID.UTF8String,
						  OTRL_INSTAG_BEST, 0, NULL, NULL, NULL);
	if (context && context->active_fingerprint) {
		if (fingerprint &&
			[[self activeFingerprintForContact:[adium.contactController contactWithService:account.service
																				   account:account
																					   UID:username]]
				isEqualToString:fingerprint]) {
			otrl_context_set_trust(context->active_fingerprint, "verified");
		}
	}
}

- (NSString *)activeFingerprintForContact:(AIListContact *)inContact
{
	AIAccount *account = inContact.account;

	OtrlUserState userState = [[self class] userState];
	ConnContext *context = otrl_context_find(
		userState, inContact.UID.UTF8String, [[self class] accountNameForOtrlAccount:account].UTF8String,
		account.service.serviceID.UTF8String, OTRL_INSTAG_BEST, 0, NULL, NULL, NULL);
	if (context) {
		Fingerprint *fingerprint = context->active_fingerprint;
		if (fingerprint) {
			char hash[OTRL_PRIVKEY_FPRINT_HUMAN_LEN];
			otrl_privkey_hash_to_human(hash, fingerprint->fingerprint);
			NSString *result = [NSString stringWithUTF8String:hash];
			return result;
		}
	}

	return nil;
}

- (NSString *)fingerprintForUsername:(NSString *)username
						 accountName:(NSString *)accountName
					 accountProtocol:(NSString *)accountProtocol
{
	OtrlUserState userState = [[self class] userState];
	ConnContext *context = otrl_context_find(userState, username.UTF8String, accountName.UTF8String,
											 accountProtocol.UTF8String, OTRL_INSTAG_BEST, 0, NULL, NULL, NULL);
	if (context) {
		Fingerprint *fingerprint = context->active_fingerprint;
		if (fingerprint) {
			char hash[OTRL_PRIVKEY_FPRINT_HUMAN_LEN];
			otrl_privkey_hash_to_human(hash, fingerprint->fingerprint);
			return [NSString stringWithUTF8String:hash];
		}
	}

	return nil;
}

- (BOOL)isContactVerified:(AIListContact *)contact
{
	AIAccount *account = contact.account;

	OtrlUserState userState = [[self class] userState];
	ConnContext *context = otrl_context_find(
		userState, contact.UID.UTF8String, [[self class] accountNameForOtrlAccount:account].UTF8String,
		account.service.serviceID.UTF8String, OTRL_INSTAG_BEST, 0, NULL, NULL, NULL);
	if (context && context->active_fingerprint) {
		return (context->active_fingerprint->trust && context->active_fingerprint->trust[0]);
	}

	return NO;
}

- (BOOL)isOTRForContact:(AIListContact *)contact
{
	AIAccount *account = contact.account;

	OtrlUserState userState = [[self class] userState];
	ConnContext *context = otrl_context_find(
		userState, contact.UID.UTF8String, [[self class] accountNameForOtrlAccount:account].UTF8String,
		contact.service.serviceID.UTF8String, OTRL_INSTAG_BEST, 0, NULL, NULL, NULL);

	return (context && context->msgstate == OTRL_MSGSTATE_ENCRYPTED);
}

- (NSString *)sessionIDForContact:(AIListContact *)contact
{
	AIAccount *account = contact.account;

	OtrlUserState userState = [[self class] userState];
	ConnContext *context = otrl_context_find(
		userState, contact.UID.UTF8String, [[self class] accountNameForOtrlAccount:account].UTF8String,
		contact.service.serviceID.UTF8String, OTRL_INSTAG_BEST, 0, NULL, NULL, NULL);

	if (context) {
		unsigned char *sessionId = context->sessionid;
		size_t sessionIdLength = context->sessionid_len;

		if (sessionId && sessionIdLength > 0) {
			NSMutableString *tempID = [NSMutableString string];
			for (size_t i = 0; i < sessionIdLength; i++) {
				[tempID appendFormat:@"%02X", sessionId[i]];
				if ((i + 1) % 8 == 0) {
					[tempID appendString:@" "];
				}
			}

			return tempID;
		}
	}

	return nil;
}

- (BOOL)isOTRavailableForContact:(AIListContact *)contact
{
	AIAccount *account = contact.account;

	OtrlUserState userState = [[self class] userState];
	ConnContext *context = otrl_context_find(
		userState, contact.UID.UTF8String, [[self class] accountNameForOtrlAccount:account].UTF8String,
		contact.service.serviceID.UTF8String, OTRL_INSTAG_BEST, 0, NULL, NULL, NULL);

	return (context != NULL);
}

- (BOOL)isOTRRequiredForContact:(AIListContact *)contact
{
	AIAccount *account = contact.account;

	OtrlUserState userState = [[self class] userState];
	ConnContext *context = otrl_context_find(
		userState, contact.UID.UTF8String, [[self class] accountNameForOtrlAccount:account].UTF8String,
		contact.service.serviceID.UTF8String, OTRL_INSTAG_BEST, 0, NULL, NULL, NULL);

	return ((context != NULL) && [self otrPolicyForContact:contact] == OTRL_POLICY_ALWAYS);
}

#pragma mark OTR Window

- (void)showOTRPreferenceWindow
{
	[[adium preferenceController] showPreferenceWindow:nil];
}

- (void)showOTRNotificationForContact:(AIListContact *)inContact
{
	NSString *message = [NSString
		stringWithFormat:AILocalizedString(@"Private conversation started with %@", nil), inContact.displayName];

	[self showNotificationForContact:inContact message:message];
}

- (void)showOTREndedNotificationForContact:(AIListContact *)inContact
{
	NSString *message = [NSString
		stringWithFormat:AILocalizedString(@"Private conversation ended with %@", nil), inContact.displayName];
	[self showNotificationForContact:inContact message:message];
}

- (void)showNotificationForContact:(AIListContact *)inContact message:(NSString *)message
{
	[[adium contactAlertsController] generateEvent:@"OTRNotification"
									 forListObject:inContact
										  userInfo:[NSDictionary dictionaryWithObject:message forKey:@"message"]
					  previouslyPerformedActionIDs:nil];
}

#pragma mark OTR Key generation

- (void)generatePrivateKeyForAccount:(AIAccount *)inAccount
{
	if ([self privateKeyExistsForAccount:inAccount]) {
		NSAlert *privateKeyExistsAlert = [[NSAlert alloc] init];
		privateKeyExistsAlert.messageText = AILocalizedString(@"Private key already exists", nil);
		privateKeyExistsAlert.informativeText =
			AILocalizedString(@"You must remove the old private key using the OTR preferences "
							  @"before generating a new one.",
							  nil);
		[privateKeyExistsAlert addButtonWithTitle:AILocalizedString(@"OK", nil)];
		[privateKeyExistsAlert runModal];
		return;
	}

	NSString *privkeyFilename = [[self privKeyPathForAccount:inAccount] stringByExpandingTildeInPath];

	OtrlUserState userState = [[self class] userState];

	gcry_error_t err = otrl_privkey_generate(userState, [privkeyFilename UTF8String],
											 [[self class] accountNameForOtrlAccount:inAccount].UTF8String,
											 inAccount.service.serviceID.UTF8String);
	if (err) {
		AILogWithSignature(@"libotr error generating private key: %@",
						   [NSString stringWithUTF8String:gcry_strerror(err)]);
	}

	[self upgradeV1Key:privkeyFilename
		   accountName:[[self class] accountNameForOtrlAccount:inAccount]
			accountUID:inAccount.UID];
}

- (void)removePrivateKeyForAccount:(AIAccount *)inAccount
{
	NSString *privkeyFilename = [[self privKeyPathForAccount:inAccount] stringByExpandingTildeInPath];
	NSString *oldPrivkeyFilename = [[self oldPrivKeyPathForAccount:inAccount] stringByExpandingTildeInPath];
	NSFileManager *defaultFileManager = [NSFileManager defaultManager];

	if ([defaultFileManager fileExistsAtPath:privkeyFilename]) {
		[defaultFileManager removeItemAtPath:privkeyFilename error:NULL];
	}

	if ([defaultFileManager fileExistsAtPath:oldPrivkeyFilename]) {
		[defaultFileManager removeItemAtPath:oldPrivkeyFilename error:NULL];
	}
}

- (BOOL)privateKeyExistsForAccount:(AIAccount *)inAccount
{
	NSFileManager *defaultFileManager = [NSFileManager defaultManager];
	NSString *privkeyFilename = [[self privKeyPathForAccount:inAccount] stringByExpandingTildeInPath];

	return [defaultFileManager fileExistsAtPath:privkeyFilename];
}

#pragma mark OTR Key files

- (NSString *)privKeyPathForAccount:(AIAccount *)inAccount
{
	return [PRIVKEY_PATH
		stringByAppendingPathComponent:[NSString
										   stringWithFormat:@"%@.%@.key",
															[[self class] accountNameForOtrlAccount:inAccount],
															[inAccount.UID stringByReplacingOccurrencesOfString:@"/"
																									 withString:@"_"]]];
}

- (NSString *)oldPrivKeyPathForAccount:(AIAccount *)inAccount
{
	return [PRIVKEY_PATH
		stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.key",
																  [[self class] accountNameForOtrlAccount:inAccount]]];
}

- (NSString *)pathForEncryptedMessage:(NSString *)messageExtension
{
	return [[adium.loginController userDirectory]
		stringByAppendingPathComponent:[NSString stringWithFormat:@"/OTR/%@", messageExtension]];
}

#pragma mark OTR Private Key Passphrases

- (BOOL)passphraseNeededForAccount:(AIAccount *)inAccount
{
	// The shipped libotr does not support encrypted private keys
	return NO;
}

- (void)readPrivateKeyForAccount:(AIAccount *)inAccount
{
	NSString *privkeyFilename = [[self privKeyPathForAccount:inAccount] stringByExpandingTildeInPath];

	OtrlUserState userState = [[self class] userState];

	if (!otrl_privkey_read(userState, privkeyFilename.UTF8String)) {
		_keyReadSuccess = YES;
	}

	if (!_keyReadSuccess) {
		NSString *oldPrivkeyFilename = [[self oldPrivKeyPathForAccount:inAccount] stringByExpandingTildeInPath];
		if ([oldPrivkeyFilename length] > 0) {
			if (!otrl_privkey_read(userState, oldPrivkeyFilename.UTF8String)) {
				_keyReadSuccess = YES;
			}
		}
	}
}

- (BOOL)readFingerprintsAndPrivkeys
{
	NSString *fingerprintPath = [FINGERPRINT_PATH stringByExpandingTildeInPath];
	NSString *instagPath = [INSTAG_PATH stringByExpandingTildeInPath];

	OtrlUserState userState = [[self class] userState];

	otrl_privkey_read_fingerprints(userState, [fingerprintPath UTF8String], NULL, NULL);
	otrl_instag_read(userState, [instagPath UTF8String]);

	for (AIAccount *account in adium.accountController.accounts) {
		if (account.online) {
			[self readPrivateKeyForAccount:account];
		}
	}

	return YES;
}

- (void)setPassphrase:(NSString *)passphrase forAccount:(AIAccount *)inAccount
{
	if (passphrase && [passphrase length] > 0) {
		[[adium preferenceController]
			setPreference:passphrase
				   forKey:KEY_OTR_PASSPHRASE
					group:[NSString stringWithFormat:GROUP_OTR_PASSPHRASE, [inAccount internalObjectID]]];
	}
}

- (NSString *)passphraseForAccount:(AIAccount *)inAccount
{
	NSString *passphrase = [[adium preferenceController]
		preferenceForKey:KEY_OTR_PASSPHRASE
				   group:[NSString stringWithFormat:GROUP_OTR_PASSPHRASE, [inAccount internalObjectID]]];
	return passphrase;
}

- (void)emptyPassphraseForAccount:(AIAccount *)inAccount
{
	[[adium preferenceController]
		setPreference:nil
			   forKey:KEY_OTR_PASSPHRASE
				group:[NSString stringWithFormat:GROUP_OTR_PASSPHRASE, [inAccount internalObjectID]]];
}

#pragma mark OTR Upgrading

- (void)upgradeV1Key:(NSString *)privkeyFilenameNew
		 accountName:(NSString *)newAccountName
		  accountUID:(NSString *)newAccountUID
{
#pragma unused(newAccountUID)
	NSString *privkeyFilenameV1 = [[self oldPrivKeyPathForAccount:nil] stringByExpandingTildeInPath];
	NSString *resolvedNewPath = [privkeyFilenameNew stringByExpandingTildeInPath];

	if (![[NSFileManager defaultManager] fileExistsAtPath:resolvedNewPath] &&
		[[NSFileManager defaultManager] fileExistsAtPath:privkeyFilenameV1]) {
		OtrlUserState userState = [[self class] userState];
		FILE *privKeyFileV1 = fopen([privkeyFilenameV1 UTF8String], "r");
		if (privKeyFileV1) {
			otrl_privkey_read_FILEp(userState, privKeyFileV1);
			fclose(privKeyFileV1);

			// Copy the V1 key file to the new path since libotr has no write function
			[[NSFileManager defaultManager] copyItemAtPath:privkeyFilenameV1 toPath:resolvedNewPath error:NULL];
		}
	}
}

#pragma mark Config

- (NSString *)secretQuestion
{
	return [[adium preferenceController] preferenceForKey:KEY_OTR_SMP_SECRETQUESTION group:GROUP_OTR];
}

- (NSString *)secretAnswer
{
	return [[adium preferenceController] preferenceForKey:KEY_OTR_SMP_SECRETANSWER group:GROUP_OTR];
}

- (void)createInstag:(OtrlUserState)userState
{
	NSString *instagPath = [INSTAG_PATH stringByExpandingTildeInPath];
	otrl_instag_generate(userState, instagPath.UTF8String, "", "");
}

#pragma mark Preferences

- (void)prefsShouldUpdatePrivateKeyList
{
	if (OTRWindowController) {
		[OTRWindowController updatePrivateKeyList];
	}
}

- (void)prefsShouldUpdateFingerprintsList
{
	if (OTRWindowController) {
		[OTRWindowController updateFingerprintsList];
	}
}

#pragma mark Chat Security Details

- (void)setSecurityDetails:(NSDictionary *)securityDetailsDict forChat:(AIChat *)inChat
{
	if (securityDetailsDict) {
		[inChat setSecurityDetails:securityDetailsDict];
	} else {
		[inChat setSecurityDetails:nil];
	}
}

- (void)updateSecurityDetails:(NSNotification *)inNotification
{
	AIChat *chat = [inNotification object];
	if (chat) {
		update_security_details_for_chat(chat);
	}
}

- (void)adiumWillTerminate:(NSNotification *)inNotification
{
#pragma unused(inNotification)
	@autoreleasepool {
		ConnContext *context = otrg_plugin_userstate->context_root;
		while (context) {
			if (context->msgstate == OTRL_MSGSTATE_ENCRYPTED) {
				disconnect_from_context(context);
			}
			context = context->next;
		}
	}
}

#pragma mark OTR Messages

- (NSString *)localizedOTRMessage:(NSString *)message
					 withUsername:(NSString *)username
		   isWorthOpeningANewChat:(BOOL *)isWorthOpeningANewChat
{
	if ([message isEqualToString:@"encrypted"]) {
		return [NSString stringWithFormat:AILocalizedString(@"OTR encrypted session started with %@.", nil), username];

	} else if ([message isEqualToString:@"finished"]) {
		if (isWorthOpeningANewChat)
			*isWorthOpeningANewChat = YES;
		return [NSString
			stringWithFormat:AILocalizedString(
								 @"%@ has ended his/her private conversation with you; you should do the same.", nil),
							 username];

	} else if ([message isEqualToString:@"connection closed"]) {
		return [NSString
			stringWithFormat:AILocalizedString(@"%@ has closed his/her private connection with you.", nil), username];

	} else if ([message isEqualToString:@"unencrypted"]) {
		return [NSString
			stringWithFormat:AILocalizedString(@"The private conversation with %@ was interrupted.", nil), username];

	} else if ([message isEqualToString:@"SMP started"]) {
		return [NSString stringWithFormat:AILocalizedString(@"SMP authentication started with %@.", nil), username];

	} else if ([message isEqualToString:@"SMP finished"]) {
		return [NSString stringWithFormat:AILocalizedString(@"SMP authentication finished with %@.", nil), username];

	} else if ([message isEqualToString:@"SMP failed"]) {
		return [NSString stringWithFormat:AILocalizedString(@"SMP authentication failed with %@.", nil), username];

	} else {
		return
			[NSString stringWithFormat:AILocalizedString(@"Unknown OTR message: %@ from %@.", nil), message, username];
	}
}

- (void)notifyWithTitle:(NSString *)title primary:(NSString *)primary secondary:(NSString *)secondary
{
#pragma unused(title, secondary)
	[[adium contactAlertsController] generateEvent:@"OTRNotification"
									 forListObject:nil
										  userInfo:[NSDictionary dictionaryWithObject:primary forKey:@"message"]
					  previouslyPerformedActionIDs:nil];
}

@end
