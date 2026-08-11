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

#import "AIPropertyTestUtilities.h"
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
#define EKEZV_TEST_AS_RESOURCE_FORK_ENTRY_ID 2
#define EKEZV_TEST_AS_COMMENT_ENTRY_ID 4
#define EKEZV_TEST_AS_FINDER_INFO_ENTRY_ID 9
#define EKEZV_TEST_AS_FINDER_INFO_LENGTH 32

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

/* AppleSingle body carrying a data fork followed by a resource fork. The resource fork entry comes
 * last, so a naive last-content-entry-wins writer would install the resource fork instead of the
 * data fork the transfer actually delivers (issue #269 dual-fork case). */
- (NSData *)appleSingleBodyWithDataForkLength:(NSUInteger)dataForkLength
						   resourceForkLength:(NSUInteger)resourceForkLength
{
	NSMutableData *body = [NSMutableData data];

	UInt32 magic = htonl(0x00051600);
	UInt32 version = htonl(0x00020000);
	UInt16 numberEntries = htons(2);
	char filler[16] = {0};

	UInt32 dataForkOffset = (UInt32)(EKEZV_TEST_AS_HEADER_LENGTH + 2 * EKEZV_TEST_AS_ENTRY_LENGTH);
	UInt32 dataForkEntryID = htonl(EKEZV_TEST_AS_DATA_FORK_ENTRY_ID);
	UInt32 dataForkEntryOffset = htonl(dataForkOffset);
	UInt32 dataForkEntryLength = htonl((UInt32)dataForkLength);

	UInt32 resourceForkOffset = dataForkOffset + (UInt32)dataForkLength;
	UInt32 resourceForkEntryID = htonl(2); /* AS_ENTRY_RESOURCE_FORK */
	UInt32 resourceForkEntryOffset = htonl(resourceForkOffset);
	UInt32 resourceForkEntryLength = htonl((UInt32)resourceForkLength);

	[body appendBytes:&magic length:sizeof(magic)];
	[body appendBytes:&version length:sizeof(version)];
	[body appendBytes:filler length:sizeof(filler)];
	[body appendBytes:&numberEntries length:sizeof(numberEntries)];
	[body appendBytes:&dataForkEntryID length:sizeof(dataForkEntryID)];
	[body appendBytes:&dataForkEntryOffset length:sizeof(dataForkEntryOffset)];
	[body appendBytes:&dataForkEntryLength length:sizeof(dataForkEntryLength)];
	[body appendBytes:&resourceForkEntryID length:sizeof(resourceForkEntryID)];
	[body appendBytes:&resourceForkEntryOffset length:sizeof(resourceForkEntryOffset)];
	[body appendBytes:&resourceForkEntryLength length:sizeof(resourceForkEntryLength)];
	[body appendData:[NSMutableData dataWithLength:dataForkLength]];
	[body appendData:[NSMutableData dataWithLength:resourceForkLength]];
	return body;
}

/* Drives a transfer whose single file is the given AppleSingle body through the completion gate, with
 * the declared size given. Returns the transfer for success/artifact assertions. */
- (EKEzvIncomingFileTransfer *)transferWithAppleSingleBody:(NSData *)body
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

- (EKEzvIncomingFileTransfer *)transferDecodedWithRawLength:(NSUInteger)rawLength
											   declaredSize:(unsigned long long)declared
												   tempRoot:(NSString *)tempRoot
{
	return [self transferWithAppleSingleBody:[self appleSingleBodyWithRawLength:rawLength]
								declaredSize:declared
									tempRoot:tempRoot];
}

/* Content for the multi-entry bodies: each entry's content block is filled with a fixed byte that
 * identifies its role (data fork 0x01, resource fork 0x02, comment 0x03, Finder info 0x04), so the
 * properties can assert byte-exactly which fork was installed regardless of table order. */
- (NSData *)dataWithRepeatedByte:(uint8_t)byte length:(NSUInteger)length
{
	NSMutableData *data = [NSMutableData dataWithLength:length];
	if (length > 0) {
		memset([data mutableBytes], byte, length);
	}
	return data;
}

/* Fisher-Yates shuffle so the "last content entry wins" decode preference is exercised from every
 * table position, not just the data-fork-first layout the fixed tests hard-code (issue #275). */
