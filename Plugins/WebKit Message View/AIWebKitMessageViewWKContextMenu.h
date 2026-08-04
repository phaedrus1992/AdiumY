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

/// Parsed `contextMenu` script message from the WKWebView message bridge (see
/// AIWebKitMessageViewWKController.m). Pure and side-effect-free so it can be
/// unit-tested directly (issue #152).
typedef struct {
	/// clientX from the JS event, in viewport coordinates.
	double x;
	/// clientY from the JS event, in viewport coordinates.
	double y;
	/// The image URL string from the body, or nil when absent or empty.
	NSString *imageURLString;
	/// YES when the body is a well-formed contextMenu message; see AIWKContextMenuMessageFromBody.
	BOOL valid;
} AIWKContextMenuMessage;

/// Parses and validates a script-message body for the `contextMenu` handler.
///
/// A body is valid when it is a dictionary whose `type` is the string "contextMenu"
/// and whose `x`/`y` are NSNumber. `imageURL`, when present, must be a non-empty
/// string; it is normalized to nil otherwise. Any other shape yields `valid == NO`
/// with undefined x/y/imageURLString.
///
/// @param body The WKScriptMessage body (nil, a non-dictionary, or a dictionary).
/// @return The parsed message; `valid` indicates whether the fields are meaningful.
AIWKContextMenuMessage AIWKContextMenuMessageFromBody(id body);

/// Returns the image URL for a context-menu `imageURL` string, or nil when the
/// string does not form a usable URL. Thin wrapper around +[NSURL URLWithString:]
/// extracted so the parse gate can be property-tested (issue #152).
NSURL *AIWKImageURLFromString(NSString *imageURLString);

/// Whether "Save Image As" should be offered for an image URL: file: URLs are
/// copied directly, http(s) URLs are downloaded first (issue #151). Any other
/// scheme — or nil — is not savable.
BOOL AIWKCanSaveImageURL(NSURL *imageURL);
