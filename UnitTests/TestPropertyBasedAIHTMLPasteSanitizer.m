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

// Malformed markup is not crashed on; unterminated tags are copied verbatim.
- (void)testMalformedMarkupIsSafe
{
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<img src="), @"<img src=");
	XCTAssertEqualObjects(AIHTMLStringByNeutralizingRemoteResources(@"<img src=\"http://example.com/a.png\" "),
						  @"<img src=\"http://example.com/a.png\" ");
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
/// free of any http(s) URLs.
- (void)testNoRemoteSchemeSurvives
{
	PBTCheckDefault({
		NSString *html = PBTRandomHTMLString(64);
		NSString *sanitized = AIHTMLStringByNeutralizingRemoteResources(html);
		NSRange remoteRange = [sanitized rangeOfString:@"https?://"
											   options:NSRegularExpressionSearch | NSCaseInsensitiveSearch];
		XCTAssertEqual(remoteRange.location, (NSUInteger)NSNotFound, @"input = %@\nsanitized = %@", html, sanitized);
	});
}

@end
