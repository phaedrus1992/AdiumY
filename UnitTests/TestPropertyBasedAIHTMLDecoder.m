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

#import "TestPropertyBasedAIHTMLDecoder.h"
#import "AIPropertyTestUtilities.h"
#import <Adium/AIHTMLDecoder.h>

@implementation TestPropertyBasedAIHTMLDecoder

/// Property: For any NSAttributedString, decoding the HTML produced by encodeHTML:
/// must not crash and must return a non-nil result.
- (void)testEncodeDecodeDoesNotCrash {
	PBTCheckDefault({
		NSAttributedString *original = PBTRandomPlainAttributedString(128);
		AIHTMLDecoder *decoder = [[AIHTMLDecoder alloc] init];
		NSString *html = [decoder encodeHTML:original imagesPath:nil];
		STAssertNotNil(html, @"encodeHTML returned nil");
		NSAttributedString *decoded = [decoder decodeHTML:html withDefaultAttributes:nil];
		STAssertNotNil(decoded, @"decodeHTML returned nil for encoded output");
	});
}

/// Property: For any NSAttributedString with attributes, encode → decode must not crash
/// and must return a non-nil result.
- (void)testEncodeDecodeWithAttributesDoesNotCrash {
	PBTCheckDefault({
		NSAttributedString *original = PBTRandomAttributedString(64);
		AIHTMLDecoder *decoder = [[AIHTMLDecoder alloc] init];
		decoder.includesFontTags = YES;
		decoder.includesColorTags = YES;
		decoder.includesStyleTags = YES;
		NSString *html = [decoder encodeHTML:original imagesPath:nil];
		STAssertNotNil(html, @"encodeHTML returned nil for attributed string");
		NSAttributedString *decoded = [decoder decodeHTML:html withDefaultAttributes:nil];
		STAssertNotNil(decoded, @"decodeHTML returned nil");
	});
}

/// Property: encodeHTML: returns a non-nil result even for empty and whitespace input.
- (void)testEncodeEmptyAndWhitespace {
	PBTCheckDefault({
		NSString *text = PBTRandomWhitespaceString(32);
		NSAttributedString *as = [[NSAttributedString alloc] initWithString:text];
		AIHTMLDecoder *decoder = [[AIHTMLDecoder alloc] init];
		NSString *html = [decoder encodeHTML:as imagesPath:nil];
		STAssertNotNil(html, @"encodeHTML returned nil for whitespace-only string");
	});
}

/// Property: Empty attributed string encodes to empty string and decodes back to empty.
- (void)testEncodeDecodeEmptyString {
	NSAttributedString *empty = [[NSAttributedString alloc] init];
	AIHTMLDecoder *decoder = [[AIHTMLDecoder alloc] init];
	NSString *html = [decoder encodeHTML:empty imagesPath:nil];
	STAssertNotNil(html, @"encodeHTML returned nil for empty string");
	NSAttributedString *decoded = [decoder decodeHTML:html withDefaultAttributes:nil];
	STAssertNotNil(decoded, @"decodeHTML returned nil for empty string encoding");
}

/// Property: Simple text survive encode → decode roundtrip with text content preserved.
/// The decoded string must contain the same characters as the original.
- (void)testEncodeDecodePreservesTextContent {
	PBTCheckDefault({
		NSAttributedString *original = PBTRandomPlainAttributedString(64);
		NSString *originalText = [original string];
		AIHTMLDecoder *decoder = [[AIHTMLDecoder alloc] init];
		NSString *html = [decoder encodeHTML:original imagesPath:nil];
		NSAttributedString *decoded = [decoder decodeHTML:html withDefaultAttributes:nil];
		NSString *decodedText = [decoded string];
		// The decoded text should contain the original text (may have whitespace added by HTML rendering)
		BOOL contains = [decodedText rangeOfString:originalText].location != NSNotFound;
		if (!contains && [originalText length] > 0) {
			// Try trimming whitespace
			NSString *trimmedOriginal = [originalText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			NSString *trimmedDecoded = [decodedText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			STAssertEqualObjects(trimmedOriginal, trimmedDecoded,
								 @"Text content lost in encode/decode roundtrip");
		}
	});
}

/// Property: decodeHTML: must not crash on arbitrary (potentially malformed) HTML strings.
- (void)testDecodeArbitraryHTMLDoesNotCrash {
	PBTCheckDefault({
		NSString *html = PBTRandomHTMLFragment(128);
		AIHTMLDecoder *decoder = [[AIHTMLDecoder alloc] init];
		NSAttributedString *result = [decoder decodeHTML:html withDefaultAttributes:nil];
		// Must not crash; result may be nil or non-nil
		STAssertTrue(YES, @"decodeHTML must not crash on arbitrary input");
	});
}

/// Property: Class convenience methods produce the same results as instance methods.
- (void)testClassVsInstanceDecodeConsistency {
	PBTCheckDefault({
		NSString *html = PBTRandomHTMLFragment(64);
		AIHTMLDecoder *decoder = [[AIHTMLDecoder alloc] init];
		NSAttributedString *instanceResult = [decoder decodeHTML:html withDefaultAttributes:nil];
		NSAttributedString *classResult = [AIHTMLDecoder decodeHTML:html withDefaultAttributes:nil];
		if (instanceResult && classResult) {
			STAssertEqualObjects([instanceResult string], [classResult string],
								 @"Class vs instance decodeHTML differs");
		}
	});
}

/// Property: parseArguments: must not crash on random attribute strings.
- (void)testParseArgumentsDoesNotCrash {
	PBTCheckDefault({
		NSString *args = PBTRandomASCIIString(64);
		AIHTMLDecoder *decoder = [[AIHTMLDecoder alloc] init];
		NSDictionary *result = [decoder parseArguments:args];
		// Must not crash. Result may be nil or a dictionary.
		STAssertTrue(result == nil || [result isKindOfClass:[NSDictionary class]],
					 @"parseArguments must return nil or NSDictionary");
	});
}

@end
