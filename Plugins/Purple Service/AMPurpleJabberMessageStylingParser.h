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

#import <Foundation/Foundation.h>

@class NSFont;

NS_ASSUME_NONNULL_BEGIN

/// XEP-0393 Message Styling Parser
///
/// Converts styled message body text (with formatting markers for bold, italic,
/// strikethrough, and monospace) into an NSAttributedString with appropriate
/// font traits and text attributes.
///
/// Block-level constructs (preformatted blocks, blockquotes) and inline spans
/// (bold, italic, strikethrough, monospace) are parsed per the XEP-0393 spec.
/// Nested formatting is supported (e.g., *_text_* renders as bold-italic).
@interface AMPurpleJabberMessageStylingParser : NSObject

/// Parse a styled message body into an NSAttributedString.
///
/// @param body The raw message body text with styling markers
/// @param baseFont The base font to use for unstyled text; traits are applied as deltas
/// @return An NSAttributedString with formatting attributes applied, or an empty string if body is nil/empty
+ (NSAttributedString *)attributedStringFromStyledBody:(nullable NSString *)body
                                                  font:(NSFont *)baseFont;

@end

NS_ASSUME_NONNULL_END
