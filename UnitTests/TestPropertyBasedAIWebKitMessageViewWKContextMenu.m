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

#import "AIHTTPDownloadValidation.h"
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
							AIWKContextMenuCoordinateDoubleIsInRange([x doubleValue]) &&
							AIWKContextMenuCoordinateDoubleIsInRange([y doubleValue]);
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

// Random scheme: one of the savable set {file, http, https}, or random garbage plus an "x" so the
// scheme can never accidentally equal a savable one (none of the savable set ends in "x"). NSURL
// lowercases schemes, so generating lowercase keeps the oracle's string comparison faithful.
static NSString *AIWKRandomScheme(void)
{
	switch (PBTUniform(4)) {
	case 0:
		return @"file";
	case 1:
		return @"http";
	case 2:
		return @"https";
	default:
		return [[PBTRandomASCIIString(8) lowercaseString] stringByAppendingString:@"x"];
	}
}

/// Property: AIWKCanSaveImageURL accepts exactly the file:, http:, and https: schemes and rejects
/// every other scheme — asserted in both directions over generated schemes (issue #151).
- (void)testCanSaveImageURLProperty
{
	PBTCheckDefault({
		NSString *scheme = AIWKRandomScheme();
		NSURL *url = [NSURL URLWithString:[scheme stringByAppendingString:@"://host/pic.png"]];
		if (url != nil) {
			BOOL expected = [scheme isEqualToString:@"file"] || [scheme isEqualToString:@"http"] ||
							[scheme isEqualToString:@"https"];
			XCTAssertEqual(AIWKCanSaveImageURL(url), expected, @"scheme = %@", scheme);
		}
	});
}

// MARK: - #170: context-menu coordinate bounds

