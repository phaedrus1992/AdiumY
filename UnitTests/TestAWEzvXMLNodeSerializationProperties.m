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
#import "AIPropertyTestUtilities.h"
#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

/*
 * Property-level tests for AWEzvXMLNode serialization (issue #190): the depth cap on -xmlString /
 * -description must be per-path and balanced, text nodes must escape in a single pass, text/raw
 * nodes must be uncapped pass-throughs, attributes must serialize as key="value", and the two
 * entry points must cap at their documented (off-by-one) depths. These complement the substring
 * depth tests in TestAWEzvXMLNodeSerializationDepth.m.
 */
@interface TestAWEzvXMLNodeSerializationProperties : XCTestCase
@end

@implementation TestAWEzvXMLNodeSerializationProperties

/* Chain of AWEzvXMLNode elements named "level-<i>" whose innermost node is the given leaf at the
 * requested depth (the returned root is depth 0). */
- (AWEzvXMLNode *)chainWithDepth:(NSUInteger)depth leaf:(AWEzvXMLNode *)leaf
{
	AWEzvXMLNode *node = leaf;
	for (NSInteger i = (NSInteger)depth - 1; i >= 0; i--) {
		AWEzvXMLNode *parent = [[AWEzvXMLNode alloc] initWithType:AWEzvXMLElement
															 name:[NSString stringWithFormat:@"level-%ld", (long)i]];
		[parent addChild:node];
		node = parent;
	}
	return node;
}

- (AWEzvXMLNode *)chainWithDepth:(NSUInteger)depth
{
	return [self chainWithDepth:depth leaf:[[AWEzvXMLNode alloc] initWithType:AWEzvXMLElement name:@"leaf"]];
}

/* Text serialization must escape & < > exactly once each, in that order, and must escape literal
 * entity strings rather than double-escaping them. */
- (void)testTextEscapingRoundtrip
{
	AWEzvXMLNode *text = [[AWEzvXMLNode alloc] initWithType:AWEzvXMLText name:@"5 < 6 & 7 > 4"];
	XCTAssertEqualObjects([text xmlString], @"5 &lt; 6 &amp; 7 &gt; 4", @"text must escape & < > in a single pass");

	AWEzvXMLNode *entity = [[AWEzvXMLNode alloc] initWithType:AWEzvXMLText name:@"&amp;"];
	XCTAssertEqualObjects([entity xmlString], @"&amp;amp;",
						  @"a literal &amp; must escape to &amp;amp;, not collapse back to &amp;");
}

/* An element at the cap depth (32) must still emit a balanced open/close pair for its own tag; the
 * level below it is dropped. A cap that emits an unbalanced prefix passes substring tests but not
 * this one. */
- (void)testBalancedTagsAtDepthCap
{
	NSString *xml = [[self chainWithDepth:40] xmlString];

	XCTAssertTrue([xml containsString:@"<level-32>"], @"the depth-32 element must open");
	XCTAssertTrue([xml containsString:@"</level-32>"], @"the depth-32 element must close");
	XCTAssertFalse([xml containsString:@"level-33"], @"content past the cap must be dropped");
	XCTAssertTrue([xml containsString:@"<level-0"], @"the root must open");
	XCTAssertTrue([xml hasSuffix:@"</level-0>"], @"the root must close");
}

/* Attributes must serialize as " key=\"value\"" on the element tag (normal values only; special-char
 * escaping in attribute values is tracked separately). */
- (void)testAttributeSerializationNormalValues
{
	AWEzvXMLNode *node = [[AWEzvXMLNode alloc] initWithType:AWEzvXMLElement name:@"message"];
	[node addAttribute:@"type" withValue:@"message"];
	[node addAttribute:@"from" withValue:@"user@example.com"];
	[node addAttribute:@"to" withValue:@"bob@example.com"];

	NSString *xml = [node xmlString];

	XCTAssertTrue([xml hasPrefix:@"<message"], @"the root tag must open");
	XCTAssertTrue([xml containsString:@" type=\"message\""], @"type attribute must serialize as key=\"value\"");
	XCTAssertTrue([xml containsString:@" from=\"user@example.com\""], @"from attribute must serialize");
	XCTAssertTrue([xml containsString:@" to=\"bob@example.com\""], @"to attribute must serialize");
	XCTAssertTrue([xml hasSuffix:@"</message>"], @"the root tag must close");
}

