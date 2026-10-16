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
#import "AIPropertyTestUtilities.h"
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

static AIOTRIdentityMigration *TestMigrationWithIndex(NSUInteger index)
{
	return TestMigration([NSString stringWithFormat:@"legacy-%lu", (unsigned long)index],
						 [NSString stringWithFormat:@"current-%lu", (unsigned long)index],
						 [NSString stringWithFormat:@"protocol-%lu", (unsigned long)index],
						 [NSString stringWithFormat:@"prpl-%lu", (unsigned long)index]);
}

// A generated field never contains a tab or a newline, so it stays inside its
// own store column.
static NSString *TestRandomField(void)
{
	NSString *field = PBTRandomASCIIString(8);
	field = [field stringByReplacingOccurrencesOfString:@"\t" withString:@""];
	field = [field stringByReplacingOccurrencesOfString:@"\n" withString:@""];
	return [field stringByReplacingOccurrencesOfString:@"\r" withString:@""];
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

- (void)testMigratesInstagStore
{
	NSString *store = @"# WARNING! You shouldn't copy this file to another computer.\n"
					   "service.abc\tservice\t00000001\n"
					   "other.xyz\tother\t00000002\n";
	NSUInteger changed = 0;

	NSString *result = AIOTRMigratedInstagStoreText(
		store, @[ TestMigration(@"service.abc", @"abc", @"service", @"prpl-service") ], &changed);

	NSString *expected = @"# WARNING! You shouldn't copy this file to another computer.\n"
						  "abc\tprpl-service\t00000001\n"
						  "other.xyz\tother\t00000002\n";
	XCTAssertEqualObjects(result, expected, @"The comment and unmatched lines pass through.");
	XCTAssertEqual(changed, (NSUInteger)1, @"One line changed.");
}

- (void)testLeavesShortInstagLineAlone
{
	NSString *store = @"service.abc\tservice\n";

	NSString *result = AIOTRMigratedInstagStoreText(
		store, @[ TestMigration(@"service.abc", @"abc", @"service", @"prpl-service") ], NULL);

	XCTAssertEqualObjects(result, store, @"A line without a tag field does not change.");
}

// Property: a store whose account fields match no migration is returned byte
// for byte, whatever the line shapes (empty lines, short lines, stray tabs).
- (void)testGeneratedNonMatchingStoresPassThroughByteForByte
{
	PBTCheckDefault({
		NSMutableArray<NSString *> *lines = [NSMutableArray array];
		NSUInteger lineCount = PBTUniform(6);
		for (NSUInteger i = 0; i < lineCount; i++) {
			NSUInteger fieldCount = PBTUniform(7);
			NSMutableArray<NSString *> *fields = [NSMutableArray array];
			for (NSUInteger field = 0; field < fieldCount; field++) {
				[fields addObject:TestRandomField()];
			}
			if (fieldCount >= 2) {
				// Every account field carries a "nomatch." prefix, so no line
				// can collide with a migration's legacy name.
				fields[1] = [@"nomatch." stringByAppendingString:fields[1]];
			}
			[lines addObject:[fields componentsJoinedByString:@"\t"]];
		}

		NSString *store = [lines componentsJoinedByString:@"\n"];
		if (PBTRandomBool()) {
			store = [store stringByAppendingString:@"\n"];
		}

		NSUInteger changed = 123;
		NSString *result = AIOTRMigratedFingerprintStoreText(store, @[ TestMigrationWithIndex(1) ], &changed);

		XCTAssertEqualObjects(result, store, @"A store with no matching account passes through byte for byte.");
		XCTAssertEqual(changed, (NSUInteger)0, @"No line changed.");
	});
}

// Property: the rewrite changes exactly the account and protocol fields; the
// field count and every other field survive.
- (void)testRewriteKeepsFieldCountAndChangesOnlyIdentityFields
{
	AIOTRIdentityMigration *migration = TestMigrationWithIndex(1);
	PBTCheckDefault({
		NSUInteger fieldCount = 4 + PBTUniform(4);
		NSMutableArray<NSString *> *fields = [NSMutableArray array];
		for (NSUInteger field = 0; field < fieldCount; field++) {
			[fields addObject:TestRandomField()];
		}
		fields[1] = migration.legacyAccountName;
		fields[2] = PBTRandomBool() ? migration.legacyProtocol : TestRandomField();
		NSString *line = [fields componentsJoinedByString:@"\t"];
		BOOL protocolWasLegacy = [fields[2] isEqualToString:migration.legacyProtocol];

		NSUInteger changed = 0;
		NSString *result = AIOTRMigratedFingerprintStoreText(line, @[ migration ], &changed);
		NSArray<NSString *> *resultFields = [result componentsSeparatedByString:@"\t"];

		XCTAssertEqual([resultFields count], fieldCount, @"The field count survives the rewrite.");
		XCTAssertEqualObjects(resultFields[1], migration.currentAccountName,
							  @"The account field becomes the current account name.");
		XCTAssertEqualObjects(resultFields[2], protocolWasLegacy ? migration.currentProtocol : fields[2],
							  @"The protocol field changes only when it held the legacy protocol.");
		for (NSUInteger field = 0; field < fieldCount; field++) {
			if (field != 1 && field != 2) {
				XCTAssertEqualObjects(resultFields[field], fields[field], @"Only the identity fields change.");
			}
		}
		XCTAssertEqual(changed, (NSUInteger)1, @"One line changed.");
	});
}

// Property: running the migration twice equals running it once, which the
// every-launch call site relies on.
- (void)testMigrationIsIdempotentOverGeneratedStores
{
	NSArray<AIOTRIdentityMigration *> *migrations = @[ TestMigrationWithIndex(1), TestMigrationWithIndex(2) ];
	PBTCheckDefault({
		NSMutableArray<NSString *> *lines = [NSMutableArray array];
		NSUInteger lineCount = 1 + PBTUniform(6);
		for (NSUInteger i = 0; i < lineCount; i++) {
			NSMutableArray<NSString *> *fields = [NSMutableArray array];
			for (NSUInteger field = 0; field < 4; field++) {
				[fields addObject:TestRandomField()];
			}
			fields[1] = migrations[PBTUniform(2)].legacyAccountName;
			[lines addObject:[fields componentsJoinedByString:@"\t"]];
		}
		NSString *store = [lines componentsJoinedByString:@"\n"];

		NSUInteger firstChanged = 0;
		NSString *once = AIOTRMigratedFingerprintStoreText(store, migrations, &firstChanged);
		NSUInteger secondChanged = 123;
		NSString *twice = AIOTRMigratedFingerprintStoreText(once, migrations, &secondChanged);

		XCTAssertEqualObjects(twice, once, @"The second pass changes nothing.");
		XCTAssertEqual(secondChanged, (NSUInteger)0, @"The second pass reports no changed lines.");
		XCTAssertEqual(firstChanged, lineCount, @"The first pass changes every generated line.");
	});
}

// Property: the returned count equals the number of rewritten lines, and it is
// zero exactly when the store is returned unchanged.
- (void)testChangedCountMatchesRewrittenLines
{
	NSArray<AIOTRIdentityMigration *> *migrations = @[ TestMigrationWithIndex(1), TestMigrationWithIndex(2) ];
	PBTCheckDefault({
		NSMutableArray<NSString *> *lines = [NSMutableArray array];
		NSUInteger matchingLines = 0;
		NSUInteger lineCount = 1 + PBTUniform(6);
		for (NSUInteger i = 0; i < lineCount; i++) {
			NSMutableArray<NSString *> *fields = [NSMutableArray array];
			for (NSUInteger field = 0; field < 4; field++) {
				[fields addObject:TestRandomField()];
			}
			if (PBTRandomBool()) {
				fields[1] = migrations[PBTUniform(2)].legacyAccountName;
				matchingLines++;
			} else {
				fields[1] = [@"nomatch." stringByAppendingString:fields[1]];
			}
			[lines addObject:[fields componentsJoinedByString:@"\t"]];
		}
		NSString *store = [lines componentsJoinedByString:@"\n"];

		NSUInteger changed = 0;
		NSString *result = AIOTRMigratedFingerprintStoreText(store, migrations, &changed);

		XCTAssertEqual(changed, matchingLines, @"The count equals the number of rewritten lines.");
		XCTAssertEqual([result isEqualToString:store], (changed == 0), @"A zero count means an unchanged store.");
	});
}

@end
