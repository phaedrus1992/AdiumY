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

/* Central definition of the AdiumY bundle-ID prefix. Every hardcoded
 * "com.github.phaedrus1992.adiumy" site in the codebase should reference these
 * macros instead, so the fork identity can't drift across the codebase.
 */

#ifndef AIUTILITIES_AIBUNDLEIDENTIFIER_H
#define AIUTILITIES_AIBUNDLEIDENTIFIER_H

/// The reverse-DNS prefix (no trailing dot) shared by every bundle ID AdiumY
/// ships: bundles, preference groups, UTIs, dispatch queue names, etc.
#define kAdiumYBundleIdentifierPrefixC "com.github.phaedrus1992.adiumy"

/// The prefix as an NSString literal (no trailing dot).
#define kAdiumYBundleIdentifierPrefix @kAdiumYBundleIdentifierPrefixC

/// The prefix including a trailing dot, for call sites that append a name directly.
#define kAdiumYBundleIdentifierPrefixDot @kAdiumYBundleIdentifierPrefixC "."

#endif /* AIUTILITIES_AIBUNDLEIDENTIFIER_H */
