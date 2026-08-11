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

// Weighted response generator for the status-range property: mostly an NSHTTPURLResponse with a
// random status across the whole code space, occasionally a non-HTTP response or nil so both
// rejection branches fire with certainty.
static NSURLResponse *AIHTTPRandomDownloadResponse(void)
{
	if (PBTUniform(10) == 0) {
		if (PBTUniform(2) == 0) {
			return nil;
		}
		return [[NSURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.com/download"]
										 MIMEType:@"application/octet-stream"
							expectedContentLength:0
								 textEncodingName:nil];
	}
	return [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.com/download"]
									   statusCode:(NSInteger)PBTUniform(600)
									  HTTPVersion:@"HTTP/1.1"
									 headerFields:@{}];
}

// Path generator for the exact-oracle property: half the time a deliberately degenerate name
// (empty, ".", "..", "/", trailing slash, whitespace-only), otherwise a random ASCII leaf — which
// printable ASCII can make degenerate too (spaces, "/", dots) — sometimes with embedded path
// components, so the fallback branch and the pass-through branch both fire with certainty.
static NSString *AIHTTPRandomSavePath(void)
{
	NSString *const degenerate[] = {@"", @".", @"..", @"/", @"./", @"/../", @"   ", @"\t\n", @"/tmp/"};
	if (PBTUniform(2) == 0) {
		return degenerate[PBTUniform(sizeof(degenerate) / sizeof(degenerate[0]))];
	}
	NSString *leaf = PBTRandomASCIIString((uint32_t)PBTUniform(16) + 1);
	if (PBTUniform(3) == 0) {
		leaf = [NSString stringWithFormat:@"dir/sub/%@", leaf];
	}
	return leaf;
}

// A fallback name that is itself always a real, non-degenerate leaf, so the idempotence check in
// the oracle property is well-defined.
static NSString *AIHTTPRandomSaveFallbackName(void)
{
	return [NSString stringWithFormat:@"save-%u", (unsigned)PBTUniform(1000000)];
}

// YES iff name is a real, non-degenerate leaf: non-empty, not "." or "..", not "/", and not
// whitespace-only. Mirrors the sanitizer's degenerate rules exactly, so the properties below
// share one oracle.
static BOOL AIHTTPIsRealLeaf(NSString *name)
{
	return name != nil && [name length] > 0 && ![name isEqualToString:@"."] && ![name isEqualToString:@".."] &&
		   ![name isEqualToString:@"/"] &&
		   ([[name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0);
}

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

// Unicode leaves — the most common non-ASCII filename case — pass through unchanged; the
// degenerate checks are ASCII-only sentinels and lastPathComponent is fully Unicode-aware.
- (void)testUnicodeLeafPassesThrough
{
	XCTAssertEqualObjects(AIHTTPDownloadSafeSaveName(@"照片.jpg", @"Untitled"), @"照片.jpg");
	XCTAssertEqualObjects(AIHTTPDownloadSafeSaveName(@"café.png", @"Untitled"), @"café.png");
	XCTAssertEqualObjects(AIHTTPDownloadSafeSaveName(@"目录/照片.jpg", @"Untitled"), @"照片.jpg");
	XCTAssertEqualObjects(AIHTTPDownloadSafeSaveName(@"照片.jpg", @""), @"照片.jpg");
}

// Peer-supplied traversal names (issue #181) reduce to a single leaf that never escapes the
// transfer directory; the degenerate ones (".", "..", whitespace) are rejected as empty so the
// EKEzv caller can fail the transfer rather than write somewhere unexpected.
- (void)testTraversalInputsReduceToLeaf
{
	XCTAssertEqualObjects(AIHTTPDownloadSafeSaveName(@"a/../../evil.txt", @""), @"evil.txt");
	XCTAssertEqualObjects(AIHTTPDownloadSafeSaveName(@"/etc/passwd", @""), @"passwd");
	XCTAssertEqualObjects(AIHTTPDownloadSafeSaveName(@"dir/sub/file.txt", @""), @"file.txt");
	XCTAssertEqualObjects(AIHTTPDownloadSafeSaveName(@".", @""), @"");
	XCTAssertEqualObjects(AIHTTPDownloadSafeSaveName(@"..", @""), @"");
	XCTAssertEqualObjects(AIHTTPDownloadSafeSaveName(@"/", @""), @"");
	XCTAssertEqualObjects(AIHTTPDownloadSafeSaveName(@"", @""), @"");
	XCTAssertEqualObjects(AIHTTPDownloadSafeSaveName(@"   ", @""), @"");
}

// Property: with an empty fallback, the sanitizer returns non-empty exactly when the path's last
// component is a real, non-degenerate leaf — the reject/pass boundary the EKEzv folder-transfer
// sink relies on to fail the transfer on unsafe peer-supplied names (issue #181). Any non-empty
// result, appended to an arbitrary transfer root, stays inside that root.
- (void)testEmptyFallbackRejectsExactlyDegenerateLeaf
{
	PBTCheckDefault({
		NSString *path = AIHTTPRandomSavePath();
		NSString *safeName = AIHTTPDownloadSafeSaveName(path, @"");
		BOOL isRealLeaf = AIHTTPIsRealLeaf([path lastPathComponent]);
		XCTAssertTrue(([safeName length] > 0) == isRealLeaf, @"path = %@", path);
		if ([safeName length] > 0) {
			NSString *root = @"/tmp/transfer-root";
			XCTAssertTrue([[root stringByAppendingPathComponent:safeName] hasPrefix:root], @"path = %@", path);
		}
	});
}

// Property: whatever a peer-supplied name looks like, the sanitizer either rejects it (returns
// @"") or yields a single non-degenerate leaf — no path separator, not "." or "..". This is the
// contract the EKEzv folder-transfer sink relies on when appending to a transfer directory
// (issue #181).
- (void)testSafeSaveNameIsEitherEmptyOrASingleSafeLeaf
{
	PBTCheckDefault({
		NSString *name = PBTRandomASCIIString((uint32_t)PBTUniform(40));
		NSString *safeName = AIHTTPDownloadSafeSaveName(name, @"");
		XCTAssertNotNil(safeName);
		if ([safeName length] > 0) {
			XCTAssertFalse([safeName isEqualToString:@"."] || [safeName isEqualToString:@".."],
						   @"name = %@, safeName = %@", name, safeName);
			NSRange slashRange = [safeName rangeOfString:@"/"];
			XCTAssertEqual(slashRange.location, (NSUInteger)NSNotFound, @"name = %@, safeName = %@", name, safeName);
		}
	});
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

// Property: AIHTTPDownloadValidationErrorForResponse returns nil exactly when the response is an
// NSHTTPURLResponse with a 2xx status; otherwise an NSError in AIHTTPDownloadErrorDomain whose
// code is NotHTTP for a non-HTTP (or nil) response, or BadStatus for a non-2xx HTTP status. The
// oracle reads the same response the implementation does, locking in the 200-299 boundary — the
// regression surface a fixed set of example statuses can miss (a "<=" / "<" flip).
- (void)testDownloadValidationErrorCodeProperty
{
	PBTCheckDefault({
		NSURLResponse *response = AIHTTPRandomDownloadResponse();
		NSError *error = AIHTTPDownloadValidationErrorForResponse(response);

		if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
			XCTAssertNotNil(error, @"response = %@", response);
			XCTAssertEqualObjects([error domain], AIHTTPDownloadErrorDomain, @"response = %@", response);
			XCTAssertEqual([error code], AIHTTPDownloadErrorNotHTTP, @"response = %@", response);
		} else {
			NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
			if (statusCode >= 200 && statusCode <= 299) {
				XCTAssertNil(error, @"status = %ld", (long)statusCode);
			} else {
				XCTAssertNotNil(error, @"status = %ld", (long)statusCode);
				XCTAssertEqualObjects([error domain], AIHTTPDownloadErrorDomain, @"status = %ld", (long)statusCode);
				XCTAssertEqual([error code], AIHTTPDownloadErrorBadStatus, @"status = %ld", (long)statusCode);
			}
		}
	});
}

// Property: AIHTTPDownloadSafeSaveName returns the path's last path component exactly when that
// is a real, non-degenerate leaf (non-empty, not ".", "..", "/", and not whitespace-only), and
// the fallback otherwise. The oracle re-derives the component with the same degenerate rules, so
// it locks in the exact pass-through/fallback boundary rather than just non-degeneracy. The
// function is also idempotent: re-sanitizing its own output is a no-op.
- (void)testDefaultSaveNameProperty
{
	PBTCheckDefault({
		NSString *path = AIHTTPRandomSavePath();
		NSString *fallbackName = AIHTTPRandomSaveFallbackName();
		NSString *component = [path lastPathComponent];
		NSString *expected = AIHTTPIsRealLeaf(component) ? component : fallbackName;

		NSString *once = AIHTTPDownloadSafeSaveName(path, fallbackName);
		XCTAssertEqualObjects(once, expected, @"path = %@, fallback = %@", path, fallbackName);
		XCTAssertEqualObjects(AIHTTPDownloadSafeSaveName(once, fallbackName), once, @"path = %@", path);
	});
}

#pragma mark - Truncation validation

// A complete download — received bytes equal to the declared Content-Length — is accepted.
- (void)testCompleteDownloadIsAccepted
{
	XCTAssertNil(AIHTTPDownloadValidationErrorForTruncatedDownload(100, 100));
	// A receiver may legally get more bytes than declared (a server that over-declared, or a
	// body the client reassembles); that is not truncation.
	XCTAssertNil(AIHTTPDownloadValidationErrorForTruncatedDownload(100, 200));
}

// A short download — received bytes below the declared Content-Length — is rejected with the
// Truncated code in AIHTTPDownloadErrorDomain.
- (void)testShortDownloadIsRejected
{
	for (NSNumber *received in @[ @99, @50, @0 ]) {
		NSError *error = AIHTTPDownloadValidationErrorForTruncatedDownload(100, [received longLongValue]);
		XCTAssertNotNil(error, @"received = %@", received);
		XCTAssertEqualObjects([error domain], AIHTTPDownloadErrorDomain, @"received = %@", received);
		XCTAssertEqual([error code], AIHTTPDownloadErrorTruncated, @"received = %@", received);
	}
}

// The unknown-length sentinel (-1) carries no size contract, so a short body is not treated as
// truncated (issue #263's declared==0 guard).
- (void)testUnknownDeclaredLengthIsAccepted
{
	XCTAssertNil(AIHTTPDownloadValidationErrorForTruncatedDownload(NSURLResponseUnknownLength, 0));
	XCTAssertNil(AIHTTPDownloadValidationErrorForTruncatedDownload(NSURLResponseUnknownLength, 1024));
}

// A non-positive declared length (0 or negative) also carries no size contract.
- (void)testNonPositiveDeclaredLengthIsAccepted
{
	XCTAssertNil(AIHTTPDownloadValidationErrorForTruncatedDownload(0, 0));
	XCTAssertNil(AIHTTPDownloadValidationErrorForTruncatedDownload(0, 1024));
	XCTAssertNil(AIHTTPDownloadValidationErrorForTruncatedDownload(-5, 0));
}

// Property: AIHTTPDownloadValidationErrorForTruncatedDownload returns nil exactly when there is no
// size contract (declaredLength <= 0) or the received bytes meet or exceed the declaration; an
// NSError in AIHTTPDownloadErrorDomain with code Truncated otherwise. The oracle reads the same
// inputs the implementation does, locking in the declared<=0 and received<declared boundaries — the
// regression surface a fixed set of example lengths can miss (a "<=" / "<" flip).
- (void)testTruncationErrorCodeProperty
{
	PBTCheckDefault({
		int64_t declaredLength;
		switch (PBTUniform(5)) {
		case 0:
			declaredLength = 0;
			break;
		case 1:
			declaredLength = -5;
			break;
		case 2:
			declaredLength = (int64_t)NSURLResponseUnknownLength; // -1
			break;
		case 3:
			declaredLength = (int64_t)PBTUniform(UINT32_MAX) + 1;
			break;
		default:
			/* The full positive int64 domain, including declarations the 32-bit generator above never
			 * reaches; the comparison is pure int64, so values past UINT32_MAX must not diverge (issue #273). */
			declaredLength = (int64_t)PBTUniformUInt64((uint64_t)INT64_MAX);
			break;
		}
		/* Sweep the negative received side too: a negative byte count must still compare correctly
		 * against a positive declaration (issue #273). */
		int64_t receivedBytes =
			PBTRandomBool() ? (int64_t)PBTUniform(UINT32_MAX) : -(int64_t)PBTUniformUInt64(UINT32_MAX);

		NSError *error = AIHTTPDownloadValidationErrorForTruncatedDownload(declaredLength, receivedBytes);
		BOOL shouldBeNil = (declaredLength <= 0) || (receivedBytes >= declaredLength);
		if (shouldBeNil) {
			XCTAssertNil(error, @"declared = %lld, received = %lld", declaredLength, receivedBytes);
		} else {
			XCTAssertNotNil(error, @"declared = %lld, received = %lld", declaredLength, receivedBytes);
			XCTAssertEqualObjects([error domain], AIHTTPDownloadErrorDomain, @"declared = %lld", declaredLength);
			XCTAssertEqual([error code], AIHTTPDownloadErrorTruncated, @"declared = %lld", declaredLength);
		}
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
