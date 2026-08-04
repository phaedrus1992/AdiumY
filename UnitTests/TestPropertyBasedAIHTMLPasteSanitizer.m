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

#import "AIHTMLPasteSanitizer.h"
#import "AIPropertyTestUtilities.h"
#import <XCTest/XCTest.h>

static NSString *AITestResourceAttributePattern(void);
static NSString *AITestDecodeSchemeEntities(NSString *value);
static BOOL AITestValueHasRemoteScheme(NSString *value);

@interface TestPropertyBasedAIHTMLPasteSanitizer : XCTestCase
@end

@implementation TestPropertyBasedAIHTMLPasteSanitizer

// Resource-attribute values with a remote scheme are blanked, whatever the quoting.
- (void)testRemoteResourceAttributeValuesAreBlanked
{
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<img src=\"http://example.com/a.png\">"),
						  @"<img src=\"\">");
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<img src=\"https://example.com/a.png\">"),
						  @"<img src=\"\">");
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<img src='http://example.com/a.png'>"),
						  @"<img src=''>");
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<img src=http://example.com/a.png>"),
						  @"<img src=>");
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<img src=\"HTTP://EXAMPLE.COM/A.PNG\">"),
						  @"<img src=\"\">");
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<img src=\"//cdn.example.com/a.png\">"),
						  @"<img src=\"\">");
}

// Local, relative, data:, and fragment references are preserved.
- (void)testLocalResourceAttributeValuesArePreserved
{
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<img src=\"/local/a.png\">"),
						  @"<img src=\"/local/a.png\">");
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<img src=\"a.png\">"), @"<img src=\"a.png\">");
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<img src=\"data:image/png;base64,AAAA\">"),
						  @"<img src=\"data:image/png;base64,AAAA\">");
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<img src=\"#frag\">"), @"<img src=\"#frag\">");
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<img src=\"\">"), @"<img src=\"\">");
}

// <a href> links are preserved; <link> and <base> href loads are blanked.
- (void)testAnchorHrefsPreservedButLinkAndBaseBlanked
{
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<a href=\"https://example.com/page\">hi</a>"),
						  @"<a href=\"https://example.com/page\">hi</a>");
	XCTAssertEqualObjects(
		AIHTMLStringByNeutralizingRemoteResources(@"<link href=\"https://example.com/s.css\" rel=\"stylesheet\">"),
		@"<link href=\"\" rel=\"stylesheet\">");
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<base href=\"https://example.com/\">"),
						  @"<base href=\"\">");
}

// srcset lists that contain a remote URL are blanked whole; local lists survive.
- (void)testSrcsetLists
{
	XCTAssertEqualObjects(
		AIHTMLStringByNeutralizingRemoteResources(@"<img srcset=\"a.png 1x, https://cdn.example.com/b.png 2x\">"),
		@"<img srcset=\"\">");
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<img srcset=\"a.png 1x, b.png 2x\">"),
						  @"<img srcset=\"a.png 1x, b.png 2x\">");
}

// Comments are copied verbatim.
- (void)testCommentsPreserved
{
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<!-- <img src=\"http://example.com/a.png\"> -->"),
						  @"<!-- <img src=\"http://example.com/a.png\"> -->");
}

// CSS url() references and @import statements are neutralized inside style attributes and <style> blocks.
- (void)testCSSRemoteReferencesBlanked
{
	XCTAssertEqualObjects(
		AIHTMLStringByNeutralizingRemoteResources(@"<div style=\"background:url(http://example.com/bg.png)\">"),
		@"<div style=\"background:url()\">");
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(
							  @"<div style='background-image: url(\"https://example.com/bg.png\");'>"),
						  @"<div style='background-image: url();'>");
	XCTAssertEqualObjects(
		AIHTMLStringByNeutralizingRemoteResources(@"<style>@import \"http://example.com/s.css\";</style>"),
		@"<style>@import \"\";</style>");
	XCTAssertEqualObjects(
		AIHTMLStringByNeutralizingRemoteResources(@"<style>@import url(https://example.com/s.css);</style>"),
		@"<style>@import url();</style>");
}

// Scripts and other tags carrying a remote src are blanked.
- (void)testScriptSrcBlanked
{
	XCTAssertEqualObjects(
		AIHTMLStringByNeutralizingRemoteResources(@"<script src=\"https://example.com/a.js\"></script>"),
		@"<script src=\"\"></script>");
}

// Declarations, processing instructions, and closing tags pass through untouched.
- (void)testMarkupPassThrough
{
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<!DOCTYPE html>"), @"<!DOCTYPE html>");
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<?xml version=\"1.0\"?>"),
						  @"<?xml version=\"1.0\"?>");
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"</body>"), @"</body>");
}

// nil and empty input are returned unchanged.
- (void)testNilAndEmpty
{
	XCTAssertNil(AIHTMLStringByNeutralizingRemoteResources(nil));
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@""), @"");
}

// Malformed markup is not crashed on; an unterminated tag has its resource values neutralized.
- (void)testMalformedMarkupIsSafe
{
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<img src="), @"<img src=");
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<img src=\"http://example.com/a.png\" "),
						  @"<img src=\"\" ");
}

// A `>` inside a quoted attribute value does not end the tag early, so the remote src is blanked.
- (void)testGreaterThanInsideQuotedAttributeValue
{
	XCTAssertEqualObjects(
		AIHTMLStringByNeutralizingRemoteResources(@"<img title=\"a > b\" src=\"http://example.com/a.png\">"),
		@"<img title=\"a > b\" src=\"\">");
}

