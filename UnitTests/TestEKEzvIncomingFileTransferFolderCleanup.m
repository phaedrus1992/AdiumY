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
 * downloadFolder:path:url: creates each directory as it walks the peer-supplied tree. When a later
 * child fails (invalid name, depth cap), the directories created before the failure were left on
 * disk (issue #191). The walk must remove what it created on failure, leaving the temp root empty.
 */
@interface TestEKEzvIncomingFileTransferFolderCleanup : XCTestCase
@end

@implementation TestEKEzvIncomingFileTransferFolderCleanup

- (NSXMLElement *)dirElementNamed:(NSString *)name
{
	NSXMLElement *dir = [[NSXMLElement alloc] initWithName:@"dir"];
	NSXMLElement *nameElement = [[NSXMLElement alloc] initWithName:@"name"];
	[nameElement setStringValue:name];
	[dir addChild:nameElement];
	return dir;
}

/* Root <dir> "a" containing a nested <dir> whose name is invalid (".."). The walk creates
 * <tempRoot>/a, then fails validating the inner name; the created directory must be removed. */
- (void)testInvalidChildNameRemovesCreatedDirectories
{
	NSString *tempRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvFolderCleanupInvalidName"];
	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];

	NSXMLElement *outer = [self dirElementNamed:@"a"];
	[outer addChild:[self dirElementNamed:@".."]];

	EKEzvIncomingFileTransfer *transfer = [[EKEzvIncomingFileTransfer alloc] init];
	BOOL result = [transfer downloadFolder:outer path:tempRoot url:@"http://example.com/base"];

	XCTAssertFalse(result, @"a nested <dir> with an invalid name must fail the transfer");
	NSString *createdDir = [tempRoot stringByAppendingPathComponent:@"a"];
	XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:createdDir],
				   @"directories created before the failing child must be removed");

	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
}

/* A tree nested past the depth cap creates dirs level-1..level-32 before failing at level-33. All
 * created directories must be removed, leaving the temp root empty. */
- (void)testDepthCapFailureRemovesCreatedDirectories
{
	NSString *tempRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvFolderCleanupDepthCap"];
	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];

	NSXMLElement *node = [self dirElementNamed:@"level-1"];
	NSXMLElement *outer = node;
	for (NSUInteger i = 2; i <= 40; i++) {
		NSXMLElement *child = [self dirElementNamed:[NSString stringWithFormat:@"level-%lu", (unsigned long)i]];
		[node addChild:child];
		node = child;
	}

	EKEzvIncomingFileTransfer *transfer = [[EKEzvIncomingFileTransfer alloc] init];
	BOOL result = [transfer downloadFolder:outer path:tempRoot url:@"http://example.com/base"];

	XCTAssertFalse(result, @"folder tree nested past the depth cap must fail the transfer");
	NSArray *remaining = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tempRoot error:NULL];
	XCTAssertEqual([remaining count], (NSUInteger)0, @"no directories may be left behind after a depth-cap failure");

	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
}

@end
