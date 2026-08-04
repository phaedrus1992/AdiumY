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

/// Decodes the character references that can spell a URL scheme — numeric references (`&#NN;` /
/// `&#xHH;`) and the named references `&colon;` and `&sol;` — so scheme detection sees through
/// entity encoding. Used only for detection: the emitted value is never altered, so encoded text
/// that is not remote passes through unchanged.
static NSString *AIDecodeSchemeReferences(NSString *value)
{
	static NSRegularExpression *pattern;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		pattern =
			[NSRegularExpression regularExpressionWithPattern:@"&#([0-9]{1,7});|&#[xX]([0-9a-fA-F]{1,6});|&colon;|&sol;"
													  options:0
														error:NULL];
	});
	if (pattern == nil || [pattern numberOfMatchesInString:value options:0 range:NSMakeRange(0, [value length])] == 0) {
		return value;
	}

	NSMutableString *result = [value mutableCopy];
	NSArray *matches = [pattern matchesInString:value options:0 range:NSMakeRange(0, [value length])];
	for (NSInteger i = (NSInteger)[matches count] - 1; i >= 0; i--) {
		NSTextCheckingResult *match = matches[(NSUInteger)i];
		NSRange decRange = [match rangeAtIndex:1];
		NSRange hexRange = [match rangeAtIndex:2];
		unsigned int code = 0;
		BOOL isNumeric = NO;
		if (decRange.location != NSNotFound) {
			code = (unsigned int)[[value substringWithRange:decRange] intValue];
			isNumeric = YES;
		} else if (hexRange.location != NSNotFound) {
			[[NSScanner scannerWithString:[value substringWithRange:hexRange]] scanHexInt:&code];
			isNumeric = YES;
		}

		NSString *replacement;
		if (isNumeric) {
			if (code == 0 || code > 0x10FFFF) {
				continue;
			}
			unichar buf[2];
			NSUInteger bufLen;
			if (code <= 0xFFFF) {
				buf[0] = (unichar)code;
				bufLen = 1;
			} else {
				code -= 0x10000;
				buf[0] = (unichar)(0xD800 + (code >> 10));
				buf[1] = (unichar)(0xDC00 + (code & 0x3FF));
				bufLen = 2;
			}
			replacement = [[NSString alloc] initWithCharacters:buf length:bufLen];
		} else {
			unichar c = ([[value substringWithRange:[match range]] isEqualToString:@"&colon;"]) ? ':' : '/';
			replacement = [NSString stringWithCharacters:&c length:1];
		}
		[result replaceCharactersInRange:[match range] withString:replacement];
	}
	return result;
}

/// Returns YES when `value` starts with a remote scheme (http, https, file, ftp, or
/// protocol-relative `//`), ignoring surrounding whitespace, case, and character references.
static BOOL AIIsRemoteSchemeValue(NSString *value)
{
	NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	NSString *lowercase = [AIDecodeSchemeReferences(trimmed) lowercaseString];
	return [lowercase hasPrefix:@"http://"] || [lowercase hasPrefix:@"https://"] || [lowercase hasPrefix:@"file://"] ||
		   [lowercase hasPrefix:@"ftp://"] || [lowercase hasPrefix:@"//"];
}

