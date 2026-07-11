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

/*!
 * @brief Cocoa wrapper for accessing the system keychain
 *
 * Backed by the modern SecItem* API (kSecClassGenericPassword / kSecClassInternetPassword)
 * instead of the deprecated SecKeychain* API.
 */

#import "AIKeychain.h"
#import <CoreFoundation/CoreFoundation.h>
#import <Security/Security.h>

#define AI_LOCALIZED_SECURITY_ERROR_DESCRIPTION(err)                                                                   \
	NSLocalizedStringFromTableInBundle([[NSNumber numberWithLong:(err)] stringValue], @"SecErrorMessages",             \
									   [NSBundle bundleWithIdentifier:@"com.apple.security"], /* comment */ nil)

static AIKeychain *sharedDefaultKeychain = nil;

#pragma mark - Helpers

static NSString *AIKeychainProtocolString(SecProtocolType protocol)
{
	/* Map SecProtocolType values to their SecItem* kSecAttrProtocol string equivalents.
	 * Custom types (e.g. FOUR_CHAR_CODE('AdIM')) fall through to a 4-char ASCII string.
	 * ponytail: only maps the protocol types actually used by Adium callers;
	 * add more if a caller uses an unmapped type. */
	switch (protocol) {
	case kSecProtocolTypeHTTPProxy:
		return (__bridge NSString *)kSecAttrProtocolHTTPProxy;
	case kSecProtocolTypeHTTPSProxy:
		return (__bridge NSString *)kSecAttrProtocolHTTPSProxy;
	case kSecProtocolTypeFTPProxy:
		return (__bridge NSString *)kSecAttrProtocolFTPProxy;
	case kSecProtocolTypeSOCKS:
		return (__bridge NSString *)kSecAttrProtocolSOCKS;
	case kSecProtocolTypeRTSPProxy:
		return (__bridge NSString *)kSecAttrProtocolRTSPProxy;
	case kSecProtocolTypeFTP:
		return (__bridge NSString *)kSecAttrProtocolFTP;
	case kSecProtocolTypeHTTP:
		return (__bridge NSString *)kSecAttrProtocolHTTP;
	case kSecProtocolTypeHTTPS:
		return (__bridge NSString *)kSecAttrProtocolHTTPS;
	case kSecProtocolTypeIMAP:
		return (__bridge NSString *)kSecAttrProtocolIMAP;
	case kSecProtocolTypeSMTP:
		return (__bridge NSString *)kSecAttrProtocolSMTP;
	case kSecProtocolTypePOP3:
		return (__bridge NSString *)kSecAttrProtocolPOP3;
	case kSecProtocolTypeSSH:
		return (__bridge NSString *)kSecAttrProtocolSSH;
	case kSecProtocolTypeLDAP:
		return (__bridge NSString *)kSecAttrProtocolLDAP;
	case kSecProtocolTypeIRC:
		return (__bridge NSString *)kSecAttrProtocolIRC;
	default: {
		char code[5] = {(char)((protocol >> 24) & 0xFF), (char)((protocol >> 16) & 0xFF),
						(char)((protocol >> 8) & 0xFF), (char)(protocol & 0xFF), 0};
		return [NSString stringWithCString:code encoding:NSASCIIStringEncoding];
	}
	}
}

/* Helper: on macOS, the underlying keychain storage is shared — items stored by the
 * legacy SecKeychain* API are visible to SecItem* and vice versa. No explicit migration
 * pass is needed; existing credentials are found by SecItemCopyMatching on first read. */
