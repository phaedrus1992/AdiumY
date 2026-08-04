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

#import <Foundation/Foundation.h>

/// Returns `html` with remote resource references neutralized so that importing it (e.g. pasting
/// rich text) cannot trigger network requests for embedded images, stylesheets, or scripts.
///
/// The following are removed:
/// - Values of resource attributes (`src`, `srcset`, `data`, `poster`, `background`, `codebase`,
///   `archive`, `longdesc`, and `href` on `<link>`/`<base>`) whose value starts with `http://`,
///   `https://`, or a protocol-relative `//`.
/// - `srcset` values that contain any `http://` or `https://` URL.
/// - CSS `url(http(s)://…)` references and `@import "http(s)://…"` statements.
///
/// Local and relative references, hyperlink (`<a href>`) targets, comments, and malformed markup
/// are preserved verbatim. The result is idempotent: sanitizing twice yields the same output as
/// sanitizing once.
///
/// @param html The HTML text to neutralize, or nil.
/// @return The neutralized HTML, or nil if `html` was nil.
NSString *AIHTMLStringByNeutralizingRemoteResources(NSString *html);
