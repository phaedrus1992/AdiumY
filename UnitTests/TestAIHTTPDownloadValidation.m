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
#import <XCTest/XCTest.h>

@interface AIHTTPDownloadValidationTest : XCTestCase
- (NSHTTPURLResponse *)httpResponseWithStatus:(NSInteger)statusCode;
@end

@implementation AIHTTPDownloadValidationTest

#pragma mark - Response validation

// Edge: a nil response is not HTTP and is rejected.
- (void)testNilResponseIsRejected
{
	NSError *error = AIHTTPDownloadValidationErrorForResponse(nil);
	XCTAssertNotNil(error);
	XCTAssertEqualObjects([error domain], AIHTTPDownloadErrorDomain);
	XCTAssertEqual([error code], AIHTTPDownloadErrorNotHTTP);
}

// Edge: a non-HTTP response (e.g. a file:// NSURLResponse) is rejected.
- (void)testNonHTTPResponseIsRejected
{
	NSURLResponse *response = [[NSURLResponse alloc] initWithURL:[NSURL URLWithString:@"file:///tmp/download"]
														MIMEType:@"application/octet-stream"
										   expectedContentLength:1024
												textEncodingName:nil];
	NSError *error = AIHTTPDownloadValidationErrorForResponse(response);
	XCTAssertNotNil(error);
	XCTAssertEqualObjects([error domain], AIHTTPDownloadErrorDomain);
	XCTAssertEqual([error code], AIHTTPDownloadErrorNotHTTP);
}

// 2xx responses, including 204 and the top of the range, pass.
- (void)testTwoHundredRangeIsAccepted
{
	for (NSNumber *status in @[ @200, @204, @299 ]) {
		XCTAssertNil(AIHTTPDownloadValidationErrorForResponse([self httpResponseWithStatus:[status integerValue]]),
					 @"status = %@", status);
	}
}

// Non-2xx responses are rejected with the BadStatus code.
- (void)testNonTwoHundredRangeIsRejected
{
	for (NSNumber *status in @[ @100, @300, @400, @404, @500 ]) {
		NSError *error = AIHTTPDownloadValidationErrorForResponse([self httpResponseWithStatus:[status integerValue]]);
		XCTAssertNotNil(error, @"status = %@", status);
		XCTAssertEqualObjects([error domain], AIHTTPDownloadErrorDomain, @"status = %@", status);
		XCTAssertEqual([error code], AIHTTPDownloadErrorBadStatus, @"status = %@", status);
	}
}

#pragma mark - Safe save name

// Edge: nil or a degenerate last path component falls back to the provided name.
- (void)testDegeneratePathsFallBack
{
	NSArray<NSString *> *degenerate = @[ @"", @".", @"..", @"/", @"./", @"/../" ];
	for (NSString *path in degenerate) {
		XCTAssertEqualObjects(AIHTTPDownloadSafeSaveName(path, @"Untitled"), @"Untitled", @"path = %@", path);
	}
	XCTAssertEqualObjects(AIHTTPDownloadSafeSaveName(nil, @"Untitled"), @"Untitled");
}

// A normal leaf filename, or a path whose leaf is a normal name, passes through unchanged.
- (void)testLeafNamePassesThrough
{
	XCTAssertEqualObjects(AIHTTPDownloadSafeSaveName(@"photo.jpg", @"Untitled"), @"photo.jpg");
	XCTAssertEqualObjects(AIHTTPDownloadSafeSaveName(@"dir/file.txt", @"Untitled"), @"file.txt");
}

// Property: no input — empty, whitespace, or arbitrary printable ASCII (which can include
// "/" and dots) — yields an empty or dot-degenerate default save name.
- (void)testSaveNameIsNeverDegenerate
{
	PBTCheckDefault({
		NSString *path = PBTRandomASCIIString((uint32_t)PBTUniform(32));
		NSString *name = AIHTTPDownloadSafeSaveName(path, @"Untitled");
		XCTAssertNotNil(name);
		XCTAssertGreaterThan([name length], (NSUInteger)0);
		XCTAssertFalse([name isEqualToString:@"."] || [name isEqualToString:@".."] || [name isEqualToString:@"/"]);
	});
}

- (NSHTTPURLResponse *)httpResponseWithStatus:(NSInteger)statusCode
{
	return [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.com/download"]
									   statusCode:statusCode
									  HTTPVersion:@"HTTP/1.1"
									 headerFields:@{}];
}

@end
