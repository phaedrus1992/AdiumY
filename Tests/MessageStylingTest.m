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

/// XEP-0393 Message Styling Parser Tests
///
/// Standalone unit tests for AMPurpleJabberMessageStylingParser.
/// Compile with:
///   clang -framework Foundation -framework AppKit \
///         -I ../Plugins/Purple\ Service \
///         MessageStylingTest.m \
///         ../Plugins/Purple\ Service/AMPurpleJabberMessageStylingParser.m \
///         -o MessageStylingTest

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "AMPurpleJabberMessageStylingParser.h"

static NSUInteger g_testsPassed = 0;
static NSUInteger g_testsFailed = 0;

#define TEST(name, expr) do { \
    if ((expr)) { \
        g_testsPassed++; \
        printf("  PASS: %s\n", [name UTF8String]); \
    } else { \
        g_testsFailed++; \
        printf("  FAIL: %s\n", [name UTF8String]); \
    } \
} while(0)

#define TEST_ATTR(name, attrStr, attrName, rangeLoc, rangeLen, checkBlock) do { \
    NSAttributedString *_s = (attrStr); \
    NSRange _r = NSMakeRange(rangeLoc, rangeLen); \
    id _val = [_s attribute:attrName atIndex:_r.location effectiveRange:NULL]; \
    BOOL _ok = (checkBlock); \
    if (_ok) { \
        g_testsPassed++; \
        printf("  PASS: %s\n", [name UTF8String]); \
    } else { \
        g_testsFailed++; \
        printf("  FAIL: %s (expected attribute %s)\n", [name UTF8String], [attrName UTF8String]); \
    } \
} while(0)

/// Check that a substring has a bold trait
static BOOL hasBoldTrait(NSAttributedString *s, NSUInteger loc, NSUInteger len)
{
    if (loc + len > [s length]) return NO;
    NSFont *font = [s attribute:NSFontAttributeName atIndex:loc effectiveRange:NULL];
    if (font == nil) return NO;
    NSFontTraitMask traits = [[NSFontManager sharedFontManager] traitsOfFont:font];
    return (traits & NSBoldFontMask) != 0;
}

/// Check that a substring has an italic trait
static BOOL hasItalicTrait(NSAttributedString *s, NSUInteger loc, NSUInteger len)
{
    if (loc + len > [s length]) return NO;
    NSFont *font = [s attribute:NSFontAttributeName atIndex:loc effectiveRange:NULL];
    if (font == nil) return NO;
    NSFontTraitMask traits = [[NSFontManager sharedFontManager] traitsOfFont:font];
    return (traits & NSItalicFontMask) != 0;
}

/// Check that a substring has strikethrough
static BOOL hasStrikethrough(NSAttributedString *s, NSUInteger loc, NSUInteger len)
{
    if (loc + len > [s length]) return NO;
    id val = [s attribute:NSStrikethroughStyleAttributeName atIndex:loc effectiveRange:NULL];
    return (val != nil);
}

/// Check that a substring uses a monospace font
static BOOL hasMonospaceFont(NSAttributedString *s, NSUInteger loc, NSUInteger len)
{
    if (loc + len > [s length]) return NO;
    NSFont *font = [s attribute:NSFontAttributeName atIndex:loc effectiveRange:NULL];
    if (font == nil) return NO;
    return [font isEqualTo:[NSFont userFixedPitchFontOfSize:12.0]];
}

/// Check that a substring has exactly the plain base font (no special traits)
static BOOL hasPlainFont(NSAttributedString *s, NSUInteger loc, NSUInteger len)
{
    if (loc + len > [s length]) return NO;
    NSFont *font = [s attribute:NSFontAttributeName atIndex:loc effectiveRange:NULL];
    if (font == nil) return NO;
    NSFontTraitMask traits = [[NSFontManager sharedFontManager] traitsOfFont:font];
    return ((traits & (NSBoldFontMask | NSItalicFontMask)) == 0);
}

/// Check that a substring has both bold AND italic traits
static BOOL hasBoldItalicTraits(NSAttributedString *s, NSUInteger loc, NSUInteger len)
{
    if (loc + len > [s length]) return NO;
    NSFont *font = [s attribute:NSFontAttributeName atIndex:loc effectiveRange:NULL];
    if (font == nil) return NO;
    NSFontTraitMask traits = [[NSFontManager sharedFontManager] traitsOfFont:font];
    return ((traits & NSBoldFontMask) != 0 && (traits & NSItalicFontMask) != 0);
}