- (void)shuffleEntries:(NSMutableArray *)entries
{
	for (NSUInteger i = [entries count] - 1; i > 0; i--) {
		NSUInteger j = PBTUniform((uint32_t)(i + 1));
		[entries exchangeObjectAtIndex:i withObjectAtIndex:j];
	}
}

/* AppleSingle body from an entry table. Each entry is a dictionary { @"id" : entryID, @"length" :
 * byteCount, @"fill" : contentByte }. The header is the standard 26 bytes, entries are laid out
 * sequentially in table order starting after the entry table, and each content block is filled with
 * its role byte (issue #275). */
- (NSData *)appleSingleBodyWithEntries:(NSArray<NSDictionary *> *)entries
{
	NSMutableData *body = [NSMutableData data];

	UInt32 magic = htonl(0x00051600);
	UInt32 version = htonl(0x00020000);
	UInt16 numberEntries = htons((UInt16)[entries count]);
	char filler[16] = {0};

	[body appendBytes:&magic length:sizeof(magic)];
	[body appendBytes:&version length:sizeof(version)];
	[body appendBytes:filler length:sizeof(filler)];
	[body appendBytes:&numberEntries length:sizeof(numberEntries)];

	UInt32 offset = (UInt32)(EKEZV_TEST_AS_HEADER_LENGTH + [entries count] * EKEZV_TEST_AS_ENTRY_LENGTH);
	for (NSDictionary *entry in entries) {
		UInt32 entryID = htonl((UInt32)[[entry objectForKey:@"id"] unsignedIntValue]);
		UInt32 entryOffset = htonl(offset);
		UInt32 entryLength = htonl((UInt32)[[entry objectForKey:@"length"] unsignedIntValue]);
		[body appendBytes:&entryID length:sizeof(entryID)];
		[body appendBytes:&entryOffset length:sizeof(entryOffset)];
		[body appendBytes:&entryLength length:sizeof(entryLength)];
		offset += (UInt32)[[entry objectForKey:@"length"] unsignedIntValue];
	}
	for (NSDictionary *entry in entries) {
		NSUInteger length = [[entry objectForKey:@"length"] unsignedIntegerValue];
		uint8_t fill = (uint8_t)[[entry objectForKey:@"fill"] unsignedIntValue];
		[body appendData:[self dataWithRepeatedByte:fill length:length]];
	}
	return body;
}

/* Convenience: build a body from raw [id, length, fill] tuples, the shape the multi-entry property
 * generators shuffle before building. */
- (NSData *)appleSingleBodyWithRawEntries:(NSArray<NSArray *> *)entries
{
	NSMutableArray *entryDicts = [NSMutableArray array];
	for (NSArray *entry in entries) {
		[entryDicts addObject:@{
			@"id" : [entry objectAtIndex:0],
			@"length" : [entry objectAtIndex:1],
			@"fill" : [entry objectAtIndex:2],
		}];
	}
	return [self appleSingleBodyWithEntries:entryDicts];
}

/* A raw [id, length, fill] entry tuple for appleSingleBodyWithRawEntries:. Built by a method — not a
 * collection literal — because the entry tables are constructed inside PBTCheck blocks, and the
 * preprocessor splits macro arguments on paren-depth-0 commas that both @[ ... ] and @{ ... } literals
 * put at that depth (issue #275). */
