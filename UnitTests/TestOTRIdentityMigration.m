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

#import "AIOTRIdentityMigration.h"
#import <XCTest/XCTest.h>

/*
 * Regression tests for #413's fingerprints-store migration. The store still carries the
 * pre-#403 identity strings, so without this rewrite every stored fingerprint misses
 * and each peer verification is redone once, and a fresh key is generated.
 */
@interface OTRIdentityMigrationTest : XCTestCase
@end

static NSString *const OldFingerprintHex = @"0011223344556677889900112233445566778899";

static AIOTRIdentityMigration *TestMigration(NSString *legacyAccountName, NSString *currentAccountName,
											 NSString *legacyProtocol, NSString *currentProtocol)
{
	return [[AIOTRIdentityMigration alloc] initWithLegacyAccountName:legacyAccountName
												  currentAccountName:currentAccountName
													  legacyProtocol:legacyProtocol
													 currentProtocol:currentProtocol];
}

@implementation OTRIdentityMigrationTest

- (void)testRewritesAccountAndProtocolForOldIdentity
{
	NSString *store = [NSString stringWithFormat:@"alice\tservice.abc\tservice\t%@\tverified\n", OldFingerprintHex];
	NSUInteger changed = 0;

	NSString *result = AIOTRMigratedFingerprintStoreText(
		store, @[ TestMigration(@"service.abc", @"abc", @"service", @"prpl-service") ], &changed);

	NSString *expected = [NSString stringWithFormat:@"alice\tabc\tprpl-service\t%@\tverified\n", OldFingerprintHex];
	XCTAssertEqualObjects(result, expected, @"The account and protocol fields get the new identity.");
	XCTAssertEqual(changed, (NSUInteger)1, @"One line changed.");
}

- (void)testLeavesLineWithCurrentIdentityAlone
{
	NSString *store = [NSString stringWithFormat:@"alice\tabc\tprpl-service\t%@\tverified\n", OldFingerprintHex];
	NSUInteger changed = 0;

	NSString *result = AIOTRMigratedFingerprintStoreText(
		store, @[ TestMigration(@"service.abc", @"abc", @"service", @"prpl-service") ], &changed);

	XCTAssertEqualObjects(result, store, @"A line with the new identity does not change.");
	XCTAssertEqual(changed, (NSUInteger)0, @"No line changed.");
}

- (void)testLeavesLineForUnknownAccountAlone
{
	NSString *store = [NSString stringWithFormat:@"bob\tother.xyz\tother\t%@\n", OldFingerprintHex];
	NSUInteger changed = 0;

	NSString *result = AIOTRMigratedFingerprintStoreText(
		store, @[ TestMigration(@"service.abc", @"abc", @"service", @"prpl-service") ], &changed);

	XCTAssertEqualObjects(result, store, @"An account with no migration record does not change.");
	XCTAssertEqual(changed, (NSUInteger)0, @"No line changed.");
}

- (void)testKeepsLineWithoutTrustFieldAtFourFields
{
	NSString *store = [NSString stringWithFormat:@"alice\tservice.abc\tservice\t%@\n", OldFingerprintHex];
	NSUInteger changed = 0;

	NSString *result = AIOTRMigratedFingerprintStoreText(
		store, @[ TestMigration(@"service.abc", @"abc", @"service", @"prpl-service") ], &changed);

	NSString *expected = [NSString stringWithFormat:@"alice\tabc\tprpl-service\t%@\n", OldFingerprintHex];
	XCTAssertEqualObjects(result, expected, @"A line without a trust field stays at four fields.");
	XCTAssertEqual(changed, (NSUInteger)1, @"One line changed.");
}

- (void)testLeavesMalformedLineAlone
{
	NSString *store = @"alice\tservice.abc\n";

	NSString *result = AIOTRMigratedFingerprintStoreText(
		store, @[ TestMigration(@"service.abc", @"abc", @"service", @"prpl-service") ], NULL);

	XCTAssertEqualObjects(result, store, @"A line with too few fields does not change.");
}

