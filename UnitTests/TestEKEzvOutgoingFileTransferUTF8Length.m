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
 * UTF-8 length bug (issue #252): generateDirectoryXML serialized the folder XML with
 * [NSData dataWithBytes:[xmlString UTF8String] length:[xmlString length]], using the UTF-16
 * code-unit count as the UTF-8 byte count. Any non-ASCII filename makes the UTF-8 byte count
 * exceed the UTF-16 count, so the NSData is a truncated prefix of the XML — cut mid-tag or
 * mid-multibyte-sequence — and the receiver's NSXMLDocument parse fails. The folder XML must
 * parse as well-formed XML and round-trip non-ASCII filenames.
 */
@interface TestEKEzvOutgoingFileTransferUTF8Length : XCTestCase
@end

@implementation TestEKEzvOutgoingFileTransferUTF8Length

- (void)testDirectoryXMLParsesWithNonASCIIFilenames
{
	NSString *tempRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvOutgoingUTF8Length"];
	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
	[[NSFileManager defaultManager] createDirectoryAtPath:tempRoot
							  withIntermediateDirectories:YES
											   attributes:nil
													error:NULL];

	NSString *accentedFile = [tempRoot stringByAppendingPathComponent:@"café.txt"];
	[[NSFileManager defaultManager] createFileAtPath:accentedFile contents:[NSData data] attributes:nil];
	NSString *cjkFile = [tempRoot stringByAppendingPathComponent:@"文件.txt"];
	[[NSFileManager defaultManager] createFileAtPath:cjkFile contents:[NSData data] attributes:nil];

	EKEzvOutgoingFileTransfer *transfer = [[EKEzvOutgoingFileTransfer alloc] init];
	[transfer setLocalFilename:tempRoot];

	NSData *xmlData = [transfer generateDirectoryXML];
	XCTAssertNotNil(xmlData, @"folder XML generation must succeed");

	NSError *error = nil;
	NSXMLDocument *document = [[NSXMLDocument alloc] initWithData:xmlData options:0 error:&error];
	XCTAssertNil(error, @"folder XML with non-ASCII filenames must be valid UTF-8, not a truncated byte prefix: %@", error);
	XCTAssertNotNil(document, @"folder XML with non-ASCII filenames must parse as well-formed XML");

	NSString *xml = [[NSString alloc] initWithData:xmlData encoding:NSUTF8StringEncoding];

	/* macOS stores filenames in NFD and returns them that way, so the test's NFC literals would
	 * never match the file system's actual names — compare the XML against the on-disk names. */
	NSArray *realNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tempRoot error:NULL];
	XCTAssertEqual([realNames count], (NSUInteger)2, @"both non-ASCII files must exist on disk");
	for (NSString *name in realNames) {
		XCTAssertTrue([xml containsString:name],
					   @"on-disk filename %@ must round-trip through the folder XML", name);
	}

	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
}

@end