- (NSArray *)rawEntryWithID:(NSUInteger)entryID length:(NSUInteger)length fill:(uint8_t)fill
{
	return @[ @(entryID), @(length), @(fill) ];
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

/* Accounting drift: envelope bytes claimed (50) exceed bytes received (40). The unsigned subtraction
 * would wrap to a huge value and return NO (fail-open); the guard must fail closed and treat the
 * transfer as truncated (issue #269). */
- (void)testPredicateEnvelopeExceedingReceivedFailsClosed
{
	EKEzvIncomingFileTransfer *transfer = [[EKEzvIncomingFileTransfer alloc] init];
	[transfer setValue:[NSNumber numberWithLongLong:40] forKey:@"bytesReceived"];
	[transfer setValue:[NSNumber numberWithUnsignedLongLong:50] forKey:@"appleSingleEnvelopeBytes"];
	[transfer setSize:100];

	XCTAssertTrue([transfer transferWasTruncated],
				  @"envelope overhead exceeding received bytes must fail closed (issue #269)");
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

/* A dual-fork body [DATA_FORK(80), RESOURCE_FORK(5)] with declared size 80: the resource fork entry
 * comes last, but the data fork is the delivered file content, so decode must install the data fork
 * (80 bytes) — not the 5-byte resource fork — and the truncation check (80 raw >= 80 declared) must
 * pass. Before the data-fork-preference fix, the last-entry-wins write installed the resource fork
 * while the check still passed, silently delivering the wrong content (issue #269). */
- (void)testDualForkBodyInstallsDataFork
{
	NSString *tempRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvEnvelopeDualFork"];
	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];

	EKEzvIncomingFileTransfer *transfer = [self transferWithAppleSingleBody:[self appleSingleBodyWithDataForkLength:80
																								 resourceForkLength:5]
															   declaredSize:80
																   tempRoot:tempRoot];

	XCTAssertTrue([[transfer valueForKey:@"transferSucceeded"] boolValue],
				  @"a dual-fork body whose data fork meets the declared size must be accepted (issue #269)");
	NSString *receivedFile = [tempRoot stringByAppendingPathComponent:@"a/received.bin"];
	NSData *decoded = [[NSFileManager defaultManager] contentsAtPath:receivedFile];
	XCTAssertEqual([decoded length], (NSUInteger)80,
				   @"the data fork, not the resource fork, must be installed (issue #269)");

	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
}

/* Property: transferWasTruncated's full truth table over the whole 64-bit accounting domain, with
 * received bytes, envelope, and declared size each drawn boundary-biased up to UINT32_MAX — the
 * declared/wire values a real EZV transfer can carry. The oracle mirrors the predicate exactly: a
 * zero size never truncates, envelope exceeding received fails closed, and otherwise raw content
 * (received minus envelope) below the declared size truncates. This is where the 64-bit arithmetic
 * boundaries the roundtrip cannot materialize (UINT32_MAX - 1 / UINT32_MAX) get exercised, since
 * the predicate allocates nothing (issue #275). */
- (void)testTransferWasTruncatedProperty
{
	PBTCheckDefault({
		const uint64_t kMaxValue = UINT32_MAX;
		EKEzvIncomingFileTransfer *transfer = [[EKEzvIncomingFileTransfer alloc] init];
		uint64_t received = PBTBoundaryUInt64(kMaxValue + 1);
		uint64_t envelope = PBTBoundaryUInt64(kMaxValue + 1);
		uint64_t declared = PBTBoundaryUInt64(kMaxValue + 1);

		[transfer setValue:[NSNumber numberWithLongLong:(long long)received] forKey:@"bytesReceived"];
		[transfer setValue:[NSNumber numberWithUnsignedLongLong:envelope] forKey:@"appleSingleEnvelopeBytes"];
		[transfer setSize:declared];

		BOOL expectedTruncated;
		if (declared == 0) {
			expectedTruncated = NO;
		} else if (envelope > received) {
			expectedTruncated = YES;
		} else {
			expectedTruncated = (received - envelope) < declared;
		}
		BOOL actualTruncated = [transfer transferWasTruncated];
		if (expectedTruncated) {
			XCTAssertTrue(actualTruncated, @"received = %llu, envelope = %llu, declared = %llu",
						  (unsigned long long)received, (unsigned long long)envelope, (unsigned long long)declared);
		} else {
			XCTAssertFalse(actualTruncated, @"received = %llu, envelope = %llu, declared = %llu",
						   (unsigned long long)received, (unsigned long long)envelope, (unsigned long long)declared);
		}
	});
}

/* Property: the single data-fork wire-format roundtrip (appleSingleBodyWithRawLength: <->
 * decodeAppleSingleAtPath:). For a boundary-biased raw length in [0, 1 MiB] the body is 38 + N bytes
 * on the wire, decode writes exactly N raw bytes back, and the accumulated envelope is exactly 38
 * (header + one entry). The 1 MiB ceiling is a deliberate physical bound: the roundtrip materializes
 * the full wire body in memory and on disk, so the 4 GiB the UINT32_MAX boundaries would demand is
 * infeasible in CI — those arithmetic boundaries are covered by the allocation-free predicate
 * property instead. The N == 0 envelope-only case (the #269 gap, where the body is nothing but
 * envelope) and N == 1 are the low boundaries this sweep fires on (issue #275). */
- (void)testAppleSingleRoundtripProperty
{
	PBTCheckDefault({
		const uint64_t kMaxRawLength = 1 << 20; /* 1 MiB — see comment above */
		uint64_t rawLength = PBTBoundaryUInt64(kMaxRawLength + 1);

		NSString *tempRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvRoundtripProp"];
		[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];

		NSData *body = [self appleSingleBodyWithRawLength:(NSUInteger)rawLength];
		XCTAssertEqual([body length], (NSUInteger)(38 + rawLength),
					   @"rawLength = %llu: a single data-fork body must be 38 + N bytes on the wire",
					   (unsigned long long)rawLength);

		EKEzvIncomingFileTransfer *transfer = [self transferWithAppleSingleBody:body
																   declaredSize:rawLength
																	   tempRoot:tempRoot];

		NSString *receivedFile = [tempRoot stringByAppendingPathComponent:@"a/received.bin"];
		XCTAssertTrue([[transfer valueForKey:@"transferSucceeded"] boolValue],
					  @"rawLength = %llu: a body whose raw content meets the declared size must be accepted",
					  (unsigned long long)rawLength);
		NSData *decoded = [[NSFileManager defaultManager] contentsAtPath:receivedFile];
		XCTAssertEqual([decoded length], (NSUInteger)rawLength,
					   @"rawLength = %llu: decode must write exactly N raw bytes", (unsigned long long)rawLength);
		XCTAssertTrue([decoded isEqualToData:[NSMutableData dataWithLength:(NSUInteger)rawLength]],
					  @"rawLength = %llu: the decoded file must be the data fork content, not the envelope",
					  (unsigned long long)rawLength);
		XCTAssertEqual([[transfer valueForKey:@"appleSingleEnvelopeBytes"] unsignedLongLongValue],
					   (unsigned long long)38,
					   @"rawLength = %llu: a single data-fork body must accumulate exactly 38 envelope bytes",
					   (unsigned long long)rawLength);

		[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
	});
}

/* The structurally distinct raw lengths the roundtrip sweep's boundary generator can miss: N == 0
 * (envelope-only — the #269 gap case), N == 1 (single content byte), and N == 38 (raw size equals
 * the envelope overhead). Each must round-trip: 38 + N on the wire, N bytes written, 38 bytes of
 * envelope. The UINT32_MAX - 1 / UINT32_MAX endpoints are covered by the allocation-free predicate
 * property (testTransferWasTruncatedProperty), which sweeps the full 64-bit arithmetic domain
 * (issue #275). */
- (void)testAppleSingleRoundtripStructuralBoundaries
{
	for (NSNumber *rawNumber in @[ @0, @1, @38 ]) {
		NSUInteger rawLength = [rawNumber unsignedIntegerValue];
		NSString *tempRoot = [NSTemporaryDirectory()
			stringByAppendingPathComponent:[NSString
											   stringWithFormat:@"EKEzvRoundtripFixed-%lu", (unsigned long)rawLength]];
		[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];

		NSData *body = [self appleSingleBodyWithEntries:@[ @{
								 @"id" : @(EKEZV_TEST_AS_DATA_FORK_ENTRY_ID),
								 @"length" : @(rawLength),
								 @"fill" : @(0x01),
							 } ]];
		XCTAssertEqual([body length], (NSUInteger)(38 + rawLength), @"N = %lu", (unsigned long)rawLength);

		EKEzvIncomingFileTransfer *transfer = [self transferWithAppleSingleBody:body
																   declaredSize:rawLength
																	   tempRoot:tempRoot];

		NSString *receivedFile = [tempRoot stringByAppendingPathComponent:@"a/received.bin"];
		XCTAssertTrue([[transfer valueForKey:@"transferSucceeded"] boolValue], @"N = %lu", (unsigned long)rawLength);
		NSData *decoded = [[NSFileManager defaultManager] contentsAtPath:receivedFile];
		XCTAssertEqual([decoded length], rawLength, @"N = %lu", (unsigned long)rawLength);
		XCTAssertTrue([decoded isEqualToData:[self dataWithRepeatedByte:0x01 length:rawLength]], @"N = %lu",
					  (unsigned long)rawLength);
		XCTAssertEqual([[transfer valueForKey:@"appleSingleEnvelopeBytes"] unsignedLongLongValue],
					   (unsigned long long)38, @"N = %lu", (unsigned long)rawLength);

		[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
	}
}

/* The #269 gap case end-to-end: an envelope-only body (0 raw bytes, 38 wire bytes) with a non-zero
 * declared size must fail the truncation check and remove its artifacts — the envelope overhead must
 * not mask the missing content (issue #275). */
- (void)testEnvelopeOnlyBodyWithNonZeroDeclaredSizeIsTruncated
{
	NSString *tempRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvEnvelopeOnlyRejected"];
	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];

	EKEzvIncomingFileTransfer *transfer = [self transferDecodedWithRawLength:0 declaredSize:100 tempRoot:tempRoot];

	XCTAssertFalse([[transfer valueForKey:@"transferSucceeded"] boolValue],
				   @"an envelope-only body must not be accepted when a non-zero size is declared (issue #275)");
	XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:tempRoot],
				   @"a truncated envelope-only body must remove its artifacts (issue #275)");

	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
}