static OSStatus AIKeychainCopyPassword(NSString *server, NSString *account, NSString *protocol, NSString *path,
									   UInt16 port, NSString *domain, SecAuthenticationType authType,
									   NSString **outPassword, SecKeychainItemRef *outItem)
{
	NSMutableDictionary *query = [NSMutableDictionary
		dictionaryWithObjectsAndKeys:(__bridge id)kSecClassInternetPassword, (__bridge id)kSecClass, kCFBooleanTrue,
									 (__bridge id)kSecReturnData, nil];
	if (server)
		[query setObject:server forKey:(__bridge id)kSecAttrServer];
	if (account)
		[query setObject:account forKey:(__bridge id)kSecAttrAccount];
	if (protocol)
		[query setObject:protocol forKey:(__bridge id)kSecAttrProtocol];
	if (domain)
		[query setObject:domain forKey:(__bridge id)kSecAttrSecurityDomain];
	if (path)
		[query setObject:path forKey:(__bridge id)kSecAttrPath];
	if (port)
		[query setObject:[NSNumber numberWithUnsignedShort:port] forKey:(__bridge id)kSecAttrPort];

	CFTypeRef result = NULL;
	OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);

	if (err == noErr && result) {
		NSData *data = (__bridge NSData *)result;
		if (outPassword) {
			*outPassword = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		}
		CFRelease(result);
	} else {
		if (outPassword)
			*outPassword = nil;
	}

	if (outItem)
		*outItem = NULL; /* SecItem* has no item-ref concept; NULL is the signal for "found" */
	return err;
}

static OSStatus AIKeychainAddPassword(NSString *server, NSString *account, NSString *protocol, NSString *path,
									  UInt16 port, NSString *domain, SecAuthenticationType authType, NSString *password)
{
	NSMutableDictionary *attrs = [NSMutableDictionary
		dictionaryWithObjectsAndKeys:(__bridge id)kSecClassInternetPassword, (__bridge id)kSecClass,
									 [password dataUsingEncoding:NSUTF8StringEncoding], (__bridge id)kSecValueData,
									 nil];
	if (server)
		[attrs setObject:server forKey:(__bridge id)kSecAttrServer];
	if (account)
		[attrs setObject:account forKey:(__bridge id)kSecAttrAccount];
	if (protocol)
		[attrs setObject:protocol forKey:(__bridge id)kSecAttrProtocol];
	if (domain)
		[attrs setObject:domain forKey:(__bridge id)kSecAttrSecurityDomain];
	if (path)
		[attrs setObject:path forKey:(__bridge id)kSecAttrPath];
	if (port)
		[attrs setObject:[NSNumber numberWithUnsignedShort:port] forKey:(__bridge id)kSecAttrPort];

	return SecItemAdd((__bridge CFDictionaryRef)attrs, NULL);
}

static OSStatus AIKeychainUpdatePassword(NSString *server, NSString *account, NSString *protocol, NSString *path,
										 UInt16 port, NSString *domain, SecAuthenticationType authType,
										 NSString *newPassword)
{
	NSMutableDictionary *query = [NSMutableDictionary
		dictionaryWithObjectsAndKeys:(__bridge id)kSecClassInternetPassword, (__bridge id)kSecClass, nil];
	if (server)
		[query setObject:server forKey:(__bridge id)kSecAttrServer];
	if (account)
		[query setObject:account forKey:(__bridge id)kSecAttrAccount];
	if (protocol)
		[query setObject:protocol forKey:(__bridge id)kSecAttrProtocol];
	if (domain)
		[query setObject:domain forKey:(__bridge id)kSecAttrSecurityDomain];
	if (path)
		[query setObject:path forKey:(__bridge id)kSecAttrPath];
	if (port)
		[query setObject:[NSNumber numberWithUnsignedShort:port] forKey:(__bridge id)kSecAttrPort];

	NSDictionary *update =
		[NSDictionary dictionaryWithObjectsAndKeys:[newPassword dataUsingEncoding:NSUTF8StringEncoding],
												   (__bridge id)kSecValueData, nil];

	return SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)update);
}

static OSStatus AIKeychainDeletePassword(NSString *server, NSString *account, NSString *protocol, NSString *path,
										 UInt16 port, NSString *domain, SecAuthenticationType authType)
{
	NSMutableDictionary *query = [NSMutableDictionary
		dictionaryWithObjectsAndKeys:(__bridge id)kSecClassInternetPassword, (__bridge id)kSecClass, nil];
	if (server)
		[query setObject:server forKey:(__bridge id)kSecAttrServer];
	if (account)
		[query setObject:account forKey:(__bridge id)kSecAttrAccount];
	if (protocol)
		[query setObject:protocol forKey:(__bridge id)kSecAttrProtocol];
	if (domain)
		[query setObject:domain forKey:(__bridge id)kSecAttrSecurityDomain];
	if (path)
		[query setObject:path forKey:(__bridge id)kSecAttrPath];
	if (port)
		[query setObject:[NSNumber numberWithUnsignedShort:port] forKey:(__bridge id)kSecAttrPort];

	return SecItemDelete((__bridge CFDictionaryRef)query);
}

