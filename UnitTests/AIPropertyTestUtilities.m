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

#import "AIPropertyTestUtilities.h"
#import <AppKit/AppKit.h>
#import <XCTest/XCTest.h>

int64_t PBTFixedSeed = 0;
int64_t PBTCurrentSeed = 0;

void PBTLogSeed(int64_t seed)
{
	fprintf(stderr, "\nPBT FAILURE — reproduce with: PBTFixedSeed = %lld;\n", seed);
}

// MARK: - Prng helpers (deterministic, seeded by PBTCurrentSeed)

static double _pbt_drand(void)
{
	return ((double)(((uint64_t)random() & 0x7fffffff))) / 2147483648.0;
}

static void _pbt_seed(int64_t seed)
{
	srandom((unsigned int)(seed ^ (seed >> 32)));
}

static uint32_t _pbt_range(uint32_t max)
{
	return max > 0 ? (uint32_t)(_pbt_drand() * max) : 0;
}

static BOOL _pbt_bool(void)
{
	return _pbt_drand() < 0.5;
}

// MARK: - String generators

NSString *PBTRandomASCIIString(uint32_t maxLen)
{
	uint32_t len = _pbt_range(maxLen + 1);
	if (len == 0) {
		return @"";
	}
	unichar *buf = calloc(len, sizeof(unichar));
	for (uint32_t i = 0; i < len; i++) {
		// Printable ASCII range 32..126
		buf[i] = (unichar)(32 + _pbt_range(95));
	}
	NSString *s = [NSString stringWithCharacters:buf length:len];
	free(buf);
	return s;
}

NSString *PBTRandomUnicodeString(uint32_t maxLen)
{
	uint32_t len = _pbt_range(maxLen + 1);
	if (len == 0) {
		return @"";
	}
	unichar *buf = calloc(len, sizeof(unichar));
	for (uint32_t i = 0; i < len; i++) {
		uint32_t r = _pbt_range(0x110000);
		if (r < 0x80) {
			buf[i] = (unichar)r;
		} else if (r < 0x10000) {
			unichar candidates[] = {0x00A9, 0x00AE, 0x2026, 0x2603, 0x2764, 0x263A, 0x00E9,
									0x00F1, 0x4E2D, 0x0416, 0x03B1, 0x0300, 0x0301, 0x0302};
			buf[i] = candidates[_pbt_range(sizeof(candidates) / sizeof(candidates[0]))];
		} else {
			buf[i] = 0x2603;
		}
	}
	NSString *s = [NSString stringWithCharacters:buf length:len];
	free(buf);
	return s;
}

NSString *PBTRandomWhitespaceString(uint32_t maxLen)
{
	uint32_t len = _pbt_range(maxLen + 1);
	if (len == 0) {
		return @"";
	}
	unichar chars[] = {' ', '\t', '\n', '\r', 0x00A0};
	unichar *buf = calloc(len, sizeof(unichar));
	NSUInteger nChars = sizeof(chars) / sizeof(chars[0]);
	for (uint32_t i = 0; i < len; i++) {
		buf[i] = chars[_pbt_range((uint32_t)nChars)];
	}
	NSString *s = [NSString stringWithCharacters:buf length:len];
	free(buf);
	return s;
}

NSString *PBTRandomHTMLFragment(uint32_t maxLen)
{
	NSArray *tags = @[ @"b", @"i", @"u", @"span", @"font", @"br", @"a" ];
	uint32_t len = _pbt_range(maxLen + 1);
	if (len == 0) {
		return @"";
	}
	NSMutableString *html = [NSMutableString string];
	for (uint32_t i = 0; i < len; i++) {
		uint32_t choice = _pbt_range(5);
		if (choice == 0) {
			[html appendString:PBTRandomASCIIString(10)];
		} else if (choice == 1) {
			NSString *tag = tags[_pbt_range((uint32_t)[tags count])];
			[html appendFormat:@"<%@>", tag];
		} else if (choice == 2) {
			NSString *tag = tags[_pbt_range((uint32_t)[tags count])];
			[html appendFormat:@"</%@>", tag];
		} else if (choice == 3) {
			[html appendString:@"&amp;"];
		} else {
			[html appendString:@" "];
		}
	}
	return html;
}