- (void)testRewritesEveryMatchingLineInStore
{
	NSString *store = [NSString stringWithFormat:@"alice\tservice.abc\tservice\t%@\n"
												  "bob\tother.xyz\tother\t%@\n"
												  "carol\tjabber.def\tjabber\t%@\t\n",
												 OldFingerprintHex, OldFingerprintHex, OldFingerprintHex];
	NSUInteger changed = 0;

	NSString *result =
		AIOTRMigratedFingerprintStoreText(store,
										  @[
											  TestMigration(@"service.abc", @"abc", @"service", @"prpl-service"),
											  TestMigration(@"jabber.def", @"def", @"jabber", @"prpl-jabber")
										  ],
										  &changed);

	NSString *expected = [NSString stringWithFormat:@"alice\tabc\tprpl-service\t%@\n"
													 "bob\tother.xyz\tother\t%@\n"
													 "carol\tdef\tprpl-jabber\t%@\t\n",
													OldFingerprintHex, OldFingerprintHex, OldFingerprintHex];
	XCTAssertEqualObjects(result, expected, @"Each line with a migration record gets the new identity.");
	XCTAssertEqual(changed, (NSUInteger)2, @"Two lines changed.");
}

- (void)testKeepsLineWithoutTrailingNewline
{
	NSString *store = [NSString stringWithFormat:@"alice\tservice.abc\tservice\t%@", OldFingerprintHex];

	NSString *result = AIOTRMigratedFingerprintStoreText(
		store, @[ TestMigration(@"service.abc", @"abc", @"service", @"prpl-service") ], NULL);

	NSString *expected = [NSString stringWithFormat:@"alice\tabc\tprpl-service\t%@", OldFingerprintHex];
	XCTAssertEqualObjects(result, expected, @"The last line keeps its missing newline.");
}

- (void)testEmptyStoreStaysEmpty
{
	NSUInteger changed = 123;

	NSString *result = AIOTRMigratedFingerprintStoreText(
		@"", @[ TestMigration(@"service.abc", @"abc", @"service", @"prpl-service") ], &changed);

	XCTAssertEqualObjects(result, @"", @"An empty store stays empty.");
	XCTAssertEqual(changed, (NSUInteger)0, @"No line changed.");
}

- (void)testKeepsProtocolWhenItIsNotTheRecordedOldProtocol
{
	NSString *store = [NSString stringWithFormat:@"alice\tservice.abc\tprpl-service\t%@\n", OldFingerprintHex];
	NSUInteger changed = 0;

	NSString *result = AIOTRMigratedFingerprintStoreText(
		store, @[ TestMigration(@"service.abc", @"abc", @"service", @"prpl-service") ], &changed);

	NSString *expected = [NSString stringWithFormat:@"alice\tabc\tprpl-service\t%@\n", OldFingerprintHex];
	XCTAssertEqualObjects(result, expected, @"Only a protocol field that holds the old string is rewritten.");
	XCTAssertEqual(changed, (NSUInteger)1, @"One line changed.");
}

- (void)testKeepsUserFieldVerbatim
{
	NSString *user = @"weird user:with spaces";
	NSString *store = [NSString stringWithFormat:@"%@\tservice.abc\tservice\t%@\n", user, OldFingerprintHex];
	NSUInteger changed = 0;

	NSString *result = AIOTRMigratedFingerprintStoreText(
		store, @[ TestMigration(@"service.abc", @"abc", @"service", @"prpl-service") ], &changed);

	NSString *expected = [NSString stringWithFormat:@"%@\tabc\tprpl-service\t%@\n", user, OldFingerprintHex];
	XCTAssertEqualObjects(result, expected, @"The user field passes through unchanged.");
	XCTAssertEqual(changed, (NSUInteger)1, @"One line changed.");
}

@end