static NSError *AIKeychainErrorFromStatus(OSStatus err, NSString *funcName)
{
	if (err == noErr)
		return nil;
	NSDictionary *userInfo = [NSDictionary
		dictionaryWithObjectsAndKeys:funcName ?: @"SecItem*", AIKEYCHAIN_ERROR_USERINFO_SECURITYFUNCTIONNAME,
									 AI_LOCALIZED_SECURITY_ERROR_DESCRIPTION(err),
									 AIKEYCHAIN_ERROR_USERINFO_ERRORDESCRIPTION, nil];
	return [NSError errorWithDomain:AIKEYCHAIN_ERROR_DOMAIN code:err userInfo:userInfo];
}

#pragma mark - Class methods (modern keychain — no locking to expose)

@implementation AIKeychain

+ (BOOL)lockAllKeychains_error:(out NSError **)outError
{
	/* ponytail: data-protection keychain is managed by the system; lock is implicitly handled. */
	if (outError)
		*outError = nil;
	return YES;
}

+ (BOOL)lockDefaultKeychain_error:(out NSError **)outError
{
	if (outError)
		*outError = nil;
	return YES;
}

+ (BOOL)unlockDefaultKeychain_error:(out NSError **)outError
{
	if (outError)
		*outError = nil;
	return YES;
}

+ (BOOL)unlockDefaultKeychainWithPassword:(NSString *)password error:(out NSError **)outError
{
	if (outError)
		*outError = nil;
	return YES;
}

+ (BOOL)allowsUserInteraction_error:(out NSError **)outError
{
	if (outError)
		*outError = nil;
	return YES;
}

+ (BOOL)setAllowsUserInteraction:(BOOL)flag error:(out NSError **)outError
{
	if (outError)
		*outError = nil;
	return YES;
}

+ (u_int32_t)keychainServicesVersion_error:(out NSError **)outError
{
	if (outError)
		*outError = nil;
	return 0;
}

#pragma mark Default keychain

+ (AIKeychain *)defaultKeychain_error:(out NSError **)outError
{
	if (outError)
		*outError = nil;

	if (!sharedDefaultKeychain) {
		sharedDefaultKeychain = [[self alloc] init];
	}

	return sharedDefaultKeychain;
}

+ (BOOL)setDefaultKeychain:(AIKeychain *)newDefaultKeychain error:(out NSError **)outError
{
	/* ponytail: SecItem* has no set-default-keychain concept; accept silently. */
	if (outError)
		*outError = nil;

	if (sharedDefaultKeychain != newDefaultKeychain) {
		sharedDefaultKeychain = newDefaultKeychain;
	}
	return YES;
}

#pragma mark File-based keychain (obsolete with data-protection keychain)

+ (AIKeychain *)keychainWithContentsOfFile:(NSString *)path error:(out NSError **)outError
{
	if (outError)
		*outError = nil;
	return [[self alloc] init];
}

- (id)initWithContentsOfFile:(NSString *)path error:(out NSError **)outError
{
	/* ponytail: data-protection keychain doesn't support file-based keychains.
	 * Return a plain instance; all SecItem* calls use the default keychain. */
	if ((self = [super init])) {
		keychainRef = NULL;
	}
	if (outError)
		*outError = nil;
	return self;
}

+ (AIKeychain *)keychainWithPath:(NSString *)path
						password:(NSString *)password
					  promptUser:(BOOL)prompt
				   initialAccess:(SecAccessRef)initialAccess
						   error:(out NSError **)outError
{
	if (outError)
		*outError = nil;
	return [[self alloc] init];
}

- (id)initWithPath:(NSString *)path
		  password:(NSString *)password
		promptUser:(BOOL)prompt
	 initialAccess:(SecAccessRef)initialAccess
			 error:(out NSError **)outError
{
	if ((self = [super init])) {
		keychainRef = NULL;
	}
	if (outError)
		*outError = nil;
	return self;
}

+ (AIKeychain *)keychainWithKeychainRef:(SecKeychainRef)newKeychainRef
{
	return [[self alloc] initWithKeychainRef:newKeychainRef];
}