/// Returns a random ASCII string safe as HTML text: printable ASCII minus `<`, `>`, `"`, and `=`.
/// Keeps generated markup unambiguous — a stray `<` or `>` can't merge into a tag name, and a
/// stray `"` or `=` can't open an attribute value the attribute-scoped property would misread.
static NSString *_pbt_htmlText(uint32_t maxLen)
{
	uint32_t len = _pbt_range(maxLen + 1);
	if (len == 0) {
		return @"";
	}
	unichar *buf = calloc(len, sizeof(unichar));
	for (uint32_t i = 0; i < len; i++) {
		unichar c;
		do {
			c = (unichar)(32 + _pbt_range(95));
		} while (c == '<' || c == '>' || c == '"' || c == '=');
		buf[i] = c;
	}
	NSString *s = [NSString stringWithCharacters:buf length:len];
	free(buf);
	return s;
}

NSString *PBTRandomHTMLString(uint32_t maxLen)
{
	static NSArray *resourceAttributes;
	static NSArray *remoteValues;
	static NSArray *localValues;
	static NSArray *tags;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		resourceAttributes =
			@[ @"src", @"srcset", @"data", @"poster", @"background", @"codebase", @"archive", @"longdesc" ];
		remoteValues = @[
			@"http://example.com/a.png",
			@"https://example.com/a.png",
			@"//cdn.example.com/a.png",
			@"HTTP://EXAMPLE.COM/A.PNG",
			@"https://x.test/path/file.png",
			@"&#104;ttp://example.com/a.png",
			@"http&#58;//example.com/a.png",
			@"&#47;&#47;cdn.example.com/a.png",
			@"file:///tmp/a.png",
			@"ftp://example.com/a.png",
		];
		localValues = @[
			@"/local/a.png",
			@"a.png",
			@"../a.png",
			@"data:image/png;base64,AAAA",
			@"#fragment",
			@"",
		];
		tags = @[ @"img", @"link", @"base", @"a", @"script", @"div", @"p", @"span", @"br" ];
	});

	NSMutableString *html = [NSMutableString string];
	uint32_t length = _pbt_range(maxLen + 1);
	for (uint32_t i = 0; i < length; i++) {
		uint32_t choice = _pbt_range(10);
		if (choice == 0) {
			[html appendString:_pbt_htmlText(8)];
		} else if (choice == 1) {
			[html appendString:@"<!-- a comment -->"];
		} else if (choice == 2) {
			NSString *tag = tags[_pbt_range((uint32_t)[tags count])];
			NSString *attr;
			BOOL remote = _pbt_bool();
			if ([tag isEqualToString:@"link"] || [tag isEqualToString:@"base"]) {
				attr = @"href";
			} else if ([tag isEqualToString:@"a"]) {
				attr = @"title";
				remote = NO; // <a> never carries remote values in generated HTML
			} else {
				attr = resourceAttributes[_pbt_range((uint32_t)[resourceAttributes count])];
			}
			NSString *value = remote ? remoteValues[_pbt_range((uint32_t)[remoteValues count])]
									 : localValues[_pbt_range((uint32_t)[localValues count])];
			[html appendFormat:@"<%@ %@=\"%@\">", tag, attr, value];
		} else if (choice == 3) {
			// <a> only ever carries local hrefs so sanitized output is http(s)-free.
			NSString *value = localValues[_pbt_range((uint32_t)[localValues count])];
			[html appendFormat:@"<a href=\"%@\">", value];
		} else if (choice == 4) {
			[html appendFormat:@"</%@>", tags[_pbt_range((uint32_t)[tags count])]];
		} else if (choice == 5) {
			NSString *value = _pbt_bool() ? remoteValues[_pbt_range((uint32_t)[remoteValues count])]
										  : localValues[_pbt_range((uint32_t)[localValues count])];
			[html appendFormat:@"<div style=\"background:url(%@)\">", value];
		} else if (choice == 6) {
			NSString *value = _pbt_bool() ? remoteValues[_pbt_range((uint32_t)[remoteValues count])]
										  : localValues[_pbt_range((uint32_t)[localValues count])];
			[html appendFormat:@"<style>@import \"%@\";</style>", value];
		} else if (choice == 7) {
			[html appendString:PBTRandomWhitespaceString(4)];
		} else if (choice == 8) {
			// A `>` inside a quoted attribute value must not end the tag early; the remote src is
			// still blanked.
			NSString *value = remoteValues[_pbt_range((uint32_t)[remoteValues count])];
			[html appendFormat:@"<img title=\"a > b\" src=\"%@\">", value];
		} else {
			// A srcset with a remote second entry blanks the whole attribute.
			NSString *value = remoteValues[_pbt_range((uint32_t)[remoteValues count])];
			[html appendFormat:@"<img srcset=\"a.png 1x, %@ 2x\">", value];
		}
	}
	return html;
}

