/*
 * Adium is the legal property of its developers, whose names are listed in the copyright file included
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

#import "EKEzvIncomingFileTransfer.h"
#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import <arpa/inet.h>

/*
 * Issue #269: the #263 truncation check compares bytesReceived against the peer-declared size with "<"
 * so AppleSingle envelope bytes don't false-positive — but that blind spot lets a truncated
 * AppleSingle body through when the envelope overhead alone pushes the wire byte count up to or past
 * the declared size while the raw content is still short. The check must subtract the accumulated
 * AppleSingle envelope overhead (header + entries + Finder info) from bytesReceived before comparing,
 * so the raw data length is what is measured against the declared size.
 *
 * AppleSingle layout (RFC 1740): 26-byte header (magic 0x00051600, version 0x00020000, 16 filler,
 * 2-byte entry count) followed by 12-byte entries. A single data-fork entry adds 12 bytes of
 * overhead, so a body carrying N raw bytes is 26 + 12 + N = 38 + N bytes on the wire.
 */
#define EKEZV_TEST_AS_HEADER_LENGTH 26
#define EKEZV_TEST_AS_ENTRY_LENGTH 12
#define EKEZV_TEST_AS_DATA_FORK_ENTRY_ID 1

@interface EKEzvIncomingFileTransfer (TestTruncationAccounting)
- (BOOL)transferWasTruncated;
@end

@interface TestEKEzvIncomingFileTransferTruncationAccounting : XCTestCase
@end

@implementation TestEKEzvIncomingFileTransferTruncationAccounting

- (NSXMLElement *)dirElementNamed:(NSString *)name
{
	NSXMLElement *dir = [[NSXMLElement alloc] initWithName:@"dir"];
	NSXMLElement *nameElement = [[NSXMLElement alloc] initWithName:@"name"];
	[nameElement setStringValue:name];
	[dir addChild:nameElement];
	return dir;
}

/* AppleSingle body holding a single data-fork entry of rawLength raw bytes (big-endian wire format). */
- (NSData *)appleSingleBodyWithRawLength:(NSUInteger)rawLength
{
	NSMutableData *body = [NSMutableData data];

	/* The impl reads the header and entries with [data getBytes:&header length:26] / getBytes:range:,
	 * so the wire fields must be 4-byte UInt32 (UInt16 for numberEntries) exactly as the AppleSingle
	 * structs declare — unsigned long would be 8 bytes on LP64 and misalign every field. */
	UInt32 magic = htonl(0x00051600);
	UInt32 version = htonl(0x00020000);
	UInt16 numberEntries = htons(1);
	char filler[16] = {0};
	UInt32 entryID = htonl(EKEZV_TEST_AS_DATA_FORK_ENTRY_ID);
	UInt32 offset = htonl((UInt32)(EKEZV_TEST_AS_HEADER_LENGTH + EKEZV_TEST_AS_ENTRY_LENGTH));
	UInt32 entryLength = htonl((UInt32)rawLength);

	[body appendBytes:&magic length:sizeof(magic)];
	[body appendBytes:&version length:sizeof(version)];
	[body appendBytes:filler length:sizeof(filler)];
	[body appendBytes:&numberEntries length:sizeof(numberEntries)];
	[body appendBytes:&entryID length:sizeof(entryID)];
	[body appendBytes:&offset length:sizeof(offset)];
	[body appendBytes:&entryLength length:sizeof(entryLength)];
	[body appendData:[NSMutableData dataWithLength:rawLength]];
	return body;
}

/* Drives a transfer whose single file is an AppleSingle body through the completion gate, with the
 * declared size given. Returns the transfer for success/artifact assertions. */
- (EKEzvIncomingFileTransfer *)transferDecodedWithRawLength:(NSUInteger)rawLength
											   declaredSize:(unsigned long long)declared
												   tempRoot:(NSString *)tempRoot
{
	EKEzvIncomingFileTransfer *transfer = [[EKEzvIncomingFileTransfer alloc] init];
	[transfer setLocalFilename:tempRoot];
	[transfer setUrl:@"http://example.com/base"];

	NSXMLElement *outer = [self dirElementNamed:@"a"];
	XCTAssertTrue([transfer downloadFolder:outer path:tempRoot url:@"http://example.com/base"],
				  @"a single valid <dir> child must complete the folder walk");

	NSString *receivedFile = [tempRoot stringByAppendingPathComponent:@"a/received.bin"];
	NSData *body = [self appleSingleBodyWithRawLength:rawLength];
	[[NSFileManager defaultManager] createFileAtPath:receivedFile contents:body attributes:nil];

	NSURL *itemURL = [NSURL URLWithString:@"http://example.com/base/a/received.bin"];
	[transfer setValue:[NSMutableArray arrayWithObject:itemURL] forKey:@"encodedDownloads"];
	[transfer setValue:[NSNumber numberWithLongLong:(long long)[body length]] forKey:@"bytesReceived"];
	[transfer setSize:declared];

	/* The success path reads [[dataTask originalRequest] URL], so the task must be a real
	 * NSURLSessionDataTask (a bare NSObject stand-in has no originalRequest). */
	NSURLSession *session =
		[NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:[NSURLRequest requestWithURL:itemURL]];
	[transfer URLSession:nil task:task didCompleteWithError:nil];
	return transfer;
}