/* Property: envelope accounting across a random multi-entry body (data fork, resource fork, comment,
 * Finder info in any table order). The decode installs the data fork — whatever else appears later —
 * and subtracts only the data fork length from the wire length for the envelope, so a body whose
 * data fork meets the declared size is accepted with the data fork as the decoded file (issue #275).
 * This is the property generalization of the fixed dual-fork case. */
- (void)testMultiEntryEnvelopeAccountingProperty
{
	PBTCheckDefault({
		NSUInteger dataForkLength = (NSUInteger)PBTBoundaryUInt64(1 << 16);
		NSMutableArray *entries = [NSMutableArray array];
		[entries addObject:[self rawEntryWithID:EKEZV_TEST_AS_DATA_FORK_ENTRY_ID length:dataForkLength fill:0x01]];
		if (PBTRandomBool()) {
			[entries addObject:[self rawEntryWithID:EKEZV_TEST_AS_RESOURCE_FORK_ENTRY_ID
											 length:(NSUInteger)PBTBoundaryUInt64(1 << 16)
											   fill:0x02]];
		}
		if (PBTRandomBool()) {
			[entries addObject:[self rawEntryWithID:EKEZV_TEST_AS_COMMENT_ENTRY_ID
											 length:(NSUInteger)PBTBoundaryUInt64(1 << 12)
											   fill:0x03]];
		}
		if (PBTRandomBool()) {
			[entries addObject:[self rawEntryWithID:EKEZV_TEST_AS_FINDER_INFO_ENTRY_ID
											 length:EKEZV_TEST_AS_FINDER_INFO_LENGTH
											   fill:0x04]];
		}
		[self shuffleEntries:entries];
		NSData *body = [self appleSingleBodyWithRawEntries:entries];

		NSString *tempRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvMultiEntryProp"];
		[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];

		EKEzvIncomingFileTransfer *transfer = [self transferWithAppleSingleBody:body
																   declaredSize:dataForkLength
																	   tempRoot:tempRoot];

		NSString *receivedFile = [tempRoot stringByAppendingPathComponent:@"a/received.bin"];
		XCTAssertTrue(
			[[transfer valueForKey:@"transferSucceeded"] boolValue],
			@"dataForkLength = %lu: a multi-entry body whose data fork meets the declared size must be accepted",
			(unsigned long)dataForkLength);
		NSData *decoded = [[NSFileManager defaultManager] contentsAtPath:receivedFile];
		XCTAssertTrue([decoded isEqualToData:[self dataWithRepeatedByte:0x01 length:dataForkLength]],
					  @"dataForkLength = %lu: the data fork, not the resource fork or envelope, must be installed",
					  (unsigned long)dataForkLength);
		XCTAssertEqual([[transfer valueForKey:@"appleSingleEnvelopeBytes"] unsignedLongLongValue],
					   (unsigned long long)([body length] - dataForkLength),
					   @"dataForkLength = %lu: the envelope subtracts only the data fork length from the wire bytes",
					   (unsigned long)dataForkLength);

		[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
	});
}

/* Property: a resource-fork-only body (no data fork) counts its whole content as envelope, so the
 * raw content measures as 0 bytes. Per the issue-269 design that is the documented false-positive
 * path: a non-zero declared size fails loudly on untrusted data, while a zero declared size (not
 * cross-checkable) is accepted and installs the resource fork (issue #275). */
- (void)testResourceForkOnlyBodyAccountingProperty
{
	PBTCheckDefault({
		NSUInteger resourceForkLength = (NSUInteger)PBTBoundaryUInt64(1 << 16);
		NSMutableArray *entries = [NSMutableArray array];
		[entries addObject:[self rawEntryWithID:EKEZV_TEST_AS_RESOURCE_FORK_ENTRY_ID
										 length:resourceForkLength
										   fill:0x02]];
		if (PBTRandomBool()) {
			[entries addObject:[self rawEntryWithID:EKEZV_TEST_AS_COMMENT_ENTRY_ID
											 length:(NSUInteger)PBTBoundaryUInt64(1 << 12)
											   fill:0x03]];
		}
		if (PBTRandomBool()) {
			[entries addObject:[self rawEntryWithID:EKEZV_TEST_AS_FINDER_INFO_ENTRY_ID
											 length:EKEZV_TEST_AS_FINDER_INFO_LENGTH
											   fill:0x04]];
		}
		[self shuffleEntries:entries];
		NSData *body = [self appleSingleBodyWithRawEntries:entries];

		/* Declared 0 → not cross-checkable, accepted; the resource fork is what gets installed. */
		NSString *tempRootAccept = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvResourceOnlyAccept"];
		[[NSFileManager defaultManager] removeItemAtPath:tempRootAccept error:NULL];
		EKEzvIncomingFileTransfer *accept = [self transferWithAppleSingleBody:body
																 declaredSize:0
																	 tempRoot:tempRootAccept];
		NSString *receivedFile = [tempRootAccept stringByAppendingPathComponent:@"a/received.bin"];
		XCTAssertTrue([[accept valueForKey:@"transferSucceeded"] boolValue], @"resourceForkLength = %lu",
					  (unsigned long)resourceForkLength);
		NSData *decoded = [[NSFileManager defaultManager] contentsAtPath:receivedFile];
		XCTAssertTrue([decoded isEqualToData:[self dataWithRepeatedByte:0x02 length:resourceForkLength]],
					  @"resourceForkLength = %lu: the resource fork must be installed",
					  (unsigned long)resourceForkLength);
		XCTAssertEqual([[accept valueForKey:@"appleSingleEnvelopeBytes"] unsignedLongLongValue],
					   (unsigned long long)[body length],
					   @"resourceForkLength = %lu: a data-fork-free body counts its whole content as envelope",
					   (unsigned long)resourceForkLength);
		[[NSFileManager defaultManager] removeItemAtPath:tempRootAccept error:NULL];

		/* The documented false-positive path: a non-zero declared size fails loudly because the raw
		 * content measures 0 bytes against it (issue #269). A zero-length resource fork with a zero
		 * declared size is not cross-checkable and is accepted. */
		NSString *tempRootReject = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvResourceOnlyReject"];
		[[NSFileManager defaultManager] removeItemAtPath:tempRootReject error:NULL];
		EKEzvIncomingFileTransfer *reject = [self transferWithAppleSingleBody:body
																 declaredSize:resourceForkLength
																	 tempRoot:tempRootReject];
		BOOL shouldReject = resourceForkLength > 0;
		XCTAssertEqual([[reject valueForKey:@"transferSucceeded"] boolValue], !shouldReject,
					   @"resourceForkLength = %lu: a resource-fork-only body with a non-zero declared size must fail",
					   (unsigned long)resourceForkLength);
		if (shouldReject) {
			XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:tempRootReject],
						   @"a rejected resource-fork-only body must remove its artifacts (issue #275)");
		}
		[[NSFileManager defaultManager] removeItemAtPath:tempRootReject error:NULL];
	});
}

@end