// Character-reference-encoded remote schemes are detected and blanked.
- (void)testEntityEncodedRemoteSchemesBlanked
{
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<img src=\"&#104;ttp://example.com/a.png\">"),
						  @"<img src=\"\">");
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<img src=\"http&#58;//example.com/a.png\">"),
						  @"<img src=\"\">");
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<img src=\"&#47;&#47;cdn.example.com/a.png\">"),
						  @"<img src=\"\">");
}

// file:// and ftp:// remote references are blanked — the importer can read local files too.
- (void)testFileAndFTPSchemesBlanked
{
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<img src=\"file:///tmp/a.png\">"),
						  @"<img src=\"\">");
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<img src=\"ftp://example.com/a.png\">"),
						  @"<img src=\"\">");
}

// Entity-encoded remote schemes inside CSS url() are blanked too.
- (void)testCSSEntityEncodedRemoteBlanked
{
	XCTAssertEqualObjects(
		AIHTMLStringByNeutralizingRemoteResources(@"<div style=\"background:url(&#104;ttp://example.com/bg.png)\">"),
		@"<div style=\"background:url()\">");
}

/// Property: sanitizing is idempotent over arbitrary generated HTML.
- (void)testSanitizerIsIdempotent
{
	PBTCheckDefault({
		NSString *html = PBTRandomHTMLString(64);
		NSString *once = AIHTMLStringByNeutralizingRemoteResources(html);
		XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(once), once, @"input = %@", html);
	});
}

/// Property: generated HTML (which never carries remote <a href> values) sanitizes to output
/// free of any remote URL, including file: and ftp: schemes.
- (void)testNoRemoteSchemeSurvives
{
	PBTCheckDefault({
		NSString *html = PBTRandomHTMLString(64);
		NSString *sanitized = AIHTMLStringByNeutralizingRemoteResources(html);
		NSRange remoteRange = [sanitized rangeOfString:@"https?://|file://|ftp://"
											   options:NSRegularExpressionSearch | NSCaseInsensitiveSearch];
		XCTAssertEqual(remoteRange.location, (NSUInteger)NSNotFound, @"input = %@\nsanitized = %@", html, sanitized);
	});
}

/// Property: no resource-attribute value that survives sanitizing is remote. Scans the emitted
/// attributes (not the whole string) and checks scheme prefixes — file:, ftp:, and
/// protocol-relative `//` — after decoding character references, covering the leaks the
/// whole-string http(s) check misses. The generator emits only double-quoted attributes, fixed
/// comments, and text that cannot spell `=` or `"`, so every surviving `name="value"` match is
/// a real attribute.
- (void)testNoRemoteResourceAttributeValuesSurvive
{
	PBTCheckDefault({
		NSString *html = PBTRandomHTMLString(64);
		NSString *sanitized = AIHTMLStringByNeutralizingRemoteResources(html);
		NSRegularExpression *attrPattern =
			[NSRegularExpression regularExpressionWithPattern:AITestResourceAttributePattern() options:0 error:NULL];
		NSArray *matches = [attrPattern matchesInString:sanitized options:0 range:NSMakeRange(0, [sanitized length])];
		for (NSTextCheckingResult *match in matches) {
			NSString *value = AITestDecodeSchemeEntities([sanitized substringWithRange:[match rangeAtIndex:2]]);
			XCTAssertFalse(AITestValueHasRemoteScheme(value), @"input = %@\nsanitized = %@\nvalue = %@", html,
						   sanitized, value);
		}
	});
}

@end

/// Returns the regex matching a double-quoted resource attribute for the attribute-scoped property.
static NSString *AITestResourceAttributePattern(void)
{
	return @"\\b(src|srcset|data|poster|background|codebase|archive|longdesc|href)=\"([^\"]*)\"";
}

/// Decodes the character references that can spell a URL scheme — the numeric forms of `h`, `:`,
/// `/` and the named `&colon;`/`&sol;` — so the attribute-scoped property can detect a remote
/// value without depending on the sanitizer's own decoder.
static NSString *AITestDecodeSchemeEntities(NSString *value)
{
	if ([value rangeOfString:@"&"].location == NSNotFound) {
		return value;
	}
	NSMutableString *result = [value mutableCopy];
	NSArray *pairs = @[
		@[ @"&colon;", @":" ],
		@[ @"&sol;", @"/" ],
		@[ @"&#104;", @"h" ],
		@[ @"&#x68;", @"h" ],
		@[ @"&#58;", @":" ],
		@[ @"&#x3a;", @":" ],
		@[ @"&#47;", @"/" ],
		@[ @"&#x2f;", @"/" ],
	];
	for (NSArray *pair in pairs) {
		[result replaceOccurrencesOfString:pair[0] withString:pair[1] options:0 range:NSMakeRange(0, [result length])];
	}
	return result;
}

/// Returns YES when the (already-decoded) attribute value starts with a remote scheme prefix:
/// protocol-relative `//`, `http:`, `https:`, `file:`, or `ftp:`.
static BOOL AITestValueHasRemoteScheme(NSString *value)
{
	NSString *lowercaseValue = [value lowercaseString];
	if ([lowercaseValue hasPrefix:@"//"]) {
		return YES;
	}
	NSArray *prefixes = @[ @"http://", @"https://", @"file://", @"ftp://" ];
	for (NSString *prefix in prefixes) {
		if ([lowercaseValue hasPrefix:prefix]) {
			return YES;
		}
	}
	return NO;
}
