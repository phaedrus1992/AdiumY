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
#import <AdiumY/AIOTRIdentityMigration.h>
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
- (void)migrateStoredIdentities;
- (void)migrateStoreAtPath:(NSString *)storePath
			withMigrations:(NSArray<AIOTRIdentityMigration *> *)migrations
				  rewriter:(NSString *(*)(NSString *, NSArray<AIOTRIdentityMigration *> *, NSUInteger *))rewriter;
- (void)migratePrivateKeyFileForAccount:(AIAccount *)inAccount migration:(AIOTRIdentityMigration *)migration;
- (void)removeLegacyKeyFileAtPath:(NSString *)legacyPath
			whenCurrentFileAtPath:(NSString *)currentPath
				  holdsKeyForName:(NSString *)accountName
						 protocol:(NSString *)protocol;
- (BOOL)privateKeyFileAtPath:(NSString *)path
			 holdsKeyForName:(NSString *)accountName
					protocol:(NSString *)protocol
					   error:(gcry_error_t *)outError;

// Methods called from C functions (need forward declaration before @implementation)
+ (NSString *)accountNameForOtrlAccount:(AIAccount *)inAccount;
- (void)initializeOTR;
- (NSString *)privKeyPathForAccount:(AIAccount *)inAccount;
- (void)showNotificationForContact:(AIListContact *)inContact message:(NSString *)message;
@end

// Static globals for C callbacks
static OtrlUserState otrg_plugin_userstate = NULL;
static AdiumOTREncryption *adiumOTREncryption = nil;

// The user state exists once per run, and any entry point can be the first to
// run. A normal launch creates it from the app-finished-loading notification,
// but a plugin installed at runtime loads after that notification and would
// never see it (#410), so every entry point goes through this accessor.
static OtrlUserState otrg_userstate(void)
{
	if (otrg_plugin_userstate == NULL && adiumOTREncryption != nil) {
		// initializeOTR reads the key files, which call back into this
		// accessor; the flag keeps a failed creation from re-entering it.
		static BOOL initializing = NO;
		if (!initializing) {
			initializing = YES;
			[adiumOTREncryption initializeOTR];
			initializing = NO;
		}
	}

	return otrg_plugin_userstate;
}

// The state fails to create only when the allocator does, but an operation
// that skips on a NULL state otherwise leaves no trace. One line per run names
// the first skipped operation.
static void logMissingUserState(NSString *operation)
{
	static BOOL reported = NO;
	if (!reported) {
		reported = YES;
		AILogWithSignature(@"No OTR user state; skipped %@. OTR stays off until the state exists.", operation);
	}
}

// The single place that builds a context lookup. The vendored libotr's
// otrl_context_find takes the peer first, then the account strings:
// (us, user, accountname, protocol, instag, ...). accountname is the account's
// internalObjectID and protocol is the service's serviceCodeUniqueID, the
// strings upstream stores (#403). A NULL state returns no context: the caller
// must skip OTR rather than let libotr dereference it.
static ConnContext *contextForAccountAndContact(AIAccount *account, AIListContact *contact)
{
	@autoreleasepool {
		if (!account || !contact)
			return NULL;

		OtrlUserState userState = otrg_userstate();
		if (userState == NULL) {
			logMissingUserState(@"the context lookup");
			return NULL;
		}

		return otrl_context_find(
			userState, [contact.UID UTF8String], [[AdiumOTREncryption accountNameForOtrlAccount:account] UTF8String],
			[account.service.serviceCodeUniqueID UTF8String], OTRL_INSTAG_BEST, 0, NULL, NULL, NULL);
	}
}