/// Returns YES when `value` contains any remote URL (http, https, file, ftp, or a
/// protocol-relative `//` token). Used for `srcset` lists, which mix local and remote entries.
static BOOL AIContainsRemoteURL(NSString *value)
{
	NSString *lowercase = [AIDecodeSchemeReferences(value) lowercaseString];
	BOOL foundRemoteScheme =
		[lowercase rangeOfString:@"https?://|file://|ftp://" options:NSRegularExpressionSearch].location != NSNotFound;
	// A `//` that starts the value or a token (after whitespace or a comma) is protocol-relative.
	BOOL foundProtocolRelative =
		[lowercase rangeOfString:@"(?:^|[\\s,])\\/\\/" options:NSRegularExpressionSearch].location != NSNotFound;
	return foundRemoteScheme || foundProtocolRelative;
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

/// Strips surrounding whitespace and one layer of matching quotes from a CSS `url()` argument so
/// it can be scheme-checked like an attribute value.
static NSString *AITrimQuotedCSSContent(NSString *content)
{
	NSString *trimmed = [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if ([trimmed length] >= 2) {
		unichar first = [trimmed characterAtIndex:0];
		unichar last = [trimmed characterAtIndex:[trimmed length] - 1];
		if ((first == '"' && last == '"') || (first == '\'' && last == '\'')) {
			trimmed = [trimmed substringWithRange:NSMakeRange(1, [trimmed length] - 2)];
		}
	}
	return trimmed;
}

/// Returns `html` with every `pattern` match replaced by the block's result, applied from the end
/// so earlier match ranges stay valid while the string mutates.
static NSString *AIHTMLStringByReplacingCSSMatches(NSString *html, NSRegularExpression *pattern,
												   NSString * (^replacementForMatch)(NSTextCheckingResult *))
{
	NSArray *matches = [pattern matchesInString:html options:0 range:NSMakeRange(0, [html length])];
	if ([matches count] == 0) {
		return html;
	}
	NSMutableString *result = [html mutableCopy];
	for (NSInteger i = (NSInteger)[matches count] - 1; i >= 0; i--) {
		NSTextCheckingResult *match = matches[(NSUInteger)i];
		[result replaceCharactersInRange:[match range] withString:replacementForMatch(match)];
	}
	return result;
}

/// Blanks CSS `url(...)` references and `@import` statements that resolve to a remote URL. The
/// tag scanner cannot see these because they live inside attribute values or `<style>` text, and
/// the scheme is checked with `AIIsRemoteSchemeValue` so entity-encoded and file/ftp schemes are
/// covered too.
static NSString *AIHTMLStringByNeutralizingCSSRemoteReferences(NSString *html)
{
	static NSRegularExpression *urlPattern;
	static NSRegularExpression *importPattern;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		// Group 1 is the url() argument, which may be quoted.
		urlPattern = [NSRegularExpression regularExpressionWithPattern:@"url\\s*\\(([^)]*)\\)"
															   options:NSRegularExpressionCaseInsensitive
																 error:NULL];
		// Either a url() argument (group 1) or a quoted string (groups 2-3).
		importPattern =
			[NSRegularExpression regularExpressionWithPattern:@"@import\\s+(?:url\\s*\\(([^)]*)\\)|([\"'])(.*?)\\2)"
													  options:NSRegularExpressionCaseInsensitive
														error:NULL];
	});

	html = AIHTMLStringByReplacingCSSMatches(html, urlPattern, ^NSString *(NSTextCheckingResult *match) {
		NSString *content = AITrimQuotedCSSContent([html substringWithRange:[match rangeAtIndex:1]]);
		if (AIIsRemoteSchemeValue(content)) {
			return @"url()";
		}
		return [html substringWithRange:[match range]];
	});
	html = AIHTMLStringByReplacingCSSMatches(html, importPattern, ^NSString *(NSTextCheckingResult *match) {
		if ([match rangeAtIndex:1].location != NSNotFound) {
			NSString *content = AITrimQuotedCSSContent([html substringWithRange:[match rangeAtIndex:1]]);
			if (AIIsRemoteSchemeValue(content)) {
				return @"@import url()";
			}
			return [html substringWithRange:[match range]];
		}
		NSString *content = [html substringWithRange:[match rangeAtIndex:3]];
		if (AIIsRemoteSchemeValue(content)) {
			return @"@import \"\"";
		}
		return [html substringWithRange:[match range]];
	});

	return html;
}

/// Returns the index of the `>` that closes the tag starting at `pos`, or NSNotFound when the
/// string ends inside the tag. Tracks quote state so a `>` inside a quoted attribute value does
/// not terminate the tag early.
static NSUInteger AIIndexOfTagEnd(NSString *html, NSUInteger pos, NSUInteger length)
{
	unichar quote = 0;
	for (NSUInteger i = pos + 1; i < length; i++) {
		unichar c = [html characterAtIndex:i];
		if (quote != 0) {
			if (c == quote) {
				quote = 0;
			}
		} else if (c == '"' || c == '\'') {
			quote = c;
		} else if (c == '>') {
			return i;
		}
	}
	return NSNotFound;
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

		// Comments are recognized before the tag end is found so an unterminated comment copies
		// verbatim — the importer treats it as comment content to end of input, so nothing inside
		// it can trigger a load.
		BOOL isComment = pos + 3 < length && [html characterAtIndex:pos + 1] == '!' &&
						 [html characterAtIndex:pos + 2] == '-' && [html characterAtIndex:pos + 3] == '-';
		if (isComment) {
			NSRange commentEnd = [html rangeOfString:@"-->" options:0 range:NSMakeRange(pos + 4, length - (pos + 4))];
			NSUInteger end = (commentEnd.location == NSNotFound) ? length : NSMaxRange(commentEnd);
			[result appendString:[html substringWithRange:NSMakeRange(pos, end - pos)]];
			pos = end;
			continue;
		}

		NSUInteger tagEnd = AIIndexOfTagEnd(html, pos, length);
		if (tagEnd == NSNotFound) {
			// Unterminated tag — the importer completes the tag at end of input, so neutralize
			// resource references instead of passing them through (#120).
			[result appendString:AIEmitStartTag(html, pos, length)];
			break;
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
