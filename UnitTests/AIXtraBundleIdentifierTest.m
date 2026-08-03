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

#import "AIXtraBundleIdentifier.h"
#import "AIPropertyTestUtilities.h"
#import <XCTest/XCTest.h>

@interface AIXtraBundleIdentifierTest : XCTestCase
@end

@implementation AIXtraBundleIdentifierTest

/// Property: For any ASCII name, the identifier is exactly the bundle-ID prefix plus the name.
- (void)testIdentifierIsPrefixPlusName
{
	PBTCheckDefault({
		NSString *name = PBTRandomASCIIString(24);
		NSString *expected = [@"com.github.phaedrus1992.adiumy." stringByAppendingString:name];
		XCTAssertEqualObjects(AIXtraBundleIdentifierForName(name), expected, @"name = %@", name);
	});
}

/// Property: Unicode names pass through unchanged (identifiers are built, not sanitized).
- (void)testIdentifierPassesThroughUnicodeNames
{
	PBTCheckDefault({
		NSString *name = PBTRandomUnicodeString(16);
		NSString *expected = [@"com.github.phaedrus1992.adiumy." stringByAppendingString:name];
		XCTAssertEqualObjects(AIXtraBundleIdentifierForName(name), expected, @"name = %@", name);
	});
}

/// Property: Repeated calls with the same name produce the same identifier.
- (void)testIdentifierIsDeterministic
{
	PBTCheckDefault({
		NSString *name = PBTRandomASCIIString(24);
		XCTAssertEqualObjects(AIXtraBundleIdentifierForName(name), AIXtraBundleIdentifierForName(name), @"name = %@",
							  name);
	});
}

/// Property: The result always carries the AdiumY bundle-ID prefix.
- (void)testIdentifierAlwaysHasAdiumYPrefix
{
	PBTCheckDefault({
		NSString *name = PBTRandomASCIIString(24);
		XCTAssertTrue([AIXtraBundleIdentifierForName(name) hasPrefix:@"com.github.phaedrus1992.adiumy."], @"name = %@",
					  name);
	});
}

// Edge: an empty name yields the bare prefix.
- (void)testEmptyNameYieldsBarePrefix
{
	XCTAssertEqualObjects(AIXtraBundleIdentifierForName(@""), @"com.github.phaedrus1992.adiumy.");
}

// Edge: a nil name yields nil.
- (void)testNilNameYieldsNil
{
	XCTAssertNil(AIXtraBundleIdentifierForName(nil));
}

@end