/* Predicate unit tests (issue #269). */

- (void)testPredicateShortWireTruncates
{
	EKEzvIncomingFileTransfer *transfer = [[EKEzvIncomingFileTransfer alloc] init];
	[transfer setValue:[NSNumber numberWithLongLong:99] forKey:@"bytesReceived"];
	[transfer setSize:100];

	XCTAssertTrue([transfer transferWasTruncated], @"99 of 100 declared bytes is truncated (issue #269)");
}

/* The #269 regression: wire bytes (118) reach the declared size (100) only because of the 38-byte
 * envelope; the raw content is 80 < 100 and must be detected as truncated. */
- (void)testPredicateEnvelopeMaskedTruncationDetected
{
	EKEzvIncomingFileTransfer *transfer = [[EKEzvIncomingFileTransfer alloc] init];
	[transfer setValue:[NSNumber numberWithLongLong:118] forKey:@"bytesReceived"];
	[transfer setValue:[NSNumber numberWithUnsignedLongLong:38] forKey:@"appleSingleEnvelopeBytes"];
	[transfer setSize:100];

	XCTAssertTrue([transfer transferWasTruncated],
				  @"envelope overhead must not mask a truncated raw body (issue #269)");
}

- (void)testPredicateEnvelopeAwareCompleteAccepted
{
	EKEzvIncomingFileTransfer *transfer = [[EKEzvIncomingFileTransfer alloc] init];
	[transfer setValue:[NSNumber numberWithLongLong:118] forKey:@"bytesReceived"];
	[transfer setValue:[NSNumber numberWithUnsignedLongLong:18] forKey:@"appleSingleEnvelopeBytes"];
	[transfer setSize:100];

	XCTAssertFalse([transfer transferWasTruncated],
				   @"a raw body that meets the declared size must be accepted (issue #269)");
}

- (void)testPredicatePlainOverrunAccepted
{
	EKEzvIncomingFileTransfer *transfer = [[EKEzvIncomingFileTransfer alloc] init];
	[transfer setValue:[NSNumber numberWithLongLong:150] forKey:@"bytesReceived"];
	[transfer setSize:100];

	XCTAssertFalse([transfer transferWasTruncated],
				   @"a plain body larger than the declared size is not truncated (issue #269)");
}

- (void)testPredicateZeroSizeNeverTruncates
{
	EKEzvIncomingFileTransfer *transfer = [[EKEzvIncomingFileTransfer alloc] init];
	[transfer setValue:[NSNumber numberWithLongLong:0] forKey:@"bytesReceived"];
	[transfer setSize:0];

	XCTAssertFalse([transfer transferWasTruncated], @"a zero declared size disables the truncation check (issue #269)");
}

/* End-to-end decode accounting (issue #269). */

/* A truncated AppleSingle body: declared 100, raw content 80 (wire 118 after the 38-byte envelope).
 * The old #263 check saw 118 >= 100 and accepted it; the envelope-aware check must fail the transfer
 * and remove the artifacts. */
- (void)testTruncatedAppleSingleBodyFailsTransfer
{
	NSString *tempRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvEnvelopeTruncated"];
	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];

	EKEzvIncomingFileTransfer *transfer = [self transferDecodedWithRawLength:80 declaredSize:100 tempRoot:tempRoot];

	XCTAssertFalse([[transfer valueForKey:@"transferSucceeded"] boolValue],
				   @"an AppleSingle body whose raw content is short of the declared size must fail (issue #269)");
	XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:tempRoot],
				   @"a truncated AppleSingle body must remove its artifacts (issue #269)");

	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
}

/* A complete AppleSingle body: declared 80, raw content 80 (wire 118). Decode writes the raw data
 * (80 bytes) back to the received path; the transfer succeeds and the decoded file is kept. */
- (void)testCompleteAppleSingleBodySucceeds
{
	NSString *tempRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvEnvelopeComplete"];
	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];

	EKEzvIncomingFileTransfer *transfer = [self transferDecodedWithRawLength:80 declaredSize:80 tempRoot:tempRoot];

	NSString *receivedFile = [tempRoot stringByAppendingPathComponent:@"a/received.bin"];
	XCTAssertTrue([[transfer valueForKey:@"transferSucceeded"] boolValue],
				  @"a complete AppleSingle body must be accepted (issue #269)");
	XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:receivedFile],
				  @"a complete AppleSingle body must keep its decoded file (issue #269)");
	NSData *decoded = [[NSFileManager defaultManager] contentsAtPath:receivedFile];
	XCTAssertEqual([decoded length], (NSUInteger)80,
				   @"the decoded file must hold the raw data fork, not the envelope (issue #269)");

	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
}

@end
