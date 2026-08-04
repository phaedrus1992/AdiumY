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

/// Returns YES when `value` starts with an http(s) scheme or is protocol-relative, ignoring
/// surrounding whitespace and case.
static BOOL AIIsRemoteSchemeValue(NSString *value)
{
	NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	NSString *lowercase = [trimmed lowercaseString];
	return [lowercase hasPrefix:@"http://"] || [lowercase hasPrefix:@"https://"] || [lowercase hasPrefix:@"//"];
}

/// Returns YES when `value` contains any http(s) URL or a protocol-relative (`//`) URL. Used
/// for `srcset` lists, which mix local and remote entries.
static BOOL AIContainsRemoteURL(NSString *value)
{
	NSString *lowercase = [value lowercaseString];
	BOOL foundHTTP = [lowercase rangeOfString:@"http://"].location != NSNotFound;
	BOOL foundHTTPS = [lowercase rangeOfString:@"https://"].location != NSNotFound;
	// A `//` that starts the value or a token (after whitespace or a comma) is protocol-relative.
	BOOL foundProtocolRelative =
		[lowercase rangeOfString:@"(?:^|[\\s,])\\/\\/" options:NSRegularExpressionSearch].location != NSNotFound;
	return foundHTTP || foundHTTPS || foundProtocolRelative;
}

/// Returns YES when `attrName` on `tagName` is a resource attribute whose value may trigger a
/// network load when the HTML is imported.
static BOOL AIIsResourceAttribute(NSString *attrName, NSString *tagName)
{
	static NSSet<NSString *> *alwaysResourceAttributes;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		alwaysResourceAttributes = [NSSet setWithObjects:@"src", @"srcset", @"data", @"poster", @"background",
														 @"codebase", @"archive", @"longdesc", nil];
	});

	if ([alwaysResourceAttributes containsObject:attrName]) {
		return YES;
	}

	// <link> and <base> load the href; <a> merely navigates.
	return
		[attrName isEqualToString:@"href"] && ([tagName isEqualToString:@"link"] || [tagName isEqualToString:@"base"]);
}

/// Returns the attribute value to emit, blanking remote resource values.
static NSString *AISanitizedAttributeValue(NSString *attrName, NSString *value)
{
	if ([attrName isEqualToString:@"srcset"]) {
		if (AIContainsRemoteURL(value)) {
			return @"";
		}
	} else if (AIIsRemoteSchemeValue(value)) {
		return @"";
	}
	return value;
}

/// Returns YES when `c` is an HTML whitespace character.
static BOOL AIIsWhitespace(unichar c)
{
	return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f';
}

/// Emits a start tag (without its closing `>`), blanking remote resource-attribute values.
/// `tagStart` and `tagEnd` delimit the `<` … `>` range in `html`.
static NSString *AIEmitStartTag(NSString *html, NSUInteger tagStart, NSUInteger tagEnd)
{
	NSMutableString *tag = [NSMutableString string];
	[tag appendString:@"<"];
	NSUInteger pos = tagStart + 1;

	// Tag name.
	NSUInteger nameEnd = pos;
	while (nameEnd < tagEnd && !AIIsWhitespace([html characterAtIndex:nameEnd]) &&
		   [html characterAtIndex:nameEnd] != '/') {
		nameEnd++;
	}
	NSString *tagName = [[html substringWithRange:NSMakeRange(pos, nameEnd - pos)] lowercaseString];
	if ([tagName length] == 0) {
		// No tag name — leave malformed markup untouched.
		return [html substringWithRange:NSMakeRange(tagStart, tagEnd - tagStart)];
	}
	[tag appendString:tagName];
	pos = nameEnd;

	while (pos < tagEnd) {
		// Whitespace between attributes.
		NSUInteger whitespaceStart = pos;
		while (pos < tagEnd && AIIsWhitespace([html characterAtIndex:pos])) {
			pos++;
		}
		[tag appendString:[html substringWithRange:NSMakeRange(whitespaceStart, pos - whitespaceStart)]];
		if (pos >= tagEnd) {
			break;
		}

		// Self-closing slash (e.g. `<img src="…" />`).
		if ([html characterAtIndex:pos] == '/') {
			[tag appendString:@"/"];
			pos++;
			continue;
		}

		// Attribute name.
		NSUInteger attrNameStart = pos;
		while (pos < tagEnd && !AIIsWhitespace([html characterAtIndex:pos]) && [html characterAtIndex:pos] != '=' &&
			   [html characterAtIndex:pos] != '/') {
			pos++;
		}
		NSString *attrName =
			[[html substringWithRange:NSMakeRange(attrNameStart, pos - attrNameStart)] lowercaseString];
		[tag appendString:attrName];

		if (pos < tagEnd && [html characterAtIndex:pos] == '=') {
			[tag appendString:@"="];
			pos++;

			// Whitespace around the `=`.
			NSUInteger aroundStart = pos;
			while (pos < tagEnd && AIIsWhitespace([html characterAtIndex:pos])) {
				pos++;
			}
			[tag appendString:[html substringWithRange:NSMakeRange(aroundStart, pos - aroundStart)]];

			// Quoted or unquoted value.
			unichar quote = 0;
			if (pos < tagEnd && ([html characterAtIndex:pos] == '"' || [html characterAtIndex:pos] == '\'')) {
				quote = [html characterAtIndex:pos];
				[tag appendString:[html substringWithRange:NSMakeRange(pos, 1)]];
				pos++;
			}

			NSUInteger valueStart = pos;
			if (quote != 0) {
				while (pos < tagEnd && [html characterAtIndex:pos] != quote) {
					pos++;
				}
			} else {
				while (pos < tagEnd && !AIIsWhitespace([html characterAtIndex:pos])) {
					pos++;
				}
			}
			NSString *value = [html substringWithRange:NSMakeRange(valueStart, pos - valueStart)];

			[tag appendString:AIIsResourceAttribute(attrName, tagName) ? AISanitizedAttributeValue(attrName, value)
																	   : value];

			if (quote != 0 && pos < tagEnd && [html characterAtIndex:pos] == quote) {
				[tag appendString:[html substringWithRange:NSMakeRange(pos, 1)]];
				pos++;
			}
		}
	}

	return tag;
}

