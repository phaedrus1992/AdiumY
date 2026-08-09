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

#import "AWEzvXMLNode.h"
#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

/*
 * AWEzvXMLNode -xmlString recurses once per element depth with no bound of its own; a peer-supplied
 * <message><html> tree nested past AWEZVXML_MAX_DEPTH would overflow the stack on OSes with an
 * unbounded expat nesting limit (issue #190). The serializer must drop content past the cap instead
 * of recursing without bound, in both -xmlString and -description.
 */
@interface TestAWEzvXMLNodeSerializationDepth : XCTestCase
@end

@implementation TestAWEzvXMLNodeSerializationDepth

/* Chain of AWEzvXMLNode elements whose innermost element sits at the given depth (the returned root
 * is depth 0). Each level is named "level-<depth>" so the serialized output is greppable. */
- (AWEzvXMLNode *)chainWithDepth:(NSUInteger)depth
{
	AWEzvXMLNode *node = [[AWEzvXMLNode alloc] initWithType:AWEzvXMLElement name:@"leaf"];
	for (NSInteger i = (NSInteger)depth - 1; i >= 0; i--) {
		AWEzvXMLNode *parent = [[AWEzvXMLNode alloc] initWithType:AWEzvXMLElement
															 name:[NSString stringWithFormat:@"level-%ld", (long)i]];
		[parent addChild:node];
		node = parent;
	}
	return node;
}

- (void)testXmlStringCapsSerializationDepth
{
	NSString *xml = [[self chainWithDepth:40] xmlString];

	XCTAssertTrue([xml containsString:@"<level-32"], @"nodes at the cap depth must still serialize");
	XCTAssertFalse([xml containsString:@"level-33"], @"content past the depth cap must be dropped, not recursed");
	XCTAssertFalse([xml containsString:@"level-39"], @"deep content must not be serialized");
}

- (void)testXmlStringSerializesShallowTree
{
	NSString *xml = [[self chainWithDepth:10] xmlString];

	XCTAssertTrue([xml containsString:@"<level-0"], @"a shallow tree must keep its root");
	XCTAssertTrue([xml containsString:@"level-9"], @"a shallow tree under the cap must serialize fully");
}

- (void)testDescriptionCapsSerializationDepth
{
	NSString *description = [[self chainWithDepth:40] description];

	/* -description serializes each direct child with the full cap, so a single-child chain of 40 is
	 * serialized up to level-33 (the cap depth reached from level-1); the tail past the cap must not
	 * appear. */
	XCTAssertFalse([description containsString:@"level-39"],
				   @"description must not serialize the full depth of a capped tree");
}

- (void)testXmlStringWithMaxDepthZeroOmitsChildren
{
	AWEzvXMLNode *parent = [[AWEzvXMLNode alloc] initWithType:AWEzvXMLElement name:@"parent"];
	[parent addChild:[[AWEzvXMLNode alloc] initWithType:AWEzvXMLElement name:@"child"]];

	NSString *xml = [parent xmlStringWithMaxDepth:0];

	XCTAssertEqualObjects(xml, @"<parent></parent>", @"maxDepth 0 must serialize only the element's own tag");
}

@end
