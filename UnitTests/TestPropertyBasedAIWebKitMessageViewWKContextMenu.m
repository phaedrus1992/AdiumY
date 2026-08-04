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
#import "AIWebKitMessageViewWKContextMenu.h"
#import <XCTest/XCTest.h>

@interface TestPropertyBasedAIWebKitMessageViewWKContextMenu : XCTestCase
@end

@implementation TestPropertyBasedAIWebKitMessageViewWKContextMenu

// The contextMenu body carries numeric x/y coordinates; a non-numeric value must
// never reach the doubleValue that feeds the pop-up position. Covered by #152.
- (void)testNumericCoordinatesAreRequired
{
	AIWKContextMenuMessage message = AIWKContextMenuMessageFromBody(@{
		@"type" : @"contextMenu",
		@"x" : @"12", // string, not NSNumber
		@"y" : @(8),
	});
	XCTAssertFalse(message.valid);

	message = AIWKContextMenuMessageFromBody(@{
		@"type" : @"contextMenu",
		@"x" : [NSNull null],
		@"y" : @(8),
	});
	XCTAssertFalse(message.valid);
}

// The type must be exactly the string "contextMenu".
- (void)testWrongTypeIsRejected
{
	XCTAssertFalse(AIWKContextMenuMessageFromBody(@{@"type" : @"ready", @"x" : @(1), @"y" : @(2)}).valid);
	XCTAssertFalse(AIWKContextMenuMessageFromBody(@{@"type" : @(1), @"x" : @(1), @"y" : @(2)}).valid);
	XCTAssertFalse(AIWKContextMenuMessageFromBody(@{@"x" : @(1), @"y" : @(2)}).valid);
}

// A non-dictionary body (e.g. a page posting a plain string) is rejected, not crashed on.
- (void)testNonDictionaryBodyIsRejected
{
	XCTAssertFalse(AIWKContextMenuMessageFromBody(@"garbage").valid);
	XCTAssertFalse(AIWKContextMenuMessageFromBody(@[ @"a", @"b" ]).valid);
	XCTAssertFalse(AIWKContextMenuMessageFromBody(nil).valid);
}

// An absent or empty imageURL normalizes to nil, never an empty string.
- (void)testEmptyImageURLNormalizesToNil
{
	AIWKContextMenuMessage message = AIWKContextMenuMessageFromBody(@{
		@"type" : @"contextMenu",
		@"x" : @(12.5),
		@"y" : @(8),
		@"imageURL" : @"",
	});
	XCTAssertTrue(message.valid);
	XCTAssertNil(message.imageURLString);

	message = AIWKContextMenuMessageFromBody(@{@"type" : @"contextMenu", @"x" : @(12.5), @"y" : @(8)});
	XCTAssertTrue(message.valid);
	XCTAssertNil(message.imageURLString);
}

// A non-string imageURL is ignored (treated as no image), like the pre-extraction code.
- (void)testNonStringImageURLIsIgnored
{
	AIWKContextMenuMessage message = AIWKContextMenuMessageFromBody(@{
		@"type" : @"contextMenu",
		@"x" : @(1),
		@"y" : @(2),
		@"imageURL" : @(5),
	});
	XCTAssertTrue(message.valid);
	XCTAssertNil(message.imageURLString);
}

/// Property: A generated JS body parses to valid exactly when it carries a "contextMenu"
/// type with numeric x/y, and the parsed values round-trip the body.
- (void)testContextMenuBodyParsingProperty
{
	PBTCheckDefault({
		id body = PBTRandomJSBodyDictionary();
		AIWKContextMenuMessage message = AIWKContextMenuMessageFromBody(body);

		BOOL expectedValid = NO;
		if ([body isKindOfClass:[NSDictionary class]]) {
			NSDictionary *dict = (NSDictionary *)body;
			expectedValid = [[dict objectForKey:@"type"] isKindOfClass:[NSString class]] &&
							[[dict objectForKey:@"type"] isEqualToString:@"contextMenu"] &&
							[[dict objectForKey:@"x"] isKindOfClass:[NSNumber class]] &&
							[[dict objectForKey:@"y"] isKindOfClass:[NSNumber class]];
		}

		XCTAssertEqual(message.valid, expectedValid, @"body = %@", body);
		if (expectedValid) {
			XCTAssertEqualWithAccuracy(message.x, [[(NSDictionary *)body objectForKey:@"x"] doubleValue], 0.0001,
									   @"body = %@", body);
			XCTAssertEqualWithAccuracy(message.y, [[(NSDictionary *)body objectForKey:@"y"] doubleValue], 0.0001,
									   @"body = %@", body);
			id imageURL = [(NSDictionary *)body objectForKey:@"imageURL"];
			if ([imageURL isKindOfClass:[NSString class]] && [imageURL length] > 0) {
				XCTAssertEqualObjects(message.imageURLString, imageURL, @"body = %@", body);
			} else {
				XCTAssertNil(message.imageURLString, @"body = %@", body);
			}
		}
	});
}

/// Property: AIWKImageURLFromString agrees with +[NSURL URLWithString:] on arbitrary strings.
- (void)testImageURLFromStringMatchesURLWithString
{
	PBTCheckDefault({
		NSString *s = PBTRandomASCIIString(64);
		XCTAssertEqualObjects(AIWKImageURLFromString(s), [NSURL URLWithString:s], @"string = %@", s);
	});
}

// nil input yields nil, never a crash.
- (void)testImageURLFromStringNil
{
	XCTAssertNil(AIWKImageURLFromString(nil));
}

// file: and http(s) URLs offer Save Image As; other schemes and nil do not.
- (void)testCanSaveImageURLBranches
{
	XCTAssertTrue(AIWKCanSaveImageURL([NSURL fileURLWithPath:@"/tmp/pic.png"]));
	XCTAssertTrue(AIWKCanSaveImageURL([NSURL URLWithString:@"https://example.com/pic.png"]));
	XCTAssertTrue(AIWKCanSaveImageURL([NSURL URLWithString:@"http://example.com/pic.png"]));
	XCTAssertFalse(AIWKCanSaveImageURL([NSURL URLWithString:@"ftp://example.com/pic.png"]));
	XCTAssertFalse(AIWKCanSaveImageURL([NSURL URLWithString:@"data:image/png;base64,AAAA"]));
	XCTAssertFalse(AIWKCanSaveImageURL([NSURL URLWithString:@"notaurl"]));
	XCTAssertFalse(AIWKCanSaveImageURL(nil));
}

/// Property: A random non-file/non-http(s) scheme is never savable.
- (void)testRandomSchemeNotSavable
{
	PBTCheckDefault({
		// Appending "x" guarantees the scheme never collides with file/http/https.
		NSString *scheme = [[PBTRandomASCIIString(8) lowercaseString] stringByAppendingString:@"x"];
		NSURL *url = [NSURL URLWithString:[scheme stringByAppendingString:@"://host/pic.png"]];
		if (url != nil) {
			XCTAssertFalse(AIWKCanSaveImageURL(url), @"scheme = %@", scheme);
		}
	});
}

@end