/// Check string content at a range
static BOOL stringAtRangeEquals(NSAttributedString *s, NSUInteger loc, NSUInteger len, NSString *expected)
{
    if (loc + len > [s length]) return NO;
    NSString *sub = [[s string] substringWithRange:NSMakeRange(loc, len)];
    return [sub isEqualToString:expected];
}

void runBoldTests(NSFont *baseFont)
{
    printf("\n=== Bold Tests ===\n");

    // Basic bold: *hello*
    NSAttributedString *result = [AMPurpleJabberMessageStylingParser attributedStringFromStyledBody:@"*hello*" font:baseFont];
    TEST(@"bold: basic *hello*", hasBoldTrait(result, 0, 5));
    TEST(@"bold: content is 'hello'", stringAtRangeEquals(result, 0, 5, @"hello"));
    TEST(@"bold: length is 5", [result length] == 5);

    // Unmatched: *hello (no closer) — should display as literal but we parse as-is
    result = [AMPurpleJabberMessageStylingParser attributedStringFromStyledBody:@"*hello" font:baseFont];
    TEST(@"bold: unmatched *hello is literal", hasPlainFont(result, 0, 6));

    // Bold with space after opener should not be parsed
    result = [AMPurpleJabberMessageStylingParser attributedStringFromStyledBody:@"* hello *" font:baseFont];
    TEST(@"bold: space after opener is literal", stringAtRangeEquals(result, 0, 9, @"* hello *"));

    // Adjacent text
    result = [AMPurpleJabberMessageStylingParser attributedStringFromStyledBody:@"foo*bar*" font:baseFont];
    TEST(@"bold: adjacent foo*bar*", hasBoldTrait(result, 3, 3));
    TEST(@"bold: 'bar' is bold", stringAtRangeEquals(result, 3, 3, @"bar"));
}

void runItalicTests(NSFont *baseFont)
{
    printf("\n=== Italic Tests ===\n");

    // Basic italic: _hello_
    NSAttributedString *result = [AMPurpleJabberMessageStylingParser attributedStringFromStyledBody:@"_hello_" font:baseFont];
    TEST(@"italic: basic _hello_", hasItalicTrait(result, 0, 5));
    TEST(@"italic: content is 'hello'", stringAtRangeEquals(result, 0, 5, @"hello"));

    // Unmatched
    result = [AMPurpleJabberMessageStylingParser attributedStringFromStyledBody:@"_hello" font:baseFont];
    TEST(@"italic: unmatched is literal", hasPlainFont(result, 0, 6));
}

void runStrikethroughTests(NSFont *baseFont)
{
    printf("\n=== Strikethrough Tests ===\n");

    NSAttributedString *result = [AMPurpleJabberMessageStylingParser attributedStringFromStyledBody:@"~hello~" font:baseFont];
    TEST(@"strikethrough: basic ~hello~", hasStrikethrough(result, 0, 5));
    TEST(@"strikethrough: content is 'hello'", stringAtRangeEquals(result, 0, 5, @"hello"));
}

void runMonospaceTests(NSFont *baseFont)
{
    printf("\n=== Monospace Tests ===\n");

    NSAttributedString *result = [AMPurpleJabberMessageStylingParser attributedStringFromStyledBody:@"`hello`" font:baseFont];
    TEST(@"monospace: basic `hello`", hasMonospaceFont(result, 0, 5));
    TEST(@"monospace: content is 'hello'", stringAtRangeEquals(result, 0, 5, @"hello"));

    // Unmatched backtick
    result = [AMPurpleJabberMessageStylingParser attributedStringFromStyledBody:@"`hello" font:baseFont];
    TEST(@"monospace: unmatched is literal", stringAtRangeEquals(result, 0, 6, @"`hello"));
    TEST(@"monospace: unmatched has no mono font", hasPlainFont(result, 0, 6));
}

void runNestingTests(NSFont *baseFont)
{
    printf("\n=== Nesting Tests ===\n");

    // Bold inside italic: _*hello*_
    NSAttributedString *result = [AMPurpleJabberMessageStylingParser attributedStringFromStyledBody:@"_*hello*_" font:baseFont];
    TEST(@"nesting: italic outer * bold inner", hasBoldItalicTraits(result, 0, 5));
    TEST(@"nesting: content is 'hello'", stringAtRangeEquals(result, 0, 5, @"hello"));

    // Italic inside bold: *_hello_*
    result = [AMPurpleJabberMessageStylingParser attributedStringFromStyledBody:@"*_hello_*" font:baseFont];
    TEST(@"nesting: bold outer * italic inner", hasBoldItalicTraits(result, 0, 5));
    TEST(@"nesting: content is 'hello'", stringAtRangeEquals(result, 0, 5, @"hello"));
}

void runEscapeTests(NSFont *baseFont)
{
    printf("\n=== Escape Tests ===\n");

    NSAttributedString *result = [AMPurpleJabberMessageStylingParser attributedStringFromStyledBody:@"\\*hello\\*" font:baseFont];
    TEST(@"escape: literal *hello*", stringAtRangeEquals(result, 0, 7, @"*hello*"));
    TEST(@"escape: no bold trait", hasPlainFont(result, 0, 7));

    result = [AMPurpleJabberMessageStylingParser attributedStringFromStyledBody:@"\\_hello\\_" font:baseFont];
    TEST(@"escape: literal _hello_", stringAtRangeEquals(result, 0, 7, @"_hello_"));
    TEST(@"escape: no italic trait", hasPlainFont(result, 0, 7));
}

void runPreformattedBlockTests(NSFont *baseFont)
{
    printf("\n=== Preformatted Block Tests ===\n");

    // Simple pre block: ```\ncode\n```
    NSString *body = @"```\ncode\n```";
    NSAttributedString *result = [AMPurpleJabberMessageStylingParser attributedStringFromStyledBody:body font:baseFont];
    TEST(@"pre: content is 'code'", stringAtRangeEquals(result, 0, 4, @"code"));
    TEST(@"pre: content has monospace font", hasMonospaceFont(result, 0, 4));

    // Pre block with no span parsing inside
    body = @"```\n*not bold*\n```";
    result = [AMPurpleJabberMessageStylingParser attributedStringFromStyledBody:body font:baseFont];
    TEST(@"pre: inside has asterisks literal", stringAtRangeEquals(result, 0, 10, @"*not bold*"));
}

void runBlockquoteTests(NSFont *baseFont)
{
    printf("\n=== Blockquote Tests ===\n");

    NSAttributedString *result = [AMPurpleJabberMessageStylingParser attributedStringFromStyledBody:@"> hello" font:baseFont];
    TEST(@"blockquote: content is 'hello'", stringAtRangeEquals(result, 0, 5, @"hello"));
    // Blockquote content should be parsed, so *bold* inside works
    result = [AMPurpleJabberMessageStylingParser attributedStringFromStyledBody:@"> *bold*" font:baseFont];
    TEST(@"blockquote: content has bold", hasBoldTrait(result, 0, 4));
    TEST(@"blockquote: bold content is 'bold'", stringAtRangeEquals(result, 0, 4, @"bold"));
}

void runEdgeCaseTests(NSFont *baseFont)
{
    printf("\n=== Edge Case Tests ===\n");

    // Empty body
    NSAttributedString *result = [AMPurpleJabberMessageStylingParser attributedStringFromStyledBody:@"" font:baseFont];
    TEST(@"empty body returns empty", [result length] == 0);

    // nil body
    result = [AMPurpleJabberMessageStylingParser attributedStringFromStyledBody:nil font:baseFont];
    TEST(@"nil body returns empty", [result length] == 0);

    // Body with only whitespace
    result = [AMPurpleJabberMessageStylingParser attributedStringFromStyledBody:@"   " font:baseFont];
    TEST(@"whitespace body has length 3", [result length] == 3);

    // Plain text (no markers)
    result = [AMPurpleJabberMessageStylingParser attributedStringFromStyledBody:@"Hello, world!" font:baseFont];
    TEST(@"plain text: content preserved", stringAtRangeEquals(result, 0, 13, @"Hello, world!"));
    TEST(@"plain text: no bold", !hasBoldTrait(result, 0, 13));
    TEST(@"plain text: no italic", !hasItalicTrait(result, 0, 13));
}

int main(int argc, const char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    printf("XEP-0393 Message Styling Parser Tests\n");
    printf("======================================\n");

    NSFont *baseFont = [NSFont systemFontOfSize:12.0];

    runBoldTests(baseFont);
    runItalicTests(baseFont);
    runStrikethroughTests(baseFont);
    runMonospaceTests(baseFont);
    runNestingTests(baseFont);
    runEscapeTests(baseFont);
    runPreformattedBlockTests(baseFont);
    runBlockquoteTests(baseFont);
    runEdgeCaseTests(baseFont);

    printf("\n======================================\n");
    printf("Results: %lu passed, %lu failed out of %lu\n",
           (unsigned long)g_testsPassed,
           (unsigned long)g_testsFailed,
           (unsigned long)(g_testsPassed + g_testsFailed));

    [pool drain];

    return (g_testsFailed > 0) ? 1 : 0;
}