// MARK: - Attributed string generators

NSAttributedString *PBTRandomAttributedString(uint32_t maxLen)
{
	NSString *text = PBTRandomASCIIString(maxLen);
	if ([text length] == 0) {
		return [[NSAttributedString alloc] init];
	}
	NSMutableAttributedString *mas = [[NSMutableAttributedString alloc] initWithString:text];
	NSArray *colors = @[
		[NSColor blackColor], [NSColor redColor], [NSColor blueColor], [NSColor greenColor], [NSColor whiteColor],
		[NSColor yellowColor]
	];
	NSArray *fonts =
		@[ [NSFont systemFontOfSize:12.0], [NSFont boldSystemFontOfSize:14.0], [NSFont systemFontOfSize:10.0] ];

	NSUInteger len = [text length];
	NSUInteger pos = 0;
	while (pos < len) {
		NSUInteger runLen = 1 + (NSUInteger)_pbt_range((uint32_t)(len - pos));
		NSRange range = NSMakeRange(pos, runLen);
		if (_pbt_bool()) {
			[mas addAttribute:NSForegroundColorAttributeName
						value:colors[_pbt_range((uint32_t)[colors count])]
						range:range];
		}
		if (_pbt_bool()) {
			[mas addAttribute:NSFontAttributeName value:fonts[_pbt_range((uint32_t)[fonts count])] range:range];
		}
		if (_pbt_bool()) {
			[mas addAttribute:NSUnderlineStyleAttributeName value:@(_pbt_range(3)) range:range];
		}
		pos += runLen;
	}
	return mas;
}

NSAttributedString *PBTRandomPlainAttributedString(uint32_t maxLen)
{
	NSString *text = PBTRandomASCIIString(maxLen);
	return [[NSAttributedString alloc] initWithString:text];
}

// MARK: - Number generators

NSUInteger PBTUniform(uint32_t max)
{
	return _pbt_range(max);
}

BOOL PBTRandomBool(void)
{
	return _pbt_bool();
}

uint64_t PBTUniformUInt64(uint64_t max)
{
	if (max == 0) {
		return 0;
	}
	if (max <= UINT32_MAX) {
		return _pbt_range((uint32_t)max);
	}
	/* Two 32-bit draws composed into a 64-bit value: _pbt_range's uint32_t max cannot reach beyond
	 * UINT32_MAX, so a larger max needs the full width composed by hand. */
	uint64_t high = (uint64_t)_pbt_range(UINT32_MAX) << 32;
	uint64_t low = (uint64_t)_pbt_range(UINT32_MAX);
	return (high | low) % max;
}

uint64_t PBTBoundaryUInt64(uint64_t max)
{
	if (max == 0) {
		return 0;
	}
	switch (_pbt_range(6)) {
	case 0:
		return 0;
	case 1:
		return max > 1 ? 1 : 0;
	case 2:
		return max - 1;
	case 3:
		return max / 2;
	case 4:
		return max > 2 ? (max - 2) : (max > 1 ? (max - 1) : 0);
	default:
		return PBTUniformUInt64(max);
	}
}