// Builds the prompt payload for the fingerprint controllers. The fingerprint
// bytes travel with it, so an accept or deny lands on the exact instance the
// user saw (#415). The caller ensures the context has an active fingerprint.
static NSDictionary *OTRResponseInfoForContext(ConnContext *context, AIAccount *account, NSString *who)
{
	char our_hash[OTRL_PRIVKEY_FPRINT_HUMAN_LEN] = "";
	char their_hash[OTRL_PRIVKEY_FPRINT_HUMAN_LEN] = "";

	Fingerprint *fingerprint = context->active_fingerprint;
	if (fingerprint != NULL) {
		otrl_privkey_hash_to_human(their_hash, fingerprint->fingerprint);
	}

	OtrlUserState userState = otrg_userstate();
	if (userState != NULL) {
		otrl_privkey_fingerprint(userState, our_hash, context->accountname, context->protocol);
	}

	return [NSMutableDictionary
		dictionaryWithObjectsAndKeys:(account ? account : (id)[NSNull null]), @"AIAccount", who, @"who",
									 [NSString stringWithUTF8String:their_hash], @"Their Fingerprint",
									 [NSString stringWithUTF8String:our_hash], @"Our Fingerprint",
									 [NSData dataWithBytes:fingerprint->fingerprint length:20], @"Fingerprint", nil];
}

// -------------------------------------------------------------------------------------------------
#pragma mark Helper C functions
// -------------------------------------------------------------------------------------------------

// Forward declarations for functions used before definition
static void update_security_details_for_chat(AIChat *inChat);

static AIAccount *accountFromAccountID(const char *accountID)
{
	@autoreleasepool {
		if (!accountID)
			return nil;
		return [adium.accountController accountWithInternalObjectID:[NSString stringWithUTF8String:accountID]];
	}
}

static AIService *serviceFromUniqueID(const char *uniqueID)
{
	@autoreleasepool {
		NSString *sid = [NSString stringWithUTF8String:uniqueID];
		return [adium.accountController serviceWithUniqueID:sid];
	}
}