/* Attribute values must escape & < > and " exactly once each, in that order, so a peer-supplied
 * value cannot inject markup into the serialized tag (issue #249). */
- (void)testAttributeValueEscaping
{
	AWEzvXMLNode *node = [[AWEzvXMLNode alloc] initWithType:AWEzvXMLElement name:@"message"];
	[node addAttribute:@"summary" withValue:@"5 < 6 & 7 > 4"];

	NSString *xml = [node xmlString];

	XCTAssertTrue([xml containsString:@"summary=\"5 &lt; 6 &amp; 7 &gt; 4\""],
				  @"attribute values must escape & < > in a single pass");
}

/* A value mixing all four escapable characters must come out exactly once each, with & escaped
 * first so the replacement is not re-escaped. */
- (void)testAttributeValueEscapesAllFourCharactersSinglePass
{
	AWEzvXMLNode *node = [[AWEzvXMLNode alloc] initWithType:AWEzvXMLElement name:@"message"];
	[node addAttribute:@"summary" withValue:@"& < > \""];

	NSString *xml = [node xmlString];

	XCTAssertTrue([xml containsString:@"summary=\"&amp; &lt; &gt; &quot;\""],
				  @"& must escape before < > and \" so the replacements are not re-escaped");
	XCTAssertFalse([xml containsString:@"&amp;amp;"], @"& must not be double-escaped");
}

/* A literal entity string in the value must escape to its escaped form, not collapse back. */
- (void)testAttributeValueLiteralEntityNotCollapsed
{
	AWEzvXMLNode *node = [[AWEzvXMLNode alloc] initWithType:AWEzvXMLElement name:@"message"];
	[node addAttribute:@"summary" withValue:@"&amp;"];

	NSString *xml = [node xmlString];

	XCTAssertTrue([xml containsString:@"summary=\"&amp;amp;\""],
				  @"a literal &amp; in an attribute value must escape to &amp;amp;");
}

/* -description serializes the same attributes and must escape their values identically. */
- (void)testDescriptionEscapesAttributeValues
{
	AWEzvXMLNode *node = [[AWEzvXMLNode alloc] initWithType:AWEzvXMLElement name:@"message"];
	[node addAttribute:@"summary" withValue:@"a & b"];

	NSString *description = [node description];

	XCTAssertTrue([description containsString:@"summary=\"a &amp; b\""],
				  @"description must escape attribute values the same way xmlString does");
}

/* Filters a string to the XML-valid, round-trippable attribute-value domain. Control characters
 * below 0x20 (other than the line endings, which attribute-value normalization collapses to
 * spaces anyway) and the surrogate range are not representable as attribute content, so they are
 * dropped — PBTRandomUnicodeString can generate them, and they are not the escaper's concern. */
- (NSString *)xmlValidCopy:(NSString *)string
{
	NSMutableString *valid = [NSMutableString stringWithCapacity:[string length]];
	for (NSUInteger i = 0; i < [string length]; i++) {
		unichar character = [string characterAtIndex:i];
		if ((character >= 0x20 && character <= 0xD7FF) || (character >= 0xE000 && character <= 0xFFFD)) {
			[valid appendString:[NSString stringWithCharacters:&character length:1]];
		}
	}
	return [valid copy];
}

/* Property: escaping must be a bijection on the wire — every XML-valid attribute value serializes
 * to parseable XML whose parsed attribute equals the original (issue #249). NSXMLDocument decodes
 * the predefined entities, so an under-escaped " or & breaks the parse and an over-escaped &amp;
 * round-trips to "&amp;" rather than the original. ASCII values exercise all four escapable
 * characters; the existing example tests are single instances of this property. */
