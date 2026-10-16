/*
 * Adium is the property of its developers, whose names are listed in the copyright file included
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// One account's libotr identity strings, before and after the #403 change. The
/// stored contexts, fingerprints, and private keys still carry the old pair, so
/// the stored files need a rewrite to keep the user's identity (#413).
@interface AIOTRIdentityMigration : NSObject

/// The account name libotr stored before #403 (serviceID.internalObjectID).
@property(nonatomic, copy, readonly) NSString *legacyAccountName;
/// The account name libotr stores now (the account's internalObjectID).
@property(nonatomic, copy, readonly) NSString *currentAccountName;
/// The protocol string libotr stored before #403 (the serviceID).
@property(nonatomic, copy, readonly) NSString *legacyProtocol;
/// The protocol string libotr stores now (the serviceCodeUniqueID).
@property(nonatomic, copy, readonly) NSString *currentProtocol;

/// Creates one account's before/after identity strings.
///
/// @param legacyAccountName The pre-#403 account name.
/// @param currentAccountName The current account name.
/// @param legacyProtocol The pre-#403 protocol string.
/// @param currentProtocol The current protocol string.
- (instancetype)initWithLegacyAccountName:(NSString *)legacyAccountName
					   currentAccountName:(NSString *)currentAccountName
						   legacyProtocol:(NSString *)legacyProtocol
						  currentProtocol:(NSString *)currentProtocol NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

/// Rewrites the store lines whose account field matches a migration's
/// legacyAccountName: the account field becomes currentAccountName, and the protocol
/// field becomes currentProtocol when it still holds legacyProtocol. Every other line,
/// and every field of an unmatched line, stays as it was.
///
/// @param storeText The whole fingerprints store. Each line holds
///        user, account, protocol, and fingerprint fields, separated by tabs,
///        with an optional trust field.
/// @param migrations One record for each account that needs a new identity.
/// @param changedLineCount On return, the count of lines with changed fields.
///        Pass NULL if the count is not needed.
/// @return The rewritten store. The result equals storeText when no line matched.
NSString *AIOTRMigratedFingerprintStoreText(NSString *storeText, NSArray<AIOTRIdentityMigration *> *migrations,
											NSUInteger *_Nullable changedLineCount);

NS_ASSUME_NONNULL_END
