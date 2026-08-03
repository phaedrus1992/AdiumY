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

/// Migrates pre-fork WebKit message-style preferences to the AdiumY bundle-ID
/// namespace. Pure and side-effect-free so it can be unit-tested directly;
/// the caller applies the returned delta.
///
/// Two kinds of change are recognized, in this order:
///  1. The displayed style itself (key "Message Style") whose value is a
///     legacy pre-fork bundle ID is upgraded to the fork's shipped bundle ID.
///  2. Any other key prefixed by a legacy bundle ID (style-specific prefs like
///     <bundleID>.FontColor) is remapped to the fork bundle ID; the obsolete
///     key is marked for deletion.
///
/// @param prefs The style-preference dict to migrate. nil yields nil.
/// @return A delta dict of changed keys, or nil when nothing changes. Values
///         are the new value; NSNull marks a key to delete. Iteration over the
///         legacy ID table is in fixed order, first match wins, so the result
///         is deterministic for a given input.
NSDictionary *AIWebkitMessageStylePreferenceMigration(NSDictionary *prefs);
