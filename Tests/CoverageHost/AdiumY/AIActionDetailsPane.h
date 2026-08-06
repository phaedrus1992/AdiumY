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

/*
 * Stub for the standalone CoverageHost test target. The real AIActionDetailsPane subclasses
 * AIModularPane (a heavy AppKit panel hierarchy); a plain NSObject exposing the factory the plugin
 * calls is enough for ErrorMessageHandlerPlugin.m and ESPanelAlertDetailPane.h to compile. Cocoa is
 * imported here so ESPanelAlertDetailPane.h (whose ivars reference NSTextField/NSTextView) compiles
 * before any AIUtilities header in the plugin TU pulls in AppKit.
 */
#import <Cocoa/Cocoa.h>

@interface AIActionDetailsPane : NSObject

+ (AIActionDetailsPane *)actionDetailsPane;

@end
