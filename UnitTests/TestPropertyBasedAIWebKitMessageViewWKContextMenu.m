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
#import <math.h>

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
			NSNumber *x = [dict objectForKey:@"x"];
			NSNumber *y = [dict objectForKey:@"y"];
			expectedValid = [[dict objectForKey:@"type"] isKindOfClass:[NSString class]] &&
							[[dict objectForKey:@"type"] isEqualToString:@"contextMenu"] &&
							[x isKindOfClass:[NSNumber class]] && [y isKindOfClass:[NSNumber class]] &&
							AIWKContextMenuCoordinateIsValid([x doubleValue]) &&
							AIWKContextMenuCoordinateIsValid([y doubleValue]);
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

// MARK: - #170: context-menu coordinate bounds

// The exposed range predicate accepts exactly [0, AIWKMaxContextMenuCoordinate] and rejects
// non-finite values (they would misposition the pop-up via NSMakePoint).
- (void)testCoordinateIsValidBoundaries
{
	XCTAssertTrue(AIWKContextMenuCoordinateIsValid(0.0));
	XCTAssertTrue(AIWKContextMenuCoordinateIsValid(AIWKMaxContextMenuCoordinate));
	XCTAssertTrue(AIWKContextMenuCoordinateIsValid(500.25));
	XCTAssertFalse(AIWKContextMenuCoordinateIsValid(-0.0001));
	XCTAssertFalse(AIWKContextMenuCoordinateIsValid(AIWKMaxContextMenuCoordinate + 0.0001));
	XCTAssertFalse(AIWKContextMenuCoordinateIsValid(INFINITY));
	XCTAssertFalse(AIWKContextMenuCoordinateIsValid(-INFINITY));
	XCTAssertFalse(AIWKContextMenuCoordinateIsValid(NAN));
}

/// Property: AIWKContextMenuCoordinateIsValid agrees with a direct bound comparison over a
/// wide double range spanning negatives, in-range, and oversized values.
- (void)testCoordinateIsValidProperty
{
	PBTCheckDefault({
		double d = ((double)PBTUniform(1000000000)) / 1000.0 - 500000.0; // -500000..500000
		BOOL expected = isfinite(d) && d >= 0.0 && d <= AIWKMaxContextMenuCoordinate;
		XCTAssertEqual(AIWKContextMenuCoordinateIsValid(d), expected, @"d = %f", d);
	});
}

// Out-of-range coordinates must be rejected, not fed to NSMakePoint.
- (void)testOutOfRangeCoordinatesAreRejected
{
	XCTAssertFalse(AIWKContextMenuMessageFromBody(@{@"type" : @"contextMenu", @"x" : @(-1), @"y" : @(5)}).valid);
	XCTAssertFalse(AIWKContextMenuMessageFromBody(@{@"type" : @"contextMenu", @"x" : @(5), @"y" : @(-0.5)}).valid);
	XCTAssertFalse(AIWKContextMenuMessageFromBody(
					   @{@"type" : @"contextMenu", @"x" : @(AIWKMaxContextMenuCoordinate + 1), @"y" : @(5)})
					   .valid);
	XCTAssertFalse(AIWKContextMenuMessageFromBody(
					   @{@"type" : @"contextMenu", @"x" : @(5), @"y" : @(AIWKMaxContextMenuCoordinate + 1)})
					   .valid);

	// The boundaries themselves are valid viewport positions.
	XCTAssertTrue(AIWKContextMenuMessageFromBody(@{@"type" : @"contextMenu", @"x" : @(0), @"y" : @(0)}).valid);
	XCTAssertTrue(
		AIWKContextMenuMessageFromBody(
			@{@"type" : @"contextMenu", @"x" : @(AIWKMaxContextMenuCoordinate), @"y" : @(AIWKMaxContextMenuCoordinate)})
			.valid);
}

// JSON true/false parse to CFBoolean-backed NSNumbers whose doubleValue is 1.0/0.0 — in
// range, but a boolean is not a coordinate. Reject them (policy decided in #170).
- (void)testBooleanCoordinatesAreRejected
{
	XCTAssertFalse(AIWKContextMenuMessageFromBody(@{@"type" : @"contextMenu", @"x" : @YES, @"y" : @(5)}).valid);
	XCTAssertFalse(AIWKContextMenuMessageFromBody(@{@"type" : @"contextMenu", @"x" : @(5), @"y" : @NO}).valid);
	XCTAssertFalse(AIWKContextMenuMessageFromBody(@{@"type" : @"contextMenu", @"x" : @NO, @"y" : @YES}).valid);
}

// MARK: - #169: default save-name computation

