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

#import "AWEzvStack.h"
#import "AWEzvXMLNode.h"
#import "AWEzvXMLStream.h"
#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

/*
 * Parse-side depth cap (issue #252): AWEzvXMLStream builds an AWEzvXMLNode tree with no bound, and
 * AWEzvXMLNode's dealloc releases its children recursively — a peer that nests elements without
 * limit hands us an N-deep tree that takes N stack frames to free, a stack overflow. The stream
 * must drop elements past AWEZVXML_MAX_DEPTH so the tree (and its recursive dealloc) stays bounded.
 */
@interface TestStreamDepthCapDelegate : NSObject <AWEzvXMLStreamProtocol>
@property(nonatomic, strong) AWEzvXMLNode *receivedRoot;
@end

@implementation TestStreamDepthCapDelegate

- (void)XMLConnectionClosed
{}

- (void)XMLReceived:(AWEzvXMLNode *)root
{
	[self setReceivedRoot:root];
}

- (NSString *)uniqueID
{
	return @"test-depth-cap";
}

- (AWEzvContactManager *)manager
{
	return nil;
}

@end

@interface TestAWEzvXMLStreamDepthCap : XCTestCase
@end

@implementation TestAWEzvXMLStreamDepthCap

- (NSUInteger)treeDepth:(AWEzvXMLNode *)node
{
	NSUInteger maxChildDepth = 0;
	for (AWEzvXMLNode *child in [node children]) {
		maxChildDepth = MAX(maxChildDepth, [self treeDepth:child]);
	}
	return 1 + maxChildDepth;
}

/* Open 200 nested elements — far past the cap of 32 — then close them all. The element stack must
 * never grow past the cap, and the delivered root must be a capped tree, so dealloc never recurses
 * more than 32 deep. */
- (void)testElementStackAndDeliveredTreeAreBounded
{
	AWEzvXMLStream *stream = [[AWEzvXMLStream alloc] initWithFileHandle:nil initiator:0];
	TestStreamDepthCapDelegate *delegate = [[TestStreamDepthCapDelegate alloc] init];
	[stream setDelegate:delegate];

	const XML_Char *noAttributes[] = {NULL};
	for (NSUInteger i = 0; i < 200; i++) {
		[stream xmlStartElement:"a" attributes:noAttributes];
	}

	AWEzvStack *stack = [stream valueForKey:@"nodeStack"];
	XCTAssertLessThanOrEqual([stack size], (unsigned int)AWEZVXML_MAX_DEPTH,
							 @"the element stack must never grow past the depth cap");

	for (NSUInteger i = 0; i < 200; i++) {
		[stream xmlEndElement:"a"];
	}

	AWEzvXMLNode *root = [delegate receivedRoot];
	XCTAssertNotNil(root, @"the capped tree must still be delivered once the stack empties");
	XCTAssertLessThanOrEqual([self treeDepth:root], (NSUInteger)AWEZVXML_MAX_DEPTH,
							 @"the delivered tree must be capped so dealloc stays bounded");
}

@end