// The exposed range predicate accepts exactly [0, AIWKMaxContextMenuCoordinate] and rejects
// non-finite values (they would misposition the pop-up via NSMakePoint).
- (void)testCoordinateIsValidBoundaries
{
	XCTAssertTrue(AIWKContextMenuCoordinateDoubleIsInRange(0.0));
	XCTAssertTrue(AIWKContextMenuCoordinateDoubleIsInRange(AIWKMaxContextMenuCoordinate));
	XCTAssertTrue(AIWKContextMenuCoordinateDoubleIsInRange(500.25));
	XCTAssertFalse(AIWKContextMenuCoordinateDoubleIsInRange(-0.0001));
	XCTAssertFalse(AIWKContextMenuCoordinateDoubleIsInRange(AIWKMaxContextMenuCoordinate + 0.0001));
	XCTAssertFalse(AIWKContextMenuCoordinateDoubleIsInRange(INFINITY));
	XCTAssertFalse(AIWKContextMenuCoordinateDoubleIsInRange(-INFINITY));
	XCTAssertFalse(AIWKContextMenuCoordinateDoubleIsInRange(NAN));
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

// PBTRandomJSBodyDictionary never emits CFBoolean coordinates or values outside
// [0, AIWKMaxContextMenuCoordinate] — exactly the two shapes the parser must reject — so this
// generator builds coordinates by hand. PBTUniform max 100000 keeps the values single-digit-ok.
static NSNumber *AIWKRandomCoordinateNumber(void)
{
	switch (PBTUniform(5)) {
	case 0:
		return @(-(double)PBTUniform(100000)); // negative, out of range
	case 1:
		return @(AIWKMaxContextMenuCoordinate + 1 + (double)PBTUniform(100000)); // over the cap
	case 2:
		return @((double)PBTUniform((uint32_t)AIWKMaxContextMenuCoordinate + 1)); // in range
	case 3:
		return @YES; // JSON true
	default:
		return @NO; // JSON false
	}
}

/// Property: The contextMenu parser accepts exactly the coordinate shapes that are numbers in
/// [0, AIWKMaxContextMenuCoordinate] — CFBoolean values (JSON true/false) and out-of-range
/// numbers are rejected (issue #170).
- (void)testCoordinateParsingProperty
{
	PBTCheckDefault({
		NSNumber *x = AIWKRandomCoordinateNumber();
		NSNumber *y = AIWKRandomCoordinateNumber();
		BOOL xIsBoolean = CFGetTypeID((__bridge CFTypeRef)x) == CFBooleanGetTypeID();
		BOOL yIsBoolean = CFGetTypeID((__bridge CFTypeRef)y) == CFBooleanGetTypeID();
		BOOL expected = !xIsBoolean && !yIsBoolean && AIWKContextMenuCoordinateDoubleIsInRange([x doubleValue]) &&
						AIWKContextMenuCoordinateDoubleIsInRange([y doubleValue]);
		// The dictionary literal is parenthesized so its commas don't split the PBTCheckDefault macro argument.
		AIWKContextMenuMessage message =
			AIWKContextMenuMessageFromBody((@{@"type" : @"contextMenu", @"x" : x, @"y" : y}));
		XCTAssertEqual(message.valid, expected, @"x = %@, y = %@", x, y);
	});
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

/// Property: A URL whose last path component is a real component (non-empty, not "/", not "." or
/// "..") uses it as the default name. Dot-directory components are excluded here — they fall back
/// per issue #182 and are covered by testDefaultSaveNameFallsBackForDotPathComponents.
- (void)testDefaultSaveNameUsesLastPathComponent
{
	PBTCheckDefault({
		NSCharacterSet *allowed =
			[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz"
																"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"];
		NSString *clean = [[PBTRandomASCIIString(16) componentsSeparatedByCharactersInSet:[allowed invertedSet]]
			componentsJoinedByString:@""];
		if ([clean length] == 0 || [clean isEqualToString:@"."] || [clean isEqualToString:@".."]) {
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

// A URL whose last path component is "." or ".." points at a directory, not a file; the save
// panel must fall back rather than offer a directory as the default name (issue #182).
- (void)testDefaultSaveNameFallsBackForDotPathComponents
{
	XCTAssertEqualObjects(AIWKDefaultSaveNameForURL([NSURL URLWithString:@"https://example.com/."], @"fallback"),
						  @"fallback");
	XCTAssertEqualObjects(AIWKDefaultSaveNameForURL([NSURL URLWithString:@"https://example.com/.."], @"fallback"),
						  @"fallback");
	XCTAssertEqualObjects(AIWKDefaultSaveNameForURL([NSURL URLWithString:@"https://example.com/a/../"], @"fallback"),
						  @"fallback");
	XCTAssertEqualObjects(AIWKDefaultSaveNameForURL([NSURL fileURLWithPath:@"/tmp/."], @"fallback"), @"fallback");
	XCTAssertEqualObjects(AIWKDefaultSaveNameForURL([NSURL fileURLWithPath:@"/tmp/.."], @"fallback"), @"fallback");
}

// Random image URL: sometimes a real path component (so lastPathComponent wins), sometimes a bare
// origin or root path (so the fallback must win). Includes "/.", "/..", and "/a/../" — URLs whose
// last path component is a dot directory reference, which must also fall back (issue #182) — and
// "/%20", whose last path component decodes to a whitespace-only name, also a fallback case.
static NSURL *AIWKRandomImageURL(void)
{
	NSString *const paths[] = {
		@"/pic.png", @"/a/b/c.png", @"/", @"", @"/.", @"/..", @"/a/../", @"/%20",
	};
	return [NSURL URLWithString:[@"https://example.com" stringByAppendingString:paths[PBTUniform(8)]]];
}

// Non-empty fallback name, as the function contract requires.
static NSString *AIWKRandomSaveFallbackName(void)
{
	return [NSString stringWithFormat:@"img-%@.png", PBTRandomASCIIString(6)];
}

/// Property: The default save name is exactly what the shared sanitizer returns for the URL's last
/// path component — the wrapper delegates to AIHTTPDownloadSafeSaveName rather than re-deriving the
/// degenerate-name rules by hand (issues #169, #182). Locking the delegation: a wrapper that stops
/// delegating (e.g. re-implements the rules and omits the whitespace case) diverges from the
/// sanitizer and fails this property.
- (void)testDefaultSaveNameProperty
{
	PBTCheckDefault({
		NSURL *url = AIWKRandomImageURL();
		NSString *fallbackName = AIWKRandomSaveFallbackName();
		NSString *expected = AIHTTPDownloadSafeSaveName([url lastPathComponent], fallbackName);
		XCTAssertEqualObjects(AIWKDefaultSaveNameForURL(url, fallbackName), expected, @"url = %@, fallback = %@", url,
							  fallbackName);
	});
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

// Random MIME type spanning nil, image types, non-image types, and a bare "image/" prefix (the
// no-subtype edge that hasPrefix alone would wrongly accept).
static NSString *AIWKRandomMIMEType(void)
{
	NSString *const candidates[] = {
		nil,           @"image/png",     @"image/jpeg",
		@"image/gif",  @"image/svg+xml", @"image/x-icon",
		@"image/webp", @"text/html",     @"application/octet-stream",
		@"text/plain", @"image/",        @"IMAGE/PNG",
	};
	return candidates[PBTUniform(sizeof(candidates) / sizeof(candidates[0]))];
}

// Random byte count: usually 0..AIWKMaxRemoteImageDownloadBytes (cap included), but oversized
// ~1/4 of the time so the TooLarge branch is exercised rather than astronomically rarely.
static int64_t AIWKRandomContentLength(void)
{
	if (PBTUniform(4) == 0) {
		return AIWKMaxRemoteImageDownloadBytes + 1 + (int64_t)PBTUniform(1000000);
	}
	return (int64_t)PBTUniform(AIWKMaxRemoteImageDownloadBytes + 1);
}

// Random NSURLSession response: an NSHTTPURLResponse with random status (0..599), MIME type, and
// length, or occasionally (1 in 10) a non-HTTP response or nil to exercise the NotHTTP path.
static NSURLResponse *AIWKRandomDownloadResponse(void)
{
	if (PBTUniform(10) == 0) {
		if (PBTUniform(2) == 0) {
			return nil;
		}
		return [[NSURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.com/pic.png"]
										 MIMEType:AIWKRandomMIMEType()
							expectedContentLength:0
								 textEncodingName:nil];
	}
	return AIWKTestHTTPResponse((NSInteger)PBTUniform(600), AIWKRandomMIMEType(), AIWKRandomContentLength());
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

// Non-image content types, an absent content type, and a bare "image/" with no subtype are rejected.
- (void)testDownloadValidationRejectsWrongContentType
{
	XCTAssertNotNil(AIWKImageDownloadValidationErrorForResponse(AIWKTestHTTPResponse(200, @"text/html", 1024)));
	XCTAssertNotNil(
		AIWKImageDownloadValidationErrorForResponse(AIWKTestHTTPResponse(200, @"application/octet-stream", 1024)));
	XCTAssertNotNil(AIWKImageDownloadValidationErrorForResponse(AIWKTestHTTPResponse(200, nil, 1024)));
	XCTAssertNotNil(AIWKImageDownloadValidationErrorForResponse(AIWKTestHTTPResponse(200, @"image/", 1024)));
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

/// Property: AIWKImageDownloadValidationErrorForResponse returns nil exactly when the response is
/// HTTP 2xx with an image/<subtype> Content-Type at or under the byte cap, and otherwise an NSError
/// in AIWKImageDownloadErrorDomain whose code is the first violated check, in this order: NotHTTP,
/// BadStatus, WrongContentType, TooLarge. The oracle reads the same response values the
/// implementation does, so it locks in the precedence, not a re-derivation of each check.
- (void)testDownloadValidationErrorCodeProperty
{
	PBTCheckDefault({
		NSURLResponse *response = AIWKRandomDownloadResponse();
		NSError *error = AIWKImageDownloadValidationErrorForResponse(response);

		if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
			XCTAssertNotNil(error, @"response = %@", response);
			XCTAssertEqualObjects([error domain], AIWKImageDownloadErrorDomain, @"response = %@", response);
			XCTAssertEqual([error code], AIWKImageDownloadErrorNotHTTP, @"response = %@", response);
		} else {
			NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
			NSInteger statusCode = [httpResponse statusCode];
			NSString *contentType = [[httpResponse MIMEType] lowercaseString];
			int64_t contentLength = [httpResponse expectedContentLength];

			if (statusCode < 200 || statusCode > 299) {
				XCTAssertNotNil(error, @"status=%ld mime=%@", (long)statusCode, [httpResponse MIMEType]);
				XCTAssertEqualObjects([error domain], AIWKImageDownloadErrorDomain, @"status=%ld mime=%@",
									  (long)statusCode, [httpResponse MIMEType]);
				XCTAssertEqual([error code], AIWKImageDownloadErrorBadStatus, @"status=%ld mime=%@", (long)statusCode,
							   [httpResponse MIMEType]);
			} else if (contentType == nil || [contentType length] <= sizeof("image/") - 1 ||
					   ![contentType hasPrefix:@"image/"]) {
				XCTAssertNotNil(error, @"status=%ld mime=%@", (long)statusCode, [httpResponse MIMEType]);
				XCTAssertEqualObjects([error domain], AIWKImageDownloadErrorDomain, @"status=%ld mime=%@",
									  (long)statusCode, [httpResponse MIMEType]);
				XCTAssertEqual([error code], AIWKImageDownloadErrorWrongContentType, @"status=%ld mime=%@",
							   (long)statusCode, [httpResponse MIMEType]);
			} else if (contentLength > AIWKMaxRemoteImageDownloadBytes) {
				XCTAssertNotNil(error, @"status=%ld mime=%@ length=%lld", (long)statusCode, [httpResponse MIMEType],
								contentLength);
				XCTAssertEqualObjects([error domain], AIWKImageDownloadErrorDomain, @"status=%ld mime=%@ length=%lld",
									  (long)statusCode, [httpResponse MIMEType], contentLength);
				XCTAssertEqual([error code], AIWKImageDownloadErrorTooLarge, @"status=%ld mime=%@ length=%lld",
							   (long)statusCode, [httpResponse MIMEType], contentLength);
			} else {
				XCTAssertNil(error, @"status=%ld mime=%@ length=%lld", (long)statusCode, [httpResponse MIMEType],
							 contentLength);
			}
		}
	});
}

@end
