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

/* Nested tree whose innermost <dir> sits at the given depth (the outermost element is depth 1). */
- (NSXMLElement *)treeWithDepth:(NSUInteger)depth
{
	NSXMLElement *node = [self dirElementNamed:[NSString stringWithFormat:@"level-%lu", (unsigned long)depth]];
	for (NSUInteger i = 1; i < depth; i++) {
		NSXMLElement *parent = [self dirElementNamed:[NSString stringWithFormat:@"level-%lu", (unsigned long)i]];
		[parent addChild:node];
		node = parent;
	}
	return node;
}

- (BOOL)downloadTree:(NSXMLElement *)tree
{
	NSString *tempRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvDepthCapTest"];
	EKEzvIncomingFileTransfer *transfer = [[EKEzvIncomingFileTransfer alloc] init];
	BOOL result = [transfer downloadFolder:tree path:tempRoot url:@"http://example.com/base"];
	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
	return result;
}

- (void)testFolderDownloadFailsPastDepthCap
{
	/* Innermost leaf at depth 41 — safely past the cap of 32. */
	BOOL result = [self downloadTree:[self treeWithDepth:41]];

	XCTAssertFalse(result, @"folder tree nested past the depth cap must fail the transfer");
}

- (void)testFolderDownloadSucceedsAtCapBoundary
{
	/* Innermost <dir> exactly at the cap (depth 32) must still download. */
	BOOL result = [self downloadTree:[self treeWithDepth:32]];

	XCTAssertTrue(result, @"folder tree exactly at the depth cap must download successfully");
}

- (void)testFolderDownloadFailsOnePastCapBoundary
{
	/* One past the cap (depth 33) must fail — pins the off-by-one of the depth comparison. */
	BOOL result = [self downloadTree:[self treeWithDepth:33]];

	XCTAssertFalse(result, @"folder tree one past the depth cap must fail the transfer");
}

- (void)testFolderDownloadSucceedsShallowTree
{
	/* A shallow tree well under the cap still downloads normally. */
	BOOL result = [self downloadTree:[self treeWithDepth:2]];

	XCTAssertTrue(result, @"shallow folder tree must download successfully");
}

@end