/// Blanks CSS `url(http(s)://…)` references and `@import "http(s)://…"` statements, which the tag
/// scanner cannot see because they live inside attribute values or `<style>` text.
static NSString *AIHTMLStringByNeutralizingCSSRemoteReferences(NSString *html)
{
	static NSRegularExpression *urlPattern;
	static NSRegularExpression *importPattern;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		urlPattern =
			[NSRegularExpression regularExpressionWithPattern:@"url\\s*\\(\\s*['\"]?(?:https?://|//)[^)]*['\"]?\\s*\\)"
													  options:NSRegularExpressionCaseInsensitive
														error:NULL];
		importPattern =
			[NSRegularExpression regularExpressionWithPattern:@"@import\\s+['\"](?:https?://|//)[^'\"]+['\"]"
													  options:NSRegularExpressionCaseInsensitive
														error:NULL];
	});

	if (urlPattern != nil) {
		html = [urlPattern stringByReplacingMatchesInString:html
													options:0
													  range:NSMakeRange(0, [html length])
											   withTemplate:@"url()"];
	}
	if (importPattern != nil) {
		html = [importPattern stringByReplacingMatchesInString:html
													   options:0
														 range:NSMakeRange(0, [html length])
												  withTemplate:@"@import \"\""];
	}
	return html;
}

NSString *AIHTMLStringByNeutralizingRemoteResources(NSString *html)
{
	if (html == nil) {
		return nil;
	}
	if ([html length] == 0) {
		return html;
	}

	html = AIHTMLStringByNeutralizingCSSRemoteReferences(html);

	NSMutableString *result = [NSMutableString string];
	NSUInteger length = [html length];
	NSUInteger pos = 0;

	while (pos < length) {
		if ([html characterAtIndex:pos] != '<') {
			// Plain text, up to the next tag.
			NSUInteger nextTag = [html rangeOfString:@"<" options:0 range:NSMakeRange(pos, length - pos)].location;
			NSUInteger textEnd = (nextTag == NSNotFound) ? length : nextTag;
			[result appendString:[html substringWithRange:NSMakeRange(pos, textEnd - pos)]];
			pos = textEnd;
			continue;
		}

		NSUInteger tagEnd = [html rangeOfString:@">" options:0 range:NSMakeRange(pos, length - pos)].location;
		if (tagEnd == NSNotFound) {
			// Unterminated tag — copy the remainder verbatim.
			[result appendString:[html substringFromIndex:pos]];
			break;
		}

		BOOL isComment = [html characterAtIndex:pos + 1] == '!' && pos + 2 < length &&
						 [html characterAtIndex:pos + 2] == '-' && pos + 3 < length &&
						 [html characterAtIndex:pos + 3] == '-';
		if (isComment) {
			NSRange commentEnd = [html rangeOfString:@"-->" options:0 range:NSMakeRange(pos + 4, length - (pos + 4))];
			NSUInteger end = (commentEnd.location == NSNotFound) ? length : NSMaxRange(commentEnd);
			[result appendString:[html substringWithRange:NSMakeRange(pos, end - pos)]];
			pos = end;
			continue;
		}

		unichar second = [html characterAtIndex:pos + 1];
		if (second == '/' || second == '!' || second == '?') {
			// Closing tag, declaration, or processing instruction — verbatim.
			[result appendString:[html substringWithRange:NSMakeRange(pos, tagEnd - pos + 1)]];
			pos = tagEnd + 1;
			continue;
		}

		// Start tag — emit with resource-attribute values neutralized.
		[result appendString:AIEmitStartTag(html, pos, tagEnd)];
		[result appendString:@">"];
		pos = tagEnd + 1;
	}

	return result;
}