- (id)initWithKeychainRef:(SecKeychainRef)newKeychainRef
{
	if ((self = [super init])) {
		keychainRef = newKeychainRef ? (SecKeychainRef)CFRetain(newKeychainRef) : NULL;
	}
	return self;
}

#pragma mark Settings & status (obsolete with data-protection keychain)

- (BOOL)getSettings:(out struct SecKeychainSettings *)outSettings error:(out NSError **)outError
{
	if (outError)
		*outError = nil;
	return NO;
}

- (BOOL)setSettings:(in struct SecKeychainSettings *)newSettings error:(out NSError **)outError
{
	if (outError)
		*outError = nil;
	return NO;
}

- (SecKeychainStatus)status_error:(out NSError **)outError
{
	if (outError)
		*outError = nil;
	return 0;
}

- (char *)getPathFileSystemRepresentation:(out char *)outBuf
								   length:(inout u_int32_t *)outLength
									error:(out NSError **)outError
{
	if (outError)
		*outError = nil;
	return NULL;
}

- (NSString *)path
{
	return nil;
}

#pragma mark Locking (obsolete — data-protection keychain is auto-managed)

- (BOOL)lockKeychain_error:(out NSError **)outError
{
	if (outError)
		*outError = nil;
	return YES;
}

- (BOOL)unlockKeychain_error:(out NSError **)outError
{
	if (outError)
		*outError = nil;
	return YES;
}

- (BOOL)unlockKeychainWithPassword:(NSString *)password error:(out NSError **)outError
{
	if (outError)
		*outError = nil;
	return YES;
}

#pragma mark Keychain deletion (not applicable to data-protection keychain)

- (BOOL)deleteKeychain_error:(out NSError **)outError
{
	if (outError)
		*outError = nil;
	return NO;
}

#pragma mark - Internet Passwords

- (BOOL)addInternetPassword:(NSString *)password
				  forServer:(NSString *)server
			 securityDomain:(NSString *)domain
					account:(NSString *)account
					   path:(NSString *)path
					   port:(u_int16_t)port
				   protocol:(SecProtocolType)protocol
		 authenticationType:(SecAuthenticationType)authType
			   keychainItem:(out SecKeychainItemRef *)outKeychainItem
					  error:(out NSError **)outError
{
	@autoreleasepool {

		NSString *protocolStr = AIKeychainProtocolString(protocol);
		OSStatus err = AIKeychainAddPassword(server, account, protocolStr, path, port, domain, authType, password);

		if (outError)
			*outError = AIKeychainErrorFromStatus(err, @"SecItemAdd");
		if (outKeychainItem)
			*outKeychainItem = NULL;

		return (err == noErr);
	}
}

- (BOOL)addInternetPassword:(NSString *)password
				  forServer:(NSString *)server
					account:(NSString *)account
				   protocol:(SecProtocolType)protocol
					  error:(out NSError **)outError
{
	return [self addInternetPassword:password
						   forServer:server
					  securityDomain:nil
							 account:account
								path:nil
								port:0
							protocol:protocol
				  authenticationType:kSecAuthenticationTypeDefault
						keychainItem:NULL
							   error:outError];
}

#pragma mark -

- (NSString *)findInternetPasswordForServer:(NSString *)server
							 securityDomain:(NSString *)domain
									account:(NSString *)account
									   path:(NSString *)path
									   port:(u_int16_t)port
								   protocol:(SecProtocolType)protocol
						 authenticationType:(SecAuthenticationType)authType
							   keychainItem:(out SecKeychainItemRef *)outKeychainItem
									  error:(out NSError **)outError
{
	NSString *protocolStr = AIKeychainProtocolString(protocol);
	NSString *password = nil;
	OSStatus err =
		AIKeychainCopyPassword(server, account, protocolStr, path, port, domain, authType, &password, outKeychainItem);

	if (outError)
		*outError = AIKeychainErrorFromStatus(err, @"SecItemCopyMatching");
	/* password is nil on err — matches legacy contract */
	return password;
}

