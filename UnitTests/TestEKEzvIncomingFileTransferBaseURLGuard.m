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

/*
 * Issue #270: downloadFolder:path:url:depth: builds every child URL by string concatenation
 * (stringByAppendingPathComponent: + percent-encoding). A query or fragment on the peer-supplied base
 * URL survives the concatenation and lands inside the child path, so child files are silently
 * addressed at mangled URLs. The #264 guard only catches unparseable URLs — a mangled-but-parseable
 * URL passes through. A query/fragment-bearing base URL must fail the walk at the start.
 */
@interface TestEKEzvIncomingFileTransferBaseURLGuard : XCTestCase
@end

@implementation TestEKEzvIncomingFileTransferBaseURLGuard

- (NSXMLElement *)dirElementNamed:(NSString *)name
{
	NSXMLElement *dir = [[NSXMLElement alloc] initWithName:@"dir"];
	NSXMLElement *nameElement = [[NSXMLElement alloc] initWithName:@"name"];
	[nameElement setStringValue:name];
	[dir addChild:nameElement];
	return dir;
}

- (BOOL)downloadTree:(NSXMLElement *)tree withURL:(NSString *)baseURL
{
	NSString *tempRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvBaseURLGuardTest"];
	EKEzvIncomingFileTransfer *transfer = [[EKEzvIncomingFileTransfer alloc] init];
	BOOL result = [transfer downloadFolder:tree path:tempRoot url:baseURL];
	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
	return result;
}

- (void)testQueryInBaseURLFailsTransfer
{
	NSXMLElement *tree = [self dirElementNamed:@"a"];
	BOOL result = [self downloadTree:tree withURL:@"http://example.com/base?token=abc123"];

	XCTAssertFalse(result,
				   @"a base URL carrying a query would mangle child addresses and must fail the transfer (issue #270)");
}

- (void)testFragmentInBaseURLFailsTransfer
{
	NSXMLElement *tree = [self dirElementNamed:@"a"];
	BOOL result = [self downloadTree:tree withURL:@"http://example.com/base#section"];

	XCTAssertFalse(
		result, @"a base URL carrying a fragment would mangle child addresses and must fail the transfer (issue #270)");
}

- (void)testCleanBaseURLSucceeds
{
	NSXMLElement *tree = [self dirElementNamed:@"a"];
	BOOL result = [self downloadTree:tree withURL:@"http://example.com/base"];

	XCTAssertTrue(result, @"a clean base URL must still download normally (issue #270)");
}

- (void)testPercentEncodedPathNotTreatedAsQuery
{
	/* A percent-encoded "?" (%3F) lives in the path, not in a query; it must not be rejected. */
	NSXMLElement *tree = [self dirElementNamed:@"a"];
	BOOL result = [self downloadTree:tree withURL:@"http://example.com/base%3Fpage"];

	XCTAssertTrue(result, @"a percent-encoded '?' in the path must not be mistaken for a query (issue #270)");
}

@end