- (void)testAttributeValueEscapingRoundtripASCII
{
	PBTCheckDefault({
		NSString *value = PBTRandomASCIIString(64);

		AWEzvXMLNode *node = [[AWEzvXMLNode alloc] initWithType:AWEzvXMLElement name:@"message"];
		[node addAttribute:@"summary" withValue:value];
		NSString *xml = [node xmlString];

		NSError *error = nil;
		NSXMLDocument *document = [[NSXMLDocument alloc] initWithXMLString:xml options:0 error:&error];
		XCTAssertNotNil(document, @"serialized attribute must parse (value %@, error %@)", value, error);
		if (document != nil) {
			NSString *recovered = [[[document rootElement] attributeForName:@"summary"] stringValue];
			XCTAssertEqualObjects(recovered, value, @"escaped attribute must round-trip through NSXMLDocument");
		}
	});
}

/* The same bijection property over Unicode values (multi-byte, combining marks, and the four
 * escapable characters), filtered to the XML-valid domain. */
- (void)testAttributeValueEscapingRoundtripUnicode
{
	PBTCheckDefault({
		NSString *value = [self xmlValidCopy:PBTRandomUnicodeString(64)];

		AWEzvXMLNode *node = [[AWEzvXMLNode alloc] initWithType:AWEzvXMLElement name:@"message"];
		[node addAttribute:@"summary" withValue:value];
		NSString *xml = [node xmlString];

		NSError *error = nil;
		NSXMLDocument *document = [[NSXMLDocument alloc] initWithXMLString:xml options:0 error:&error];
		XCTAssertNotNil(document, @"serialized attribute must parse (value %@, error %@)", value, error);
		if (document != nil) {
			NSString *recovered = [[[document rootElement] attributeForName:@"summary"] stringValue];
			XCTAssertEqualObjects(recovered, value, @"escaped attribute must round-trip through NSXMLDocument");
		}
	});
}

/* maxDepth:0 on an element with attributes must keep the attributes on its own tag. */
- (void)testXmlStringWithMaxDepthZeroKeepsAttributes
{
	AWEzvXMLNode *parent = [[AWEzvXMLNode alloc] initWithType:AWEzvXMLElement name:@"parent"];
	[parent addAttribute:@"type" withValue:@"message"];
	[parent addChild:[[AWEzvXMLNode alloc] initWithType:AWEzvXMLElement name:@"child"]];

	NSString *xml = [parent xmlStringWithMaxDepth:0];

	XCTAssertEqualObjects(xml, @"<parent type=\"message\"></parent>",
						  @"maxDepth 0 must keep attributes and drop children");
}

/* Text and raw children at the cap depth survive in full (they are uncapped pass-throughs), while an
 * element child at the cap depth emits only its own empty tag. */
- (void)testTextAndRawNodesUncappedAtDepth
{
	AWEzvXMLNode *textLeaf = [[AWEzvXMLNode alloc] initWithType:AWEzvXMLText name:@"a < b & c > d"];
	NSString *xml = [[self chainWithDepth:32 leaf:textLeaf] xmlString];

	XCTAssertTrue([xml containsString:@"a &lt; b &amp; c &gt; d"], @"text at depth 32 must survive the cap");
	XCTAssertTrue([xml containsString:@"</level-31>"], @"the element at depth 31 must close");

	AWEzvXMLNode *rawLeaf = [[AWEzvXMLNode alloc] initWithType:AWEzvXMLRaw name:@"<b>bold</b>"];
	xml = [[self chainWithDepth:32 leaf:rawLeaf] xmlString];

	XCTAssertTrue([xml containsString:@"<b>bold</b>"], @"raw at depth 32 must survive the cap unescaped");
}

