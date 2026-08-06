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

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import "EKEzvIncomingFileTransfer.h"

/*
 * EKEzvIncomingFileTransfer downloadFolder:path:url: recurses into peer-supplied <dir> children
 * with no depth bound; a malicious Bonjour contact can force unbounded recursion by nesting
 * <dir> elements arbitrarily deep. The transfer must fail (return NO) past the fixed cap
 * (EKEZVFOLDER_MAX_DEPTH == 32, defined in the implementation), rather than recurse further.
 */
@interface TestEKEzvIncomingFileTransferDepthCap : XCTestCase
@end

@implementation TestEKEzvIncomingFileTransferDepthCap

- (NSXMLElement *)dirElementNamed:(NSString *)name
{
	NSXMLElement *dir = [[NSXMLElement alloc] initWithName:@"dir"];
	NSXMLElement *nameElement = [[NSXMLElement alloc] initWithName:@"name"];
	[nameElement setStringValue:name];
	[dir addChild:nameElement];
	return dir;
}

- (void)testFolderDownloadFailsPastDepthCap
{
	/* Innermost leaf, then wrap it in 40 parent <dir>s: the outermost element is the
	 * depth-1 root, so the innermost <dir> sits at depth 41 — safely past the cap of 32. */
	NSXMLElement *node = [self dirElementNamed:@"level-40"];
	for (NSUInteger i = 0; i < 40; i++) {
		NSXMLElement *parent = [self dirElementNamed:[NSString stringWithFormat:@"level-%lu", (unsigned long)i]];
		[parent addChild:node];
		node = parent;
	}

	NSString *tempRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvDepthCapTest"];
	EKEzvIncomingFileTransfer *transfer = [[EKEzvIncomingFileTransfer alloc] init];
	BOOL result = [transfer downloadFolder:node path:tempRoot url:@"http://example.com/base"];

	XCTAssertFalse(result, @"folder tree nested past the depth cap must fail the transfer");
	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
}

- (void)testFolderDownloadSucceedsShallowTree
{
	/* A shallow tree well under the cap still downloads normally. */
	NSXMLElement *dir = [self dirElementNamed:@"level-0"];
	[dir addChild:[self dirElementNamed:@"level-1"]];

	NSString *tempRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvDepthCapShallowTest"];
	EKEzvIncomingFileTransfer *transfer = [[EKEzvIncomingFileTransfer alloc] init];
	BOOL result = [transfer downloadFolder:dir path:tempRoot url:@"http://example.com/base"];

	XCTAssertTrue(result, @"shallow folder tree must download successfully");
	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
}

@end