- (NSString *)internetPasswordForServer:(NSString *)server
								account:(NSString *)account
							   protocol:(SecProtocolType)protocol
								  error:(out NSError **)outError
{
	return [self findInternetPasswordForServer:server
								securityDomain:nil
									   account:account
										  path:nil
										  port:0
									  protocol:protocol
							authenticationType:kSecAuthenticationTypeDefault
								  keychainItem:NULL
										 error:outError];
}

- (NSDictionary *)dictionaryFromKeychainForServer:(NSString *)server
										 protocol:(SecProtocolType)protocol
											error:(out NSError **)outError
{
	NSDictionary *result = nil;
	NSString *protocolStr = AIKeychainProtocolString(protocol);

	NSMutableDictionary *query = [NSMutableDictionary
		dictionaryWithObjectsAndKeys:(__bridge id)kSecClassInternetPassword, (__bridge id)kSecClass, server,
									 (__bridge id)kSecAttrServer, protocolStr, (__bridge id)kSecAttrProtocol,
									 kCFBooleanTrue, (__bridge id)kSecReturnAttributes, kCFBooleanTrue,
									 (__bridge id)kSecReturnData, (__bridge id)kSecMatchLimitAll,
									 (__bridge id)kSecMatchLimit, nil];

	CFTypeRef results = NULL;
	OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef)query, &results);

	if (err == noErr && results) {
		NSArray *items = (__bridge NSArray *)results;
		for (NSDictionary *item in items) {
			NSData *passwordData = [item objectForKey:(__bridge id)kSecValueData];
			NSString *accountStr = [item objectForKey:(__bridge id)kSecAttrAccount];
			if (accountStr && passwordData) {
				NSString *password = [[NSString alloc] initWithData:passwordData encoding:NSUTF8StringEncoding];
				result =
					[NSDictionary dictionaryWithObjectsAndKeys:accountStr, @"Username", password, @"Password", nil];
				break; /* take first match, like the old SecKeychainSearchCopyNext did */
			}
		}
		CFRelease(results);
	} else {
		if (err == errSecItemNotFound) {
			err = noErr; /* not-found is not an error for this method */
		}
	}

	if (outError)
		*outError = AIKeychainErrorFromStatus(err, @"SecItemCopyMatching");
	return result;
}

#pragma mark -

- (BOOL)setInternetPassword:(NSString *)password
				  forServer:(NSString *)server
			 securityDomain:(NSString *)domain
					account:(NSString *)account
					   path:(NSString *)path
					   port:(u_int16_t)port
				   protocol:(SecProtocolType)protocol
		 authenticationType:(SecAuthenticationType)authType
			   keychainItem:(out SecKeychainItemRef *)outKeychainItem
					  error:(out NSError **)outError
{
	NSString *protocolStr = AIKeychainProtocolString(protocol);

	if (!password) {
		/* Remove the password */
		@autoreleasepool {
			OSStatus err = AIKeychainDeletePassword(server, account, protocolStr, path, port, domain, authType);
			if (outError)
				*outError = AIKeychainErrorFromStatus(err, @"SecItemDelete");
			if (outKeychainItem)
				*outKeychainItem = NULL;
			return (err == noErr || err == errSecItemNotFound);
		}
	}

	/* Try to add; if duplicate, update instead */
	@autoreleasepool {
		OSStatus err = AIKeychainAddPassword(server, account, protocolStr, path, port, domain, authType, password);

		if (err == errSecDuplicateItem) {
			err = AIKeychainUpdatePassword(server, account, protocolStr, path, port, domain, authType, password);
		}

		if (outError)
			*outError = AIKeychainErrorFromStatus(err, @"SecItemAdd/Update");
		if (outKeychainItem)
			*outKeychainItem = NULL;
		return (err == noErr);
	}
}

- (BOOL)setInternetPassword:(NSString *)password
				  forServer:(NSString *)server
					account:(NSString *)account
				   protocol:(SecProtocolType)protocol
					  error:(out NSError **)outError
{
	return [self setInternetPassword:password
						   forServer:server
					  securityDomain:nil
							 account:account
								path:nil
								port:0
							protocol:protocol
				  authenticationType:kSecAuthenticationTypeDefault
						keychainItem:NULL
							   error:outError];
}

#pragma mark -