/* An element at exactly the cap depth emits a balanced empty tag and drops its own children. */
- (void)testElementAtExactCapEmitsBalancedEmptyTag
{
	AWEzvXMLNode *leaf = [[AWEzvXMLNode alloc] initWithType:AWEzvXMLElement name:@"leaf"];
	[leaf addChild:[[AWEzvXMLNode alloc] initWithType:AWEzvXMLElement name:@"grandchild"]];

	NSString *xml = [[self chainWithDepth:32 leaf:leaf] xmlString];

	XCTAssertTrue([xml containsString:@"<leaf></leaf>"], @"a depth-32 element must emit a balanced empty tag");
	XCTAssertFalse([xml containsString:@"grandchild"], @"children of a depth-32 element must be dropped");
}

/* The cap boundary: a content leaf at depth 32 is serialized, the same leaf at depth 33 is dropped. */
- (void)testExactDepthBoundaryKeepsContentLeaf
{
	AWEzvXMLNode *leaf32 = [[AWEzvXMLNode alloc] initWithType:AWEzvXMLText name:@"boundary-content-32"];
	NSString *xml32 = [[self chainWithDepth:32 leaf:leaf32] xmlString];
	XCTAssertTrue([xml32 containsString:@"boundary-content-32"], @"a leaf at depth 32 must serialize");

	AWEzvXMLNode *leaf33 = [[AWEzvXMLNode alloc] initWithType:AWEzvXMLText name:@"boundary-content-33"];
	NSString *xml33 = [[self chainWithDepth:33 leaf:leaf33] xmlString];
	XCTAssertFalse([xml33 containsString:@"boundary-content-33"], @"a leaf at depth 33 must be dropped");
}

/* Small maxDepth values must keep one level of children as balanced empty tags, with grandchildren
 * absent. */
- (void)testXmlStringWithSmallMaxDepth
{
	AWEzvXMLNode *root = [[AWEzvXMLNode alloc] initWithType:AWEzvXMLElement name:@"root"];
	AWEzvXMLNode *child = [[AWEzvXMLNode alloc] initWithType:AWEzvXMLElement name:@"child"];
	[child addChild:[[AWEzvXMLNode alloc] initWithType:AWEzvXMLElement name:@"grandchild"]];
	[root addChild:child];

	XCTAssertEqualObjects([root xmlStringWithMaxDepth:1], @"<root><child></child></root>",
						  @"maxDepth 1 must serialize children as balanced empty tags");
}

/* Depth accounting is per-path: many shallow siblings all serialize, and one deep chain is capped
 * independently of how many siblings exist. */
- (void)testWideTreeSiblingIndependence
{
	AWEzvXMLNode *root = [[AWEzvXMLNode alloc] initWithType:AWEzvXMLElement name:@"root"];
	for (NSUInteger i = 0; i < 10; i++) {
		[root addChild:[[AWEzvXMLNode alloc] initWithType:AWEzvXMLElement
													 name:[NSString stringWithFormat:@"sib-%lu", (unsigned long)i]]];
	}
	[root addChild:[self chainWithDepth:40]];

	NSString *xml = [root xmlString];

	for (NSUInteger i = 0; i < 10; i++) {
		NSString *sib = [NSString stringWithFormat:@"sib-%lu", (unsigned long)i];
		XCTAssertTrue([xml containsString:sib], @"wide sibling %@ must serialize despite the deep chain", sib);
	}
	XCTAssertTrue([xml containsString:@"<level-0"], @"the deep chain root (depth 1) must serialize");
	XCTAssertFalse([xml containsString:@"level-33"], @"deep chain content past the cap must be dropped");
}

/* -description re-caps each direct child at the full max, so for a single-child chain it serializes
 * one level deeper than -xmlString (root-relative 33 vs 32) but must still cap past that. */
- (void)testDescriptionReachesOneLevelDeeperThanXmlString
{
	NSString *xmlString = [[self chainWithDepth:40] xmlString];
	NSString *description = [[self chainWithDepth:40] description];

	XCTAssertFalse([xmlString containsString:@"level-33"], @"xmlString must cap at root-relative level 32");
	XCTAssertTrue([description containsString:@"level-33"], @"description must reach root-relative level 33");
	XCTAssertFalse([description containsString:@"level-34"], @"description must still cap past level 33");
}

@end
