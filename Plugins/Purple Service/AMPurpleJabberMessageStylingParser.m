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

#import "AMPurpleJabberMessageStylingParser.h"
#import <AppKit/AppKit.h>

/// Maximum nesting depth for span formatting to prevent pathological input.
#define AMPARSE_MAX_DEPTH 10

/// The three-grave-accent preformatted block delimiter.
#define AMPARSE_PRE_DELIMITER @"```"

@interface AMPurpleJabberMessageStylingParser ()

#pragma mark - Block-level parsing

/// Parse the body text applying block-level constructs (pre blocks, blockquotes)
/// and span-level formatting within each block.
///
/// @param body The input text
/// @param baseFont The base font for unstyled text
/// @return An NSAttributedString with block and span formatting applied
+ (NSAttributedString *)_parseBlocksInBody:(NSString *)body
                                      font:(NSFont *)baseFont;

/// Process a single line range for inline spans, appending to the result.
///
/// @param line A single line of text (no newline)
/// @param result The mutable attributed string to append to
/// @param baseFont The base font for unstyled text
/// @param depth Current recursion depth (for safety limit)
+ (void)_appendLine:(NSString *)line
             toResult:(NSMutableAttributedString *)result
             baseFont:(NSFont *)baseFont
                depth:(NSUInteger)depth;

/// Append formatted text for a span between an opening and closing delimiter.
///
/// @param text The content text between delimiters
/// @param result The mutable attributed string to append to
/// @param baseFont The base font for unstyled text
/// @param boldTrait Whether to add bold trait
/// @param italicTrait Whether to add italic trait
/// @param strikethrough Whether to add strikethrough
/// @param monospace Whether to use monospace font
/// @param depth Current recursion depth
+ (void)_appendFormattedText:(NSString *)text
                      toResult:(NSMutableAttributedString *)result
                      baseFont:(NSFont *)baseFont
                     boldTrait:(BOOL)boldTrait
                   italicTrait:(BOOL)italicTrait
                  strikethrough:(BOOL)strikethrough
                     monospace:(BOOL)monospace
                         depth:(NSUInteger)depth;

/// Apply formatting attributes to a range of the attributed string.
///
/// @param range The range to format (in the attributed string)
/// @param result The attributed string to modify
/// @param baseFont The base font
/// @param boldTrait Whether to add bold trait
/// @param italicTrait Whether to add italic trait
/// @param strikethrough Whether to add strikethrough
/// @param monospace Whether to use monospace font
+ (void)_applyFormattingToRange:(NSRange)range
                         inString:(NSMutableAttributedString *)result
                         baseFont:(NSFont *)baseFont
                        boldTrait:(BOOL)boldTrait
                      italicTrait:(BOOL)italicTrait
                     strikethrough:(BOOL)strikethrough
                        monospace:(BOOL)monospace;

/// Check if a character is a span delimiter.
+ (BOOL)_isSpanDelimiter:(unichar)c;

/// Check if a character at a given position in a string is a valid opening delimiter.
+ (BOOL)_isValidOpenerAt:(NSUInteger)pos inString:(NSString *)s;

/// Check if a character at a given position is a valid closing delimiter.
+ (BOOL)_isValidCloserAt:(NSUInteger)pos inString:(NSString *)s;

/// Find the position of a matching closing delimiter for a given opening delimiter, starting from a given position.
/// Returns NSNotFound if no valid match is found.
+ (NSUInteger)_findMatchingCloseForDelimiter:(unichar)delim
                                      inString:(NSString *)s
                                    fromPosition:(NSUInteger)startPos;

/// Apply font trait mask changes to the base font, returning a new font.
+ (NSFont *)_fontWithTraits:(NSFontTraitMask)traits fromBaseFont:(NSFont *)baseFont;

@end

#pragma mark - Implementation

@implementation AMPurpleJabberMessageStylingParser

#pragma mark - Public API

+ (NSAttributedString *)attributedStringFromStyledBody:(NSString *)body
                                                  font:(NSFont *)baseFont
{
    if (body == nil || [body length] == 0) {
        return [[[NSAttributedString alloc] init] autorelease];
    }

    return [self _parseBlocksInBody:body font:baseFont];
}

#pragma mark - Block-level parsing