- (BOOL)deleteInternetPasswordForServer:(NSString *)server
						 securityDomain:(NSString *)domain
								account:(NSString *)account
								   path:(NSString *)path
								   port:(u_int16_t)port
							   protocol:(SecProtocolType)protocol
					 authenticationType:(SecAuthenticationType)authType
						   keychainItem:(out SecKeychainItemRef *)outKeychainItem
								  error:(out NSError **)outError
{
	@autoreleasepool {

		NSString *protocolStr = AIKeychainProtocolString(protocol);
		OSStatus err = AIKeychainDeletePassword(server, account, protocolStr, path, port, domain, authType);

		if (outError)
			*outError = AIKeychainErrorFromStatus(err, @"SecItemDelete");
		if (outKeychainItem)
			*outKeychainItem = NULL;
		return (err == noErr || err == errSecItemNotFound);
	}
}

- (BOOL)deleteInternetPasswordForServer:(NSString *)server
								account:(NSString *)account
							   protocol:(SecProtocolType)protocol
								  error:(out NSError **)outError
{
	return [self deleteInternetPasswordForServer:server
								  securityDomain:nil
										 account:account
											path:nil
											port:0
										protocol:protocol
							  authenticationType:kSecAuthenticationTypeDefault
									keychainItem:NULL
										   error:outError];
}

#pragma mark - Generic Passwords

- (BOOL)addGenericPassword:(NSString *)password
				forService:(NSString *)service
				   account:(NSString *)account
			  keychainItem:(out SecKeychainItemRef *)outKeychainItem
					 error:(out NSError **)outError
{
	@autoreleasepool {

		NSDictionary *attrs = [NSDictionary
			dictionaryWithObjectsAndKeys:(__bridge id)kSecClassGenericPassword, (__bridge id)kSecClass, service,
										 (__bridge id)kSecAttrService, account, (__bridge id)kSecAttrAccount,
										 [password dataUsingEncoding:NSUTF8StringEncoding], (__bridge id)kSecValueData,
										 nil];

		OSStatus err = SecItemAdd((__bridge CFDictionaryRef)attrs, NULL);

		if (outError)
			*outError = AIKeychainErrorFromStatus(err, @"SecItemAdd");
		if (outKeychainItem)
			*outKeychainItem = NULL;
		return (err == noErr);
	}
}

- (NSString *)findGenericPasswordForService:(NSString *)service
									account:(NSString *)account
							   keychainItem:(out SecKeychainItemRef *)outKeychainItem
									  error:(out NSError **)outError
{
	NSDictionary *query = [NSDictionary
		dictionaryWithObjectsAndKeys:(__bridge id)kSecClassGenericPassword, (__bridge id)kSecClass, service,
									 (__bridge id)kSecAttrService, account, (__bridge id)kSecAttrAccount,
									 kCFBooleanTrue, (__bridge id)kSecReturnData, nil];

	CFTypeRef result = NULL;
	OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);

	NSString *password = nil;
	if (err == noErr && result) {
		password = [[NSString alloc] initWithData:(__bridge NSData *)result encoding:NSUTF8StringEncoding];
		CFRelease(result);
	}

	if (outError)
		*outError = AIKeychainErrorFromStatus(err, @"SecItemCopyMatching");
	if (outKeychainItem)
		*outKeychainItem = NULL;
	return password;
}

- (BOOL)deleteGenericPasswordForService:(NSString *)service account:(NSString *)account error:(out NSError **)outError
{
	NSDictionary *query = [NSDictionary
		dictionaryWithObjectsAndKeys:(__bridge id)kSecClassGenericPassword, (__bridge id)kSecClass, service,
									 (__bridge id)kSecAttrService, account, (__bridge id)kSecAttrAccount, nil];

	OSStatus err = SecItemDelete((__bridge CFDictionaryRef)query);

	if (outError)
		*outError = AIKeychainErrorFromStatus(err, @"SecItemDelete");
	return (err == noErr || err == errSecItemNotFound);
}

#pragma mark -

- (SecKeychainRef)keychainRef
{
	return keychainRef;
}

#pragma mark -

- (NSString *)description
{
	return [NSString stringWithFormat:@"<AIKeychain %p>", self];
}

- (void)dealloc
{
	if (keychainRef) {
		CFRelease(keychainRef);
	}
}

@end