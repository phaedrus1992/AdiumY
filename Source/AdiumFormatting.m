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

#import "AdiumFormatting.h"
#import <AIUtilities/AIColorAdditions.h>
#import <AIUtilities/AIDictionaryAdditions.h>
#import <AIUtilities/AIFontAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AITextAttributes.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIMenuControllerProtocol.h>

#define DEFAULT_FORMATTING_DEFAULT_PREFS @"FormattingDefaults"

@interface AdiumFormatting ()
- (void)restoreDefaultFormat:(id)sender;
@end

@implementation AdiumFormatting

/*!
 * @brief Init
 */
- (id)init
{
	if ((self = 
	_defaultAttributes = nil;
}

- (void)restoreDefaultFormat:(id)sender
{
	NSResponder *responder = [[NSApp mainWindow] firstResponder];
	if ([responder isKindOfClass:[NSTextView class]]) {
		[(NSTextView *)responder setTypingAttributes:[self defaultFormattingAttributes]];
	}
}

/*!
 * @brief Enable/disable our restore default formatting menu item
 *
 * The item should only be enabled if the current responder has typing attributes and those typing attributes are not
 * the default attributes
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	NSResponder *responder = [[NSApp mainWindow] firstResponder];

	if (![responder isKindOfClass:[NSTextView class]]) {
		return NO;
	}

	NSDictionary *defaultAttributes = [self defaultFormattingAttributes];
	NSSet *defaultAttributeKeysSet = [NSSet setWithArray:[defaultAttributes allKeys]];
	NSDictionary *typingAttributes =
		[[(NSTextView *)responder typingAttributes] dictionaryWithIntersectionWithSetOfKeys:defaultAttributeKeysSet];

	return (![typingAttributes isEqualToDictionary:defaultAttributes]);
}

@end
