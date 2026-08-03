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

#import "AIPropertyTestUtilities.h"
#import "AIWebkitMessageStylePreferenceMigration.h"
#import <XCTest/XCTest.h>

@interface MessageStylePreferenceMigrationTest : XCTestCase
@end

@implementation MessageStylePreferenceMigrationTest

// A legacy pre-1.4 style ID is upgraded to the fork's shipped bundle ID.
- (void)testUpgradesLegacyStylePreference
{
	NSDictionary *prefs = @{@"Message Style" : @"com.adiumx.gonedark.style"};
	NSDictionary *delta = AIWebkitMessageStylePreferenceMigration(prefs);
	XCTAssertNotNil(delta);
	XCTAssertEqualObjects(delta[@"Message Style"], @"com.github.phaedrus1992.adiumy.gonedark.style");
}

// The third-party yMous style ID is upgraded, preserving its camelCase suffix.
- (void)testUpgradesThirdPartyYMousStylePreference
{
	NSDictionary *prefs = @{@"Message Style" : @"mathuaerknedam.yMous.style"};
	NSDictionary *delta = AIWebkitMessageStylePreferenceMigration(prefs);
	XCTAssertNotNil(delta);
	XCTAssertEqualObjects(delta[@"Message Style"], @"com.github.phaedrus1992.adiumy.yMous.style");
}

// A complete style change ("eclipse" was renamed to Gone Dark) is upgraded.
- (void)testUpgradesCompleteStyleChange
{
	NSDictionary *prefs = @{@"Message Style" : @"com.adiumx.eclipse.style"};
	NSDictionary *delta = AIWebkitMessageStylePreferenceMigration(prefs);
	XCTAssertNotNil(delta);
	XCTAssertEqualObjects(delta[@"Message Style"], @"com.github.phaedrus1992.adiumy.gonedark.style");
}

// The current style ID is never downgraded: a fork-style ID is not a conversion key.
- (void)testCurrentStyleIdIsNotDowngraded
{
	NSDictionary *prefs = @{@"Message Style" : @"com.github.phaedrus1992.adiumy.gonedark.style"};
	XCTAssertNil(AIWebkitMessageStylePreferenceMigration(prefs));
}

/// Property: A preference key prefixed by a legacy bundle ID is remapped to the fork bundle ID,
/// and the obsolete key is marked for deletion.
- (void)testRemapsPrefixedPreferenceKeys
{
	PBTCheckDefault({
		NSString *suffix = PBTRandomASCIIString(12);
		NSString *oldKey = [@"com.adiumx.renkoo.style." stringByAppendingString:suffix];
		NSString *value = PBTRandomASCIIString(16);
		NSDictionary *delta = AIWebkitMessageStylePreferenceMigration(@{oldKey : value});
		XCTAssertNotNil(delta, @"oldKey = %@", oldKey);
		NSString *newKey = [@"com.github.phaedrus1992.adiumy.renkoo.style." stringByAppendingString:suffix];
		XCTAssertEqualObjects(delta[newKey], value, @"oldKey = %@", oldKey);
		XCTAssertEqual((id)delta[oldKey], (id)NSNull.null, @"oldKey = %@", oldKey);
	});
}

/// Property: Keys prefixed by the third-party yMous bundle ID are remapped with camelCase preserved.
- (void)testRemapsYMousPrefixedKeys
{
	PBTCheckDefault({
		NSString *suffix = PBTRandomASCIIString(12);
		NSString *oldKey = [@"mathuaerknedam.yMous.style." stringByAppendingString:suffix];
		NSString *value = PBTRandomASCIIString(16);
		NSDictionary *delta = AIWebkitMessageStylePreferenceMigration(@{oldKey : value});
		XCTAssertNotNil(delta, @"oldKey = %@", oldKey);
		NSString *newKey = [@"com.github.phaedrus1992.adiumy.yMous.style." stringByAppendingString:suffix];
		XCTAssertEqualObjects(delta[newKey], value, @"oldKey = %@", oldKey);
		XCTAssertEqual((id)delta[oldKey], (id)NSNull.null, @"oldKey = %@", oldKey);
	});
}

// The delta contains only changed keys; untouched keys never appear.
- (void)testDeltaContainsOnlyChanges
{
	NSDictionary *prefs = @{
		@"com.adiumx.minimal.style.FontColor" : @"#fff",
		@"Unrelated Key" : @"keep me",
	};
	NSDictionary *delta = AIWebkitMessageStylePreferenceMigration(prefs);
	XCTAssertNotNil(delta);
	XCTAssertEqualObjects(delta[@"com.github.phaedrus1992.adiumy.minimal_mod.style.FontColor"], @"#fff");
	XCTAssertEqual((id)delta[@"com.adiumx.minimal.style.FontColor"], (id)NSNull.null);
	XCTAssertNil(delta[@"Unrelated Key"]);
	XCTAssertEqual((NSUInteger)[delta count], (NSUInteger)2);
}

/// Property: A dict with nothing to migrate yields nil.
- (void)testNoChangeYieldsNil
{
	PBTCheckDefault({
		NSDictionary *prefs = PBTRandomStringDictionary(8);
		XCTAssertNil(AIWebkitMessageStylePreferenceMigration(prefs));
	});
}

// Already-migrated prefs (fork-style IDs) yield nil — migration is idempotent.
- (void)testAlreadyMigratedPrefsYieldNil
{
	NSDictionary *prefs = @{
		@"Message Style" : @"com.github.phaedrus1992.adiumy.gonedark.style",
		@"com.github.phaedrus1992.adiumy.gonedark.style.HeaderPref" : @"x",
	};
	XCTAssertNil(AIWebkitMessageStylePreferenceMigration(prefs));
}

/// Property: The migration is deterministic for a given input.
- (void)testMigrationIsDeterministic
{
	PBTCheckDefault({
		NSString *suffix = PBTRandomASCIIString(16);
		NSString *oldKey = [@"com.adiumx.stockholm.style." stringByAppendingString:suffix];
		// Build the dict with statements, not a multi-entry literal: PBTCheckDefault's
		// block argument is a braced group, and the preprocessor would split on a
		// top-level comma inside it.
		NSMutableDictionary *prefs = [NSMutableDictionary dictionary];
		prefs[oldKey] = PBTRandomASCIIString(8);
		prefs[@"Message Style"] = @"com.adiumx.mockie.style";
		NSDictionary *a = AIWebkitMessageStylePreferenceMigration(prefs);
		NSDictionary *b = AIWebkitMessageStylePreferenceMigration(prefs);
		XCTAssertEqualObjects(a, b);
	});
}

@end