// MARK: - Dictionary generators

NSDictionary *PBTRandomStringDictionary(uint32_t maxPairs)
{
	uint32_t count = _pbt_range(maxPairs + 1);
	if (count == 0) {
		return @{};
	}
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	for (uint32_t i = 0; i < count; i++) {
		NSString *key = PBTRandomASCIIString(16);
		NSString *val = PBTRandomASCIIString(32);
		if (key && val) {
			dict[key] = val;
		}
	}
	return dict;
}

NSDictionary *PBTRandomStatusDictionary(void)
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	NSArray *knownKeys = @[
		@"Status Message NSAttributedString", @"Has AutoReply", @"AutoReply is Status Message",
		@"AutoReply Message NSAttributedString", @"Status Name", @"Invisible", @"Mutability Type", @"Mute Sounds",
		@"Silence Growl", @"Special Type"
	];
	for (NSString *key in knownKeys) {
		if (_pbt_bool()) {
			if ([key hasSuffix:@"AttributedString"]) {
				dict[key] = PBTRandomAttributedString(64);
			} else if ([key hasSuffix:@"Type"] || [key hasPrefix:@"Mutability"]) {
				dict[key] = @(_pbt_range(4));
			} else if ([key hasPrefix:@"Has "] || [key hasPrefix:@"AutoReply is "] || [key hasPrefix:@"Invisible"] ||
					   [key hasPrefix:@"Mute "] || [key hasPrefix:@"Silence "]) {
				dict[key] = @(_pbt_bool());
			} else {
				dict[key] = PBTRandomASCIIString(32);
			}
		}
	}
	return dict;
}

static void _pbt_putRandomCoordinate(NSMutableDictionary *body, NSString *key)
{
	uint32_t choice = _pbt_range(4);
	if (choice == 1) {
		body[key] = PBTRandomASCIIString(6); // string, not NSNumber
	} else if (choice == 2) {
		body[key] = [NSNull null];
	} else if (choice == 3) {
		double d = ((double)_pbt_range(1000000)) / 1000.0 - 500.0; // -500.0..500.0
		body[key] = @(d);
	}
	// choice == 0: key absent
}

id PBTRandomJSBodyDictionary(void)
{
	// Roughly one time in ten the body is not a dictionary at all.
	if (_pbt_range(10) == 0) {
		uint32_t kind = _pbt_range(3);
		if (kind == 0)
			return PBTRandomASCIIString(16);
		if (kind == 1)
			return @[ PBTRandomASCIIString(8), @(_pbt_range(100)) ];
		return @(_pbt_range(1000));
	}

	NSMutableDictionary *body = [NSMutableDictionary dictionary];

	uint32_t typeChoice = _pbt_range(4);
	if (typeChoice == 1) {
		body[@"type"] = PBTRandomASCIIString(12); // wrong string
	} else if (typeChoice == 2) {
		body[@"type"] = @(_pbt_range(4)); // wrong type
	} else if (typeChoice == 3) {
		body[@"type"] = @"contextMenu";
	}
	// typeChoice == 0: type key absent

	_pbt_putRandomCoordinate(body, @"x");
	_pbt_putRandomCoordinate(body, @"y");

	uint32_t urlChoice = _pbt_range(4);
	if (urlChoice == 1) {
		body[@"imageURL"] = @"";
	} else if (urlChoice == 2) {
		body[@"imageURL"] = @(_pbt_range(100)); // wrong type
	} else if (urlChoice == 3) {
		body[@"imageURL"] = PBTRandomASCIIString(48);
	}
	// urlChoice == 0: imageURL key absent

	return body;
}

// MARK: - Shrinking

int64_t PBTShrinkSeed(int64_t failingSeed, BOOL (^testBlock)(int64_t seed))
{
	// Try dividing the seed delta by 2, 4, 8... to find a simpler repro
	for (int64_t step = 2; step < 256; step *= 2) {
		int64_t candidate = failingSeed - (failingSeed % step);
		if (candidate != failingSeed && testBlock(candidate)) {
			return candidate;
		}
	}
	return failingSeed;
}
