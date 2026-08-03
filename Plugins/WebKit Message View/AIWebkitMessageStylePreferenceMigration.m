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

#import "AIWebkitMessageStylePreferenceMigration.h"
#import <AIUtilities/AIBundleIdentifier.h>

static NSString *const kStylePreferenceKey = @"Message Style";

NSDictionary *AIWebkitMessageStylePreferenceMigration(NSDictionary *prefs)
{
	if (prefs == nil || [prefs count] == 0)
		return nil;

	// Legacy bundle IDs — from pre-rename Adium (im.adium.*), the earlier AdiumX
	// iteration (com.adiumx.*), and a third-party style — mapped to the style
	// name each ships under the AdiumY prefix. Iterated in fixed order; when
	// several legacy IDs map to the same shipped style, the later (canonical)
	// entry wins, so the result is deterministic for a given input.
	static const struct {
		NSString *legacyBundleID;
		NSString *styleName;
	} legacyToShipped[] = {
		{@"com.adiumx.eclipse.style", @"gonedark.style"},
		{@"com.adiumx.plastic.style", @"stockholm.style"},
		{@"com.adiumx.minimal_2.0.style", @"minimal_mod.style"},
		{@"com.adiumx.renkooNaked.style", @"renkoo.style"},
		{@"com.adiumx.minimal.style", @"minimal_mod.style"},
		{@"com.adiumx.gonedark.style", @"gonedark.style"},
		{@"com.adiumx.minimal_mod.style", @"minimal_mod.style"},
		{@"com.adiumx.mockie.style", @"mockie.style"},
		{@"com.adiumx.renkoo.style", @"renkoo.style"},
		{@"com.adiumx.smooth.operator.style", @"smooth.operator.style"},
		{@"com.adiumx.stockholm.style", @"stockholm.style"},
		{@"mathuaerknedam.yMous.style", @"yMous.style"},
		{@"im.adium.Gone Dark.style", @"gonedark.style"},
		{@"im.adium.Stockholm.style", @"stockholm.style"},
		{@"im.adium.minimal_mod.style", @"minimal_mod.style"},
		{@"im.adium.Renkoo.style", @"renkoo.style"},
		{@"im.adium.Mockie.style", @"mockie.style"},
		{@"im.adium.Smooth Operator.style", @"smooth.operator.style"},
		{@"im.adium.yMous.style", @"yMous.style"},
	};
	NSUInteger const mappingCount = sizeof(legacyToShipped) / sizeof(legacyToShipped[0]);

	NSMutableDictionary *delta = nil;

	// Upgrade the displayed style itself (an exact match on the stored value).
	NSString *currentStyle = [prefs objectForKey:kStylePreferenceKey];
	if (currentStyle != nil && [currentStyle isKindOfClass:[NSString class]]) {
		for (NSUInteger i = 0; i < mappingCount; i++) {
			if ([currentStyle isEqualToString:legacyToShipped[i].legacyBundleID]) {
				NSString *newStyle =
					[kAdiumYBundleIdentifierPrefix stringByAppendingFormat:@".%@", legacyToShipped[i].styleName];
				if (![newStyle isEqualToString:currentStyle]) {
					if (delta == nil)
						delta = [NSMutableDictionary dictionary];
					[delta setObject:newStyle forKey:kStylePreferenceKey];
				}
				break;
			}
		}
	}

	// Remap style-specific preference keys prefixed by a legacy bundle ID.
	// Iterate the table outer so colliding legacy IDs resolve to a fixed table
	// entry instead of depending on dict enumeration order.
	for (NSUInteger i = 0; i < mappingCount; i++) {
		NSString *legacyBundleID = legacyToShipped[i].legacyBundleID;
		for (NSString *key in prefs) {
			if ([key isEqualToString:kStylePreferenceKey])
				continue;
			if (![key hasPrefix:legacyBundleID])
				continue;

			NSString *newKey =
				[[kAdiumYBundleIdentifierPrefix stringByAppendingFormat:@".%@", legacyToShipped[i].styleName]
					stringByAppendingString:[key substringFromIndex:[legacyBundleID length]]];

			// A key already under the fork bundle ID is authoritative; retire
			// the stale legacy key rather than overwriting it.
			if ([prefs objectForKey:newKey] != nil) {
				if (delta == nil)
					delta = [NSMutableDictionary dictionary];
				[delta setObject:[NSNull null] forKey:key];
				continue;
			}

			if (delta == nil)
				delta = [NSMutableDictionary dictionary];
			[delta setObject:[prefs objectForKey:key] forKey:newKey];
			[delta setObject:[NSNull null] forKey:key];
		}
	}

	return delta;
}