/// Property: The default save name is never empty and never "/" for any generated URL.
- (void)testDefaultSaveNameNeverEmptyOrSlash
{
	PBTCheckDefault({
		NSString *path = [PBTRandomASCIIString(24)
			stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
		// The comma-bearing format message-send is parenthesized: inside a PBTCheckDefault
		// block only parentheses protect commas from the macro-argument splitter.
		NSURL *url = [NSURL URLWithString:([NSString stringWithFormat:@"https://example.com/%@", path])];
		XCTAssertNotNil(url);
		NSString *name = AIWKDefaultSaveNameForURL(url, @"fallback");
		XCTAssertTrue([name length] > 0, @"path = %@", path);
		XCTAssertFalse([name isEqualToString:@"/"], @"path = %@", path);
	});
}

/// Property: A URL whose last path component is a real component (non-empty, not "/") uses it
/// as the default name.
- (void)testDefaultSaveNameUsesLastPathComponent
{
	PBTCheckDefault({
		NSCharacterSet *allowed =
			[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz"
																"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"];
		NSString *clean = [[PBTRandomASCIIString(16) componentsSeparatedByCharactersInSet:[allowed invertedSet]]
			componentsJoinedByString:@""];
		if ([clean length] == 0) {
			clean = @"image.png";
		}
		NSURL *url = [NSURL URLWithString:([NSString stringWithFormat:@"https://example.com/%@", clean])];
		XCTAssertNotNil(url);
		XCTAssertEqualObjects(AIWKDefaultSaveNameForURL(url, @"fallback"), clean, @"path = %@", clean);
	});
}

// When the URL has no real path component (empty path, root path, or nil), the fallback wins.
- (void)testDefaultSaveNameFallsBackWhenNoPathComponent
{
	XCTAssertEqualObjects(AIWKDefaultSaveNameForURL([NSURL URLWithString:@"https://example.com"], @"fallback"),
						  @"fallback");
	XCTAssertEqualObjects(AIWKDefaultSaveNameForURL([NSURL URLWithString:@"https://example.com/"], @"fallback"),
						  @"fallback");
	XCTAssertEqualObjects(AIWKDefaultSaveNameForURL(nil, @"fallback"), @"fallback");
}

// MARK: - #168: remote-image download validation

// Builds an NSHTTPURLResponse with the given status, Content-Type, and Content-Length.
static NSHTTPURLResponse *AIWKTestHTTPResponse(NSInteger statusCode, NSString *mimeType, int64_t contentLength)
{
	NSMutableDictionary *headers = [NSMutableDictionary dictionary];
	if (mimeType != nil) {
		headers[@"Content-Type"] = mimeType;
	}
	if (contentLength >= 0) {
		headers[@"Content-Length"] = [NSString stringWithFormat:@"%lld", contentLength];
	}
	return [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.com/pic.png"]
									   statusCode:statusCode
									  HTTPVersion:@"HTTP/1.1"
									 headerFields:headers];
}

// A plain image response is acceptable.
- (void)testDownloadValidationAcceptsImageResponse
{
	XCTAssertNil(AIWKImageDownloadValidationErrorForResponse(AIWKTestHTTPResponse(200, @"image/png", 1024)));
}

// Non-2xx statuses are rejected.
- (void)testDownloadValidationRejectsBadStatus
{
	XCTAssertNotNil(AIWKImageDownloadValidationErrorForResponse(AIWKTestHTTPResponse(404, @"image/png", 1024)));
	XCTAssertNotNil(AIWKImageDownloadValidationErrorForResponse(AIWKTestHTTPResponse(500, @"image/png", 1024)));
	XCTAssertNotNil(AIWKImageDownloadValidationErrorForResponse(AIWKTestHTTPResponse(301, @"image/png", 1024)));
}

// Non-image content types, and an absent content type, are rejected.
- (void)testDownloadValidationRejectsWrongContentType
{
	XCTAssertNotNil(AIWKImageDownloadValidationErrorForResponse(AIWKTestHTTPResponse(200, @"text/html", 1024)));
	XCTAssertNotNil(
		AIWKImageDownloadValidationErrorForResponse(AIWKTestHTTPResponse(200, @"application/octet-stream", 1024)));
	XCTAssertNotNil(AIWKImageDownloadValidationErrorForResponse(AIWKTestHTTPResponse(200, nil, 1024)));
}

// Oversized responses are rejected; at-cap, zero, and unknown (-1) lengths are accepted.
- (void)testDownloadValidationRejectsOversizedResponse
{
	XCTAssertNotNil(AIWKImageDownloadValidationErrorForResponse(
		AIWKTestHTTPResponse(200, @"image/png", AIWKMaxRemoteImageDownloadBytes + 1)));
	XCTAssertNil(AIWKImageDownloadValidationErrorForResponse(
		AIWKTestHTTPResponse(200, @"image/png", AIWKMaxRemoteImageDownloadBytes)));
	XCTAssertNil(AIWKImageDownloadValidationErrorForResponse(AIWKTestHTTPResponse(200, @"image/png", 0)));
	XCTAssertNil(AIWKImageDownloadValidationErrorForResponse(AIWKTestHTTPResponse(200, @"image/png", -1)));
}

// Non-HTTP responses are rejected.
- (void)testDownloadValidationRejectsNonHTTPResponse
{
	NSURLResponse *plain = [[NSURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.com/pic.png"]
													 MIMEType:@"image/png"
										expectedContentLength:1024
											 textEncodingName:nil];
	XCTAssertNotNil(AIWKImageDownloadValidationErrorForResponse(plain));
	XCTAssertNotNil(AIWKImageDownloadValidationErrorForResponse(nil));
}

@end
