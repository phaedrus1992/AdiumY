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

#import "EKEzvOutgoingFileTransfer.h"
#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

/*
 * The HTTPServer class reference (issue #250) is resolved by the shared stub in HTTPServerStub.m —
 * see that file for why the test bundle needs it.
 *
 * Send/receive depth-cap asymmetry (issue #250): the receiver (EKEzvIncomingFileTransfer.m) fails
 * any element nested deeper than EKEZVFOLDER_MAX_DEPTH (32, root element = depth 1), but the sender
 * (EKEzvOutgoingFileTransfer.m) recursed without bound, emitting XML the receiver would reject. The
 * sender must not emit any entry deeper than depth 32. A chain d0..d35 under the root folder maps:
 * root = depth 1, dk = depth k+2, so d30 is the deepest accepted entry (depth 32) and d31 (depth 33)
 * must not be emitted.
 */
@interface TestEKEzvOutgoingFileTransferDepthCap : XCTestCase
@end

@implementation TestEKEzvOutgoingFileTransferDepthCap

- (void)testDirectoryXMLStopsAtReceiverDepthCap
{
	NSString *tempRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvOutgoingDepthCap"];
	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];

	NSString *current = tempRoot;
	for (NSUInteger i = 0; i <= 35; i++) {
		current = [current stringByAppendingPathComponent:[NSString stringWithFormat:@"d%lu", (unsigned long)i]];
	}
	[[NSFileManager defaultManager] createDirectoryAtPath:current
							  withIntermediateDirectories:YES
											   attributes:nil
													error:NULL];

	EKEzvOutgoingFileTransfer *transfer = [[EKEzvOutgoingFileTransfer alloc] init];
	[transfer setLocalFilename:tempRoot];

	NSData *xmlData = [transfer generateDirectoryXML];
	NSString *xml = [[NSString alloc] initWithData:xmlData encoding:NSUTF8StringEncoding];

	XCTAssertNotNil(xmlData, @"folder XML generation must succeed for a deep-but-capped tree");
	XCTAssertTrue([xml containsString:@"<name>d30</name>"], @"the entry at depth 32 must be emitted (d30)");
	XCTAssertFalse([xml containsString:@"<name>d31</name>"],
				   @"no entry may be emitted deeper than depth 32 (d31 would be depth 33)");

	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
}

/* getData registers every file in the tree into urlData/urlSizes and sums their sizes, while the
 * generated XML stops at the receiver's depth cap. A file deeper than the cap would be registered
 * but never appear in the XML, so the receiver never requests it, urlData never empties, and
 * moreFilesToDownload keeps the server alive forever — the #250 hang. getData must apply the same
 * depth cap as generateXMLFromDirectory:depth: (root = depth 1, entries past depth 32 excluded).
 */
- (void)testGetDataSkipsEntriesDeeperThanReceiverDepthCap
{
	NSString *tempRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvOutgoingGetDataDepthCap"];
	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];

	/* d33 sits at depth 35; a file inside it would be depth 36, well past the cap of 32. */
	NSString *current = tempRoot;
	for (NSUInteger i = 0; i <= 33; i++) {
		current = [current stringByAppendingPathComponent:[NSString stringWithFormat:@"d%lu", (unsigned long)i]];
	}
	[[NSFileManager defaultManager] createDirectoryAtPath:current
							  withIntermediateDirectories:YES
											   attributes:nil
													error:NULL];
	NSString *deepFile = [current stringByAppendingPathComponent:@"deep.bin"];
	[[NSFileManager defaultManager] createFileAtPath:deepFile
										   contents:[NSData dataWithBytes:"x" length:1]
										  attributes:nil];
	NSString *shallowFile = [tempRoot stringByAppendingPathComponent:@"shallow.bin"];
	[[NSFileManager defaultManager] createFileAtPath:shallowFile
										   contents:[NSData dataWithBytes:"y" length:1]
										  attributes:nil];

	EKEzvOutgoingFileTransfer *transfer = [[EKEzvOutgoingFileTransfer alloc] init];
	[transfer setValue:@YES forKey:@"isDirectory"];
	[transfer setLocalFilename:tempRoot];

	BOOL success = [transfer getData];
	XCTAssertTrue(success, @"getData must succeed for the deep-but-capped tree");

	NSDictionary *urlData = [transfer valueForKey:@"urlData"];
	for (NSString *key in urlData) {
		XCTAssertLessThanOrEqual([[key pathComponents] count], (NSUInteger)32,
								   @"urlData key %@ must not exceed the receiver depth cap", key);
	}

	NSString *shallowSubPath = [[tempRoot lastPathComponent] stringByAppendingPathComponent:@"shallow.bin"];
	XCTAssertNotNil([urlData objectForKey:shallowSubPath], @"a file at depth 2 must still be registered");

	XCTAssertEqual([transfer size], (unsigned long long)1,
				   @"transfer size must exclude the file past the depth cap");

	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
}

@end