static AIListContact *contactFromInfo(const char *accountID, const char *protocol, const char *username)
{
	@autoreleasepool {
		if (!accountID || !protocol || !username)
			return nil;

		AIAccount *account = accountFromAccountID(accountID);
		if (!account) {
			// The stored account may be gone. Fall back to the first account on
			// the same service; with several accounts on one service that is a
			// guess, so name the account it picked.
			NSString *protocolNS = [NSString stringWithUTF8String:protocol];
			for (AIAccount *acct in adium.accountController.accounts) {
				if ([acct.service.serviceCodeUniqueID isEqualToString:protocolNS]) {
					account = acct;
					break;
				}
			}
			if (account) {
				AILogWithSignature(@"No account %s; resolved the context of %s through %@.", accountID, username,
								   account);
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
		if (!chat)
			return NULL;

		return contextForAccountAndContact([chat account], (AIListContact *)[chat listObject]);
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

		AIService *service = serviceFromUniqueID(protocol);
		if (!service) {
			AILogWithSignature(@"No service with unique ID %s; the key window shows an unknown service.", protocol);
		}
		NSString *identifier =
			[NSString stringWithFormat:@"%@ (%@)", account.formattedUID, ([service shortDescription] ?: @"unknown")];
		[ESOTRPrivateKeyGenerationWindowController startedGeneratingForIdentifier:identifier];

		NSString *privkeyPath = [adiumOTREncryption privKeyPathForAccount:account];
		NSString *fullPath = [privkeyPath stringByExpandingTildeInPath];
		gcry_error_t error = otrl_privkey_generate(otrg_userstate(), fullPath.UTF8String, accountname, protocol);
		if (error) {
			AILogWithSignature(@"libotr could not generate a private key: %s", gcry_strerror(error));
		}

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

		AIChat *chat = chatForContext(otrl_context_find(otrg_userstate(), recipient, accountname, protocol,
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

		if (otrl_privkey_fingerprint(otrg_userstate(), our_hash, accountname, protocol)) {
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
			@"Fingerprint" : [NSData dataWithBytes:fingerprint length:20],
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
		otrl_privkey_write_fingerprints(otrg_userstate(), fingerprintPath.UTF8String);
	}
}

// libotr has no write function for a single key, so the migrated file is
// rebuilt from the parsed key and serialized in the same advanced format
// libotr's own writer uses (#413).
static NSData *RebuiltPrivateKeyFileData(OtrlPrivKey *key, NSString *currentName, NSString *currentProtocol)
{
	gcry_sexp_t rebuilt = NULL;
	gcry_error_t error = gcry_sexp_build(&rebuilt, NULL, "(privkeys (account (name %s) (protocol %s) %S))",
										 currentName.UTF8String, currentProtocol.UTF8String, key->privkey);
	if (error) {
		AILogWithSignature(@"libotr could not rebuild the private key with the current identity strings: %s",
						   gcry_strerror(error));
		return nil;
	}

	// gcry_sexp_sprint reports the length including the terminating NUL, the
	// same contract libotr's own writer relies on.
	size_t length = gcry_sexp_sprint(rebuilt, GCRYSEXP_FMT_ADVANCED, NULL, 0);
	if (length == 0) {
		gcry_sexp_release(rebuilt);
		return nil;
	}

	NSMutableData *data = [NSMutableData dataWithLength:length];
	gcry_sexp_sprint(rebuilt, GCRYSEXP_FMT_ADVANCED, data.mutableBytes, length);
	gcry_sexp_release(rebuilt);

	if (data.length > 0 && ((const char *)data.bytes)[data.length - 1] == '\0') {
		data.length = data.length - 1;
	}

	return data;
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
		otrl_instag_generate(otrg_userstate(), instagPath.UTF8String, accountname, protocol);
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

		NSString *accountName = [AdiumOTREncryption accountNameForOtrlAccount:account];
		NSString *username = contact.UID;

		otrl_message_sending(otrg_userstate(), &otrOps, NULL, accountName.UTF8String,
							 account.service.serviceCodeUniqueID.UTF8String, username.UTF8String, OTRL_INSTAG_BEST,
							 "?OTRv2?", NULL, NULL, OTRL_FRAGMENT_SEND_SKIP, NULL, NULL, NULL);
	}
}

static void disconnect_from_context(ConnContext *context)
{
	@autoreleasepool {
		if (!context)
			return;

		otrl_message_disconnect(otrg_userstate(), &otrOps, NULL, context->accountname, context->protocol,
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
			if (otrl_privkey_fingerprint(otrg_userstate(), our_hash, context->accountname, context->protocol)) {
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

		ConnContext *context =
			otrl_context_find(otrg_userstate(), username, accountname, protocol, OTRL_INSTAG_BEST, 0, NULL, NULL, NULL);
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

		// Use the context the fingerprint belongs to. A lookup by name alone
		// picks the first client instance, not necessarily this one (#415).
		ConnContext *context = fingerprint->context;
		AIChat *chat = chatForContext(context);

		otrl_context_forget_fingerprint(fingerprint, 0);
		otrg_plugin_write_fingerprints();
		otrg_ui_update_keylist();

		if (chat) {
			update_security_details_for_chat(chat);
		}
	}
}

Fingerprint *otrg_fingerprint_for_identity(const char *username, const char *accountname, const char *protocol,
										   const unsigned char *fingerprint, size_t fingerprintLength)
{
	@autoreleasepool {
		if (!username || !accountname || !protocol || !fingerprint || fingerprintLength != 20) {
			AILogWithSignature(@"OTR: the fingerprint lookup got invalid arguments; no fingerprint is resolved.");
			return NULL;
		}

		OtrlUserState userState = otrg_userstate();
		if (userState == NULL) {
			logMissingUserState(@"the fingerprint lookup");
			return NULL;
		}

		// One context per client instance. The fingerprint bytes pick the exact
		// instance, so an accept or deny lands on the one the user saw (#415).
		for (ConnContext *context = userState->context_root; context != NULL; context = context->next) {
			if (strcmp(context->username, username) != 0 || strcmp(context->accountname, accountname) != 0 ||
				strcmp(context->protocol, protocol) != 0) {
				continue;
			}

			Fingerprint *found = otrl_context_find_fingerprint(context, (unsigned char *)fingerprint, 0, NULL);
			if (found != NULL) {
				return found;
			}
		}

		return NULL;
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
	// The preferences UI reads this too; route it through the accessor so a
	// runtime-installed plugin has a state before the first message (#410).
	return otrg_userstate();
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

+ (NSString *)accountNameForOtrlAccount:(AIAccount *)inAccount
{
	// libotr identifies an account by this string in its contexts, stored
	// fingerprints, and private-key files, so it must be the same string the
	// peer side derives: upstream uses the raw internalObjectID (#403).
	return inAccount.internalObjectID;
}

#pragma mark OTR operations

- (id)init
{
	if ((self = [super init])) {
		OTRPersistenceFilePath = nil;
		OTRWindowController = nil;
		adiumOTREncryption = self;

		// The plugin that owns this object loads before the accounts do, and the
		// keys live in the profile. Both are ready when the app finishes loading,
		// so start the encryption there (#405). A plugin installed at runtime
		// loads after that notification and never sees it; otrg_userstate()
		// calls initializeOTR on first use for that case (#410).
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(adiumFinishedLaunching:)
													 name:AIApplicationDidFinishLoadingNotification
												   object:nil];
	}

	return self;
}

- (void)adiumFinishedLaunching:(NSNotification *)notification
{
#pragma unused(notification)
	[self initializeOTR];
}

// Idempotent. Runs from the app-finished-loading notification on a normal
// launch, and from otrg_userstate() when a runtime-installed plugin first
// needs the state (#410).
- (void)initializeOTR
{
	if (otrg_plugin_userstate != NULL) {
		return;
	}

	// Every send and every receive dereferences the user state, so create it
	// before the first message can be sent (#405).
	otrg_plugin_userstate = otrl_userstate_create();
	if (otrg_plugin_userstate == NULL) {
		AILogWithSignature(@"Could not create the OTR user state. OTR stays off for this run.");
		return;
	}

	// Move any stored identity from the pre-#403 strings to the current ones
	// before the files are read (#413)
	[self migrateStoredIdentities];

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

#pragma mark Stored identity migration

// #403 changed the account and protocol strings libotr keys its stored data by.
// Without this pass the old private key is never read again, so the app
// generates a fresh key and every peer verification is redone once (#413).
- (void)migrateStoredIdentities
{
	NSMutableArray<AIOTRIdentityMigration *> *migrations = [NSMutableArray array];

	for (AIAccount *account in adium.accountController.accounts) {
		AIService *service = account.service;
		NSString *internalObjectID = account.internalObjectID;
		if (service == nil || internalObjectID == nil) {
			AILogWithSignature(@"OTR: skipped the identity migration for %@: it has no service or account ID.",
							   account);
			continue;
		}

		AIOTRIdentityMigration *migration = [[AIOTRIdentityMigration alloc]
			initWithLegacyAccountName:[NSString stringWithFormat:@"%@.%@", service.serviceID, internalObjectID]
				   currentAccountName:[[self class] accountNameForOtrlAccount:account]
					   legacyProtocol:service.serviceID
					  currentProtocol:service.serviceCodeUniqueID];
		[migrations addObject:migration];

		[self migratePrivateKeyFileForAccount:account migration:migration];
	}

	[self migrateStoreAtPath:[FINGERPRINT_PATH stringByExpandingTildeInPath]
			  withMigrations:migrations
					rewriter:AIOTRMigratedFingerprintStoreText];
	[self migrateStoreAtPath:[INSTAG_PATH stringByExpandingTildeInPath]
			  withMigrations:migrations
					rewriter:AIOTRMigratedInstagStoreText];
}

- (void)migrateStoreAtPath:(NSString *)storePath
			withMigrations:(NSArray<AIOTRIdentityMigration *> *)migrations
				  rewriter:(NSString *(*)(NSString *, NSArray<AIOTRIdentityMigration *> *, NSUInteger *))rewriter
{
	NSFileManager *fileManager = [NSFileManager defaultManager];

	if (![fileManager fileExistsAtPath:storePath]) {
		// A fresh profile has no stored identities to move.
		return;
	}

	NSError *readError = nil;
	NSString *storeText = [NSString stringWithContentsOfFile:storePath encoding:NSUTF8StringEncoding error:&readError];
	if (storeText == nil) {
		AILogWithSignature(@"OTR: cannot read the store %@ (%@). The stored identities stay as they are.", storePath,
						   readError);
		return;
	}

	NSUInteger changedLineCount = 0;
	NSString *migratedText = rewriter(storeText, migrations, &changedLineCount);
	if (changedLineCount == 0) {
		return;
	}

	NSError *writeError = nil;
	if (![migratedText writeToFile:storePath atomically:YES encoding:NSUTF8StringEncoding error:&writeError]) {
		AILogWithSignature(@"OTR: cannot write the migrated store %@ (%@). The stored identities stay as they are.",
						   storePath, writeError);
		return;
	}

	AILogWithSignature(@"OTR: moved %lu stored %@ entry or entries to the current identity strings.",
					   (unsigned long)changedLineCount, [storePath lastPathComponent]);
}

- (void)migratePrivateKeyFileForAccount:(AIAccount *)inAccount migration:(AIOTRIdentityMigration *)migration
{
	NSString *currentPath = [[self privKeyPathForAccount:inAccount] stringByExpandingTildeInPath];
	NSString *legacyPath = [[PRIVKEY_PATH
		stringByAppendingPathComponent:[NSString
										   stringWithFormat:@"%@.%@.key", migration.legacyAccountName,
															[inAccount.UID stringByReplacingOccurrencesOfString:@"/"
																									 withString:@"_"]]]
		stringByExpandingTildeInPath];

	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath:currentPath]) {
		// Already migrated, or a fresh key exists. Never overwrite it, but a
		// legacy copy left behind by an earlier failed removal still goes.
		[self removeLegacyKeyFileAtPath:legacyPath
				  whenCurrentFileAtPath:currentPath
						holdsKeyForName:migration.currentAccountName
							   protocol:migration.currentProtocol];
		return;
	}
	if (![fileManager fileExistsAtPath:legacyPath]) {
		// Nothing to move for this account.
		return;
	}

	OtrlUserState scratch = otrl_userstate_create();
	if (scratch == NULL) {
		AILogWithSignature(@"OTR: cannot create a scratch state to migrate the key file %@.", legacyPath);
		return;
	}

	if (otrl_privkey_read(scratch, legacyPath.UTF8String)) {
		AILogWithSignature(@"OTR: cannot read the legacy key file %@. It stays as it is.", legacyPath);
		otrl_userstate_free(scratch);
		return;
	}

	OtrlPrivKey *key = scratch->privkey_root;
	if (key == NULL || key->next != NULL || strcmp(key->accountname, migration.legacyAccountName.UTF8String) != 0 ||
		strcmp(key->protocol, migration.legacyProtocol.UTF8String) != 0) {
		AILogWithSignature(@"OTR: the legacy key file %@ does not hold exactly one key for %@. It stays as it is.",
						   legacyPath, migration.legacyAccountName);
		otrl_userstate_free(scratch);
		return;
	}

	NSData *rebuilt = RebuiltPrivateKeyFileData(key, migration.currentAccountName, migration.currentProtocol);
	otrl_userstate_free(scratch);

	NSError *writeError = nil;
	BOOL wrote = NO;
	if (rebuilt != nil) {
		// Create the file 0600 before the write, the way libotr's own writer
		// does: an atomic NSData write goes through the process umask and
		// leaves the key world-readable.
		if ([fileManager createFileAtPath:currentPath contents:nil attributes:@{NSFilePosixPermissions : @(0600)}]) {
			wrote = [rebuilt writeToFile:currentPath options:0 error:&writeError];
		} else {
			AILogWithSignature(@"OTR: cannot create the migrated key file %@. The legacy file stays as it is.",
							   currentPath);
			return;
		}
	}
	if (!wrote) {
		AILogWithSignature(@"OTR: cannot write the migrated key file %@ (%@). The legacy file stays as it is.",
						   currentPath, writeError);
		return;
	}

	gcry_error_t verifyError = 0;
	if (![self privateKeyFileAtPath:currentPath
					holdsKeyForName:migration.currentAccountName
						   protocol:migration.currentProtocol
							  error:&verifyError]) {
		// Drop the damaged copy so the next launch retries the move.
		[fileManager removeItemAtPath:currentPath error:NULL];
		AILogWithSignature(@"OTR: the migrated key file %@ does not read back (error %u); removed it. The legacy "
						   @"file stays as it is.",
						   currentPath, (unsigned int)verifyError);
		return;
	}

	NSError *removalError = nil;
	if (![fileManager removeItemAtPath:legacyPath error:&removalError]) {
		AILogWithSignature(@"OTR: moved the key to %@, but cannot remove %@ (%@). The cleanup retries on the next "
						   @"launch.",
						   currentPath, legacyPath, removalError);
		return;
	}

	AILogWithSignature(@"OTR: moved the private key to %@ with the current identity strings.", currentPath);
}

// Removes a legacy key copy whose earlier removal failed. The current file
// must read back first, so the cleanup never removes the only good copy.
- (void)removeLegacyKeyFileAtPath:(NSString *)legacyPath
			whenCurrentFileAtPath:(NSString *)currentPath
				  holdsKeyForName:(NSString *)accountName
						 protocol:(NSString *)protocol
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if (![fileManager fileExistsAtPath:legacyPath]) {
		return;
	}

	if (![self privateKeyFileAtPath:currentPath holdsKeyForName:accountName protocol:protocol error:NULL]) {
		AILogWithSignature(@"OTR: kept the legacy key file %@: the current key file %@ does not read back.", legacyPath,
						   currentPath);
		return;
	}

	NSError *removalError = nil;
	if (![fileManager removeItemAtPath:legacyPath error:&removalError]) {
		AILogWithSignature(@"OTR: cannot remove the leftover legacy key file %@ (%@). The cleanup retries on the "
						   @"next launch.",
						   legacyPath, removalError);
		return;
	}

	AILogWithSignature(@"OTR: removed the leftover legacy key file %@.", legacyPath);
}

// Reads the written file back in a scratch state, so a damaged write never
// replaces the legacy file. On NO, outError holds the libotr read error; it
// stays zero when the file parsed but holds no key for the account.
- (BOOL)privateKeyFileAtPath:(NSString *)path
			 holdsKeyForName:(NSString *)accountName
					protocol:(NSString *)protocol
					   error:(gcry_error_t *)outError
{
	OtrlUserState scratch = otrl_userstate_create();
	if (scratch == NULL) {
		if (outError != NULL) {
			*outError = gcry_error(GPG_ERR_ENOMEM);
		}
		return NO;
	}

	gcry_error_t readError = otrl_privkey_read(scratch, path.UTF8String);
	BOOL holdsKey =
		(readError == 0) && (otrl_privkey_find(scratch, accountName.UTF8String, protocol.UTF8String) != NULL);
	otrl_userstate_free(scratch);

	if (outError != NULL) {
		*outError = readError;
	}

	return holdsKey;
}

#pragma mark OTR integration

- (OtrlPolicy)otrPolicyForUsername:(NSString *)username accountName:(NSString *)accountName
{
	AIAccount *account = [adium.accountController accountWithInternalObjectID:accountName];
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
	AIAccount *account = [adium.accountController accountWithInternalObjectID:accountName];
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

	OtrlUserState userState = otrg_userstate();
	if (userState == NULL) {
		// No state means no OTR: pass the message through untouched, the same
		// as any other non-OTR message (#402).
		logMissingUserState(@"message decryption");
		if (outIsOTR)
			*outIsOTR = NO;
		return message;
	}

	int ret = otrl_message_receiving(userState, &otrOps,
									 NULL,                       // opdata
									 accountName.UTF8String,     // accountname
									 accountProtocol.UTF8String, // protocol
									 username.UTF8String,        // sender
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
		// Not an OTR message. Pass it through unchanged: libotr sets newMessage
		// only for a message it decoded, so a plain message arrives here (#402).
		if (outIsOTR)
			*outIsOTR = NO;
		return message;
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
			if (!decodedMessage) {
				// libotr handed back bytes that are not UTF-8; the message is
				// unreadable rather than absent, so say which happened.
				AILogWithSignature(@"Decrypted message is not UTF-8 and was dropped.");
			}
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
			   accountProtocol:inAccount.service.serviceCodeUniqueID
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

	OtrlUserState userState = otrg_userstate();
	if (userState == NULL) {
		logMissingUserState(@"message encryption");
		return nil;
	}

	err = otrl_message_sending(userState, &otrOps,
							   NULL,                       // opdata
							   accountName.UTF8String,     // accountname
							   accountProtocol.UTF8String, // protocol
							   username.UTF8String,        // recipient
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
	NSString *protocol = account.service.serviceCodeUniqueID;
	NSString *username = contact.UID;

	gcry_error_t err;
	char *encryptedMessage = NULL;

	err = otrl_message_sending(otrg_userstate(), &otrOps, NULL, accountName.UTF8String, protocol.UTF8String,
							   username.UTF8String, OTRL_INSTAG_BEST, plaintext.UTF8String, NULL, &encryptedMessage,
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

	if (context->active_fingerprint == NULL) {
		// Without the fingerprint bytes the answer cannot be recorded, so do
		// not ask about a blank value (#415).
		AILogWithSignature(@"OTR: no active fingerprint for %@; the verification prompt is skipped.", inChat);
		return;
	}

	AIListContact *contact = (AIListContact *)[inChat listObject];
	NSString *who = contact ? contact.UID : [NSString stringWithUTF8String:context->username];

	[ESOTRUnknownFingerprintController
		showVerifyFingerprintPromptWithResponseInfo:OTRResponseInfoForContext(context, account, who)];
}

- (void)verifyUnknownFingerprint:(NSValue *)contextValue
{
	ConnContext *context = [contextValue pointerValue];
	if (!context)
		return;

	if (context->active_fingerprint == NULL) {
		AILogWithSignature(@"OTR: no active fingerprint for %s; the verification prompt is skipped.",
						   context->username);
		return;
	}

	AIAccount *account = accountFromAccountID(context->accountname);
	NSString *who = [NSString stringWithUTF8String:context->username];

	[ESOTRUnknownFingerprintController
		showUnknownFingerprintPromptWithResponseInfo:OTRResponseInfoForContext(context, account, who)];
}

- (void)disconnectFromUsername:(NSString *)username
				   accountName:(NSString *)accountName
			   accountProtocol:(NSString *)accountProtocol
{
	OtrlUserState userState = otrg_userstate();
	if (userState == NULL) {
		logMissingUserState(@"the session disconnect");
		return;
	}

	otrl_message_disconnect(userState, &otrOps, NULL, accountName.UTF8String, accountProtocol.UTF8String,
							username.UTF8String, OTRL_INSTAG_BEST);
}

- (void)disconnectFromAccount:(AIAccount *)inAccount
{
	if (!inAccount) {
		return;
	}

	OtrlUserState userState = otrg_userstate();
	if (userState == NULL) {
		logMissingUserState(@"the account disconnect");
		return;
	}

	NSEnumerator *enumerator;
	NSString *username;

	enumerator = [[[adium.contactController allContacts] valueForKey:@"UID"] objectEnumerator];
	while ((username = [enumerator nextObject])) {
		otrl_message_disconnect(userState, &otrOps, NULL, [[self class] accountNameForOtrlAccount:inAccount].UTF8String,
								inAccount.service.serviceCodeUniqueID.UTF8String, username.UTF8String,
								OTRL_INSTAG_BEST);
	}
}

- (void)initiateSMPForContact:(AIListContact *)contact
{
	ConnContext *context = contextForAccountAndContact(contact.account, contact);
	if (context) {
		OtrlUserState userState = otrg_userstate();
		const char *question = [self secretQuestion].UTF8String;
		otrl_message_initiate_smp(userState, &otrOps, NULL, context, (unsigned const char *)question, strlen(question));
	}
}

- (void)respondSMPForContact:(AIListContact *)contact
{
	ConnContext *context = contextForAccountAndContact(contact.account, contact);
	if (context) {
		OtrlUserState userState = otrg_userstate();
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
	ConnContext *context = contextForAccountAndContact(contact.account, contact);
	if (context) {
		otrl_message_abort_smp(otrg_userstate(), &otrOps, NULL, context);
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
	AIAccount *account = [adium.accountController accountWithInternalObjectID:accountName];
	if (!account) {
		return;
	}

	OtrlUserState userState = otrg_userstate();
	if (userState == NULL) {
		logMissingUserState(@"the fingerprint trust");
		return;
	}

	ConnContext *context =
		otrl_context_find(userState, username.UTF8String, accountName.UTF8String,
						  account.service.serviceCodeUniqueID.UTF8String, OTRL_INSTAG_BEST, 0, NULL, NULL, NULL);
	if (context && context->active_fingerprint) {
		if (fingerprint &&
			[[self activeFingerprintForContact:[adium.contactController contactWithService:account.service
																				   account:account
																					   UID:username]]
				isEqualToString:fingerprint]) {
			otrl_context_set_trust(context->active_fingerprint, "verified");
		} else {
			// The user verified a fingerprint, but the context now holds a
			// different one, so trusting nothing is the safe result. Say so.
			AILogWithSignature(@"Not trusting %@ for %@: it does not match the active fingerprint.", fingerprint,
							   username);
		}
	}
}

- (NSString *)activeFingerprintForContact:(AIListContact *)inContact
{
	ConnContext *context = contextForAccountAndContact(inContact.account, inContact);
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
	OtrlUserState userState = otrg_userstate();
	if (userState == NULL) {
		logMissingUserState(@"the fingerprint lookup");
		return nil;
	}

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
	ConnContext *context = contextForAccountAndContact(contact.account, contact);
	if (context && context->active_fingerprint) {
		return (context->active_fingerprint->trust && context->active_fingerprint->trust[0]);
	}

	return NO;
}

- (BOOL)isOTRForContact:(AIListContact *)contact
{
	ConnContext *context = contextForAccountAndContact(contact.account, contact);

	return (context && context->msgstate == OTRL_MSGSTATE_ENCRYPTED);
}

- (NSString *)sessionIDForContact:(AIListContact *)contact
{
	ConnContext *context = contextForAccountAndContact(contact.account, contact);

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
	ConnContext *context = contextForAccountAndContact(contact.account, contact);

	return (context != NULL);
}

- (BOOL)isOTRRequiredForContact:(AIListContact *)contact
{
	ConnContext *context = contextForAccountAndContact(contact.account, contact);

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

	OtrlUserState userState = otrg_userstate();
	if (userState == NULL) {
		logMissingUserState(@"private key generation");
		return;
	}

	gcry_error_t err = otrl_privkey_generate(userState, [privkeyFilename UTF8String],
											 [[self class] accountNameForOtrlAccount:inAccount].UTF8String,
											 inAccount.service.serviceCodeUniqueID.UTF8String);
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

	OtrlUserState userState = otrg_userstate();

	// The flag stays per call: one account's success must not skip the legacy
	// fallback for the next account.
	BOOL keyRead = (otrl_privkey_read(userState, privkeyFilename.UTF8String) == 0);

	if (!keyRead) {
		NSString *oldPrivkeyFilename = [[self oldPrivKeyPathForAccount:inAccount] stringByExpandingTildeInPath];
		if ([oldPrivkeyFilename length] > 0) {
			otrl_privkey_read(userState, oldPrivkeyFilename.UTF8String);
		}
	}
}

- (BOOL)readFingerprintsAndPrivkeys
{
	NSString *fingerprintPath = [FINGERPRINT_PATH stringByExpandingTildeInPath];
	NSString *instagPath = [INSTAG_PATH stringByExpandingTildeInPath];

	OtrlUserState userState = otrg_userstate();

	gcry_error_t fingerprintError = otrl_privkey_read_fingerprints(userState, [fingerprintPath UTF8String], NULL, NULL);
	if (fingerprintError != 0) {
		AILogWithSignature(@"Could not read the OTR fingerprint file %@ (error %u).", fingerprintPath,
						   (unsigned int)fingerprintError);
	}

	gcry_error_t instagError = otrl_instag_read(userState, [instagPath UTF8String]);
	if (instagError != 0) {
		AILogWithSignature(@"Could not read the OTR instance-tag file %@ (error %u).", instagPath,
						   (unsigned int)instagError);
	}

	// Read every configured account's key, not only the accounts that are
	// online: this runs before the accounts connect, and a key that stays
	// unloaded makes libotr call create_privkey, which overwrites the stored
	// key with a fresh one (#413).
	for (AIAccount *account in adium.accountController.accounts) {
		[self readPrivateKeyForAccount:account];
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
		OtrlUserState userState = otrg_userstate();
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
		OtrlUserState userState = otrg_userstate();
		if (userState == NULL) {
			return;
		}

		ConnContext *context = userState->context_root;
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