+ (NSAttributedString *)_parseBlocksInBody:(NSString *)body
                                      font:(NSFont *)baseFont
{
    NSMutableAttributedString *result = [[[NSMutableAttributedString alloc] init] autorelease];

    NSArray *lines = [body componentsSeparatedByString:@"\n"];
    NSUInteger i = 0;
    NSUInteger lineCount = [lines count];

    while (i < lineCount) {
        NSString *line = [lines objectAtIndex:i];

        // Check for preformatted block (line starting with ```)
        if ([line hasPrefix:AMPARSE_PRE_DELIMITER]) {
            // Find the end of the pre block
            NSMutableArray *preLines = [NSMutableArray array];
            i++;
            while (i < lineCount) {
                NSString *preLine = [lines objectAtIndex:i];
                // A line that is exactly ``` (possibly with trailing whitespace) closes the block
                NSString *trimmedLine = [preLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if ([trimmedLine isEqualToString:AMPARSE_PRE_DELIMITER]) {
                    i++;
                    break;
                }
                [preLines addObject:preLine];
                i++;
            }

            // Join pre block lines
            NSString *preText = [preLines componentsJoinedByString:@"\n"];
            if ([preText length] > 0) {
                NSMutableAttributedString *preAttr = [[[NSMutableAttributedString alloc] initWithString:preText] autorelease];
                NSFont *monoFont = [NSFont userFixedPitchFontOfSize:[baseFont pointSize]];
                [preAttr addAttribute:NSFontAttributeName value:monoFont range:NSMakeRange(0, [preText length])];
                if ([result length] > 0) {
                    [result appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\n"] autorelease]];
                }
                [result appendAttributedString:preAttr];
            }
            continue;
        }

        // Check for blockquote (line starting with >)
        if ([line hasPrefix:@">"]) {
            NSMutableArray *quoteLines = [NSMutableArray array];
            while (i < lineCount) {
                NSString *ql = [lines objectAtIndex:i];
                if (![ql hasPrefix:@">"]) {
                    break;
                }

                // Trim the leading `>` and optional single space per spec
                NSString *content = [ql substringFromIndex:1];
                if ([content hasPrefix:@" "]) {
                    content = [content substringFromIndex:1];
                }
                [quoteLines addObject:content];
                i++;
            }

            // Parse the quote content recursively (supports nested quotes)
            NSString *quoteBody = [quoteLines componentsJoinedByString:@"\n"];
            NSAttributedString *quoteAttr = [self _parseBlocksInBody:quoteBody font:baseFont];

            if ([result length] > 0) {
                [result appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\n"] autorelease]];
            }
            [result appendAttributedString:quoteAttr];
            continue;
        }

        // Plain paragraph — process inline spans
        if ([line length] > 0) {
            if ([result length] > 0) {
                [result appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\n"] autorelease]];
            }
            [self _appendLine:line toResult:result baseFont:baseFont depth:0];
        } else {
            // Empty line — preserve blank line separator
            if ([result length] > 0) {
                [result appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\n"] autorelease]];
            }
        }

        i++;
    }

    return result;
}

#pragma mark - Inline span parsing

+ (void)_appendLine:(NSString *)line
            toResult:(NSMutableAttributedString *)result
            baseFont:(NSFont *)baseFont
               depth:(NSUInteger)depth
{
    [self _appendFormattedText:line
                      toResult:result
                      baseFont:baseFont
                     boldTrait:NO
                   italicTrait:NO
                  strikethrough:NO
                     monospace:NO
                         depth:depth];
}

+ (void)_appendFormattedText:(NSString *)text
                      toResult:(NSMutableAttributedString *)result
                      baseFont:(NSFont *)baseFont
                     boldTrait:(BOOL)boldTrait
                   italicTrait:(BOOL)italicTrait
                  strikethrough:(BOOL)strikethrough
                     monospace:(BOOL)monospace
                         depth:(NSUInteger)depth
{
    if (depth >= AMPARSE_MAX_DEPTH) {
        // Safety limit: append literal text and return
        NSMutableAttributedString *plain = [[[NSMutableAttributedString alloc] initWithString:text] autorelease];
        [self _applyFormattingToRange:NSMakeRange(0, [text length])
                             inString:plain
                             baseFont:baseFont
                            boldTrait:boldTrait
                          italicTrait:italicTrait
                         strikethrough:strikethrough
                            monospace:monospace];
        [result appendAttributedString:plain];
        return;
    }

    NSUInteger len = [text length];
    NSUInteger i = 0;
    NSMutableString *plainBuffer = [[[NSMutableString alloc] init] autorelease];

    while (i < len) {
        unichar c = [text characterAtIndex:i];

        // Backslash escaping: include the next character literally
        if (c == '\\' && i + 1 < len) {
            [plainBuffer appendString:[text substringWithRange:NSMakeRange(i + 1, 1)]];
            i += 2;
            continue;
        }

        // In monospace mode, don't interpret styling delimiters
        if (monospace) {
            [plainBuffer appendString:[NSString stringWithCharacters:&c length:1]];
            i++;
            continue;
        }

        // Check for inline code span (backtick) — has priority over other delimiters
        if (c == '`') {
            NSUInteger closerPos = [self _findMatchingCloseForDelimiter:'`' inString:text fromPosition:i + 1];
            if (closerPos != NSNotFound) {
                // Flush plain buffer
                if ([plainBuffer length] > 0) {
                    NSMutableAttributedString *plainPart = [[[NSMutableAttributedString alloc] initWithString:plainBuffer] autorelease];
                    [self _applyFormattingToRange:NSMakeRange(0, [plainBuffer length])
                                         inString:plainPart
                                         baseFont:baseFont
                                        boldTrait:boldTrait
                                      italicTrait:italicTrait
                                     strikethrough:strikethrough
                                        monospace:NO];
                    [result appendAttributedString:plainPart];
                    [plainBuffer setString:@""];
                }

                NSRange contentRange = NSMakeRange(i + 1, closerPos - i - 1);
                NSString *codeText = [text substringWithRange:contentRange];
                NSMutableAttributedString *codeAttr = [[[NSMutableAttributedString alloc] initWithString:codeText] autorelease];
                [self _applyFormattingToRange:NSMakeRange(0, [codeText length])
                                     inString:codeAttr
                                     baseFont:baseFont
                                    boldTrait:boldTrait
                                  italicTrait:italicTrait
                                 strikethrough:strikethrough
                                    monospace:YES];
                [result appendAttributedString:codeAttr];
                i = closerPos + 1;
                continue;
            }
            // No valid closer — treat as literal
            [plainBuffer appendString:[NSString stringWithCharacters:&c length:1]];
            i++;
            continue;
        }

        // Check for other span delimiters (*, _, ~)
        if ([self _isSpanDelimiter:c]) {
            BOOL validOpener = [self _isValidOpenerAt:i inString:text];
            BOOL validCloser = [self _isValidCloserAt:i inString:text];

            if (validOpener) {
                // Check if this also could be a closer (ambiguous). If so, prefer closer (lazy matching).
                if (validCloser && depth > 0) {
                    // Both opener and closer — closer wins (lazy)
                    [plainBuffer appendString:[NSString stringWithCharacters:&c length:1]];
                    i++;
                    continue;
                }

                // Valid opener — try to find closer
                NSUInteger closerPos = [self _findMatchingCloseForDelimiter:c inString:text fromPosition:i + 1];
                if (closerPos != NSNotFound) {
                    // Flush plain buffer
                    if ([plainBuffer length] > 0) {
                        NSMutableAttributedString *plainPart = [[[NSMutableAttributedString alloc] initWithString:plainBuffer] autorelease];
                        [self _applyFormattingToRange:NSMakeRange(0, [plainBuffer length])
                                             inString:plainPart
                                             baseFont:baseFont
                                            boldTrait:boldTrait
                                          italicTrait:italicTrait
                                         strikethrough:strikethrough
                                            monospace:NO];
                        [result appendAttributedString:plainPart];
                        [plainBuffer setString:@""];
                    }

                    // Extract content between delimiters
                    NSRange contentRange = NSMakeRange(i + 1, closerPos - i - 1);
                    NSString *innerText = [text substringWithRange:contentRange];

                    // Set new traits for the inner content
                    BOOL newBold = boldTrait || (c == '*');
                    BOOL newItalic = italicTrait || (c == '_');
                    BOOL newStrike = strikethrough || (c == '~');

                    // Recursively parse inner content (supports nesting)
                    [self _appendFormattedText:innerText
                                      toResult:result
                                      baseFont:baseFont
                                     boldTrait:newBold
                                   italicTrait:newItalic
                                  strikethrough:newStrike
                                     monospace:NO
                                         depth:depth + 1];

                    i = closerPos + 1;
                    continue;
                }
            }

            // Not a valid opener or no closer found — treat as literal
            [plainBuffer appendString:[NSString stringWithCharacters:&c length:1]];
            i++;
            continue;
        }

        // Regular character
        [plainBuffer appendString:[NSString stringWithCharacters:&c length:1]];
        i++;
    }

    // Flush remaining plain buffer
    if ([plainBuffer length] > 0) {
        NSMutableAttributedString *plainPart = [[[NSMutableAttributedString alloc] initWithString:plainBuffer] autorelease];
        [self _applyFormattingToRange:NSMakeRange(0, [plainBuffer length])
                             inString:plainPart
                             baseFont:baseFont
                            boldTrait:boldTrait
                          italicTrait:italicTrait
                         strikethrough:strikethrough
                            monospace:NO];
        [result appendAttributedString:plainPart];
    }
}

#pragma mark - Attribute Application

+ (void)_applyFormattingToRange:(NSRange)range
                         inString:(NSMutableAttributedString *)result
                         baseFont:(NSFont *)baseFont
                        boldTrait:(BOOL)boldTrait
                      italicTrait:(BOOL)italicTrait
                     strikethrough:(BOOL)strikethrough
                        monospace:(BOOL)monospace
{
    if (range.length == 0) {
        return;
    }

    // Build font with traits
    NSFontTraitMask traits = 0;
    if (boldTrait) {
        traits |= NSBoldFontMask;
    }
    if (italicTrait) {
        traits |= NSItalicFontMask;
    }

    NSFont *font;
    if (monospace) {
        font = [NSFont userFixedPitchFontOfSize:[baseFont pointSize]];
    } else if (traits != 0) {
        font = [self _fontWithTraits:traits fromBaseFont:baseFont];
    } else {
        font = baseFont;
    }

    [result addAttribute:NSFontAttributeName value:font range:range];

    if (strikethrough) {
        [result addAttribute:NSStrikethroughStyleAttributeName
                       value:[NSNumber numberWithInteger:NSUnderlineStyleSingle]
                       range:range];
    }
}

+ (NSFont *)_fontWithTraits:(NSFontTraitMask)traits fromBaseFont:(NSFont *)baseFont
{
    NSFontManager *fm = [NSFontManager sharedFontManager];
    NSFont *font = [fm convertFont:baseFont toHaveTrait:traits];
    return font ? font : baseFont;
}

#pragma mark - Delimiter Detection

+ (BOOL)_isSpanDelimiter:(unichar)c
{
    return (c == '*' || c == '_' || c == '~');
}

+ (BOOL)_isValidOpenerAt:(NSUInteger)pos inString:(NSString *)s
{
    NSUInteger len = [s length];
    if (pos >= len) {
        return NO;
    }

    unichar c = [s characterAtIndex:pos];
    if (![self _isSpanDelimiter:c]) {
        return NO;
    }

    // Opening directive must NOT be followed by whitespace
    if (pos + 1 < len) {
        unichar next = [s characterAtIndex:pos + 1];
        if ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:next]) {
            return NO;
        }
    }

    return YES;
}

+ (BOOL)_isValidCloserAt:(NSUInteger)pos inString:(NSString *)s
{
    NSUInteger len = [s length];
    if (pos >= len) {
        return NO;
    }

    unichar c = [s characterAtIndex:pos];
    if (![self _isSpanDelimiter:c]) {
        return NO;
    }

    // Closing directive must NOT be preceded by whitespace
    if (pos == 0) {
        return NO;
    }

    unichar prev = [s characterAtIndex:pos - 1];
    if ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:prev]) {
        return NO;
    }

    return YES;
}

+ (NSUInteger)_findMatchingCloseForDelimiter:(unichar)delim
                                      inString:(NSString *)s
                                    fromPosition:(NSUInteger)startPos
{
    NSUInteger len = [s length];

    // Backtick uses simple matching (next unescaped backtick is the closer)
    // Backtick is not in _isSpanDelimiter, so the standard opener/closer validation
    // would never match it — handle it separately here.
    if (delim == '`') {
        for (NSUInteger i = startPos; i < len; i++) {
            unichar c = [s characterAtIndex:i];
            if (c == '\\' && i + 1 < len) {
                i++;
                continue;
            }
            if (c == '`') {
                return i;
            }
        }
        return NSNotFound;
    }

    NSUInteger depth = 0;

    for (NSUInteger i = startPos; i < len; i++) {
        unichar c = [s characterAtIndex:i];

        // Handle backslash escaping
        if (c == '\\' && i + 1 < len) {
            i++; // Skip escaped character
            continue;
        }

        // Track nesting depth for nested spans of the SAME delimiter type
        // (for lazy matching, we only care about the same delimiter)
        if (c == delim) {
            // Check if this is a valid closer FIRST (lazy matching — prefer closer over opener)
            if ([self _isValidCloserAt:i inString:s]) {
                if (depth > 0) {
                    // Closing a nested same-type delimiter
                    depth--;
                    continue;
                }

                // Content must be at least 1 character
                if (i - startPos > 0) {
                    return i;
                }

                // Empty span - invalid, continue searching
                continue;
            }

            // Only if not a valid closer, check if it's a valid opener
            if ([self _isValidOpenerAt:i inString:s]) {
                depth++;
                continue;
            }
        }

        // Track nesting for other delimiter types too (they affect opener validity)
        if ([self _isSpanDelimiter:c] && c != delim) {
            // Other delimiters are also valid openers/closers - just skip them
            // They're handled in _appendFormattedText's recursive calls
            continue;
        }

        // Regular character: no action needed, continue scanning
    }

    return NSNotFound;
}

@end
