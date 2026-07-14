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

#import "ESAddressBookIntegrationAdvancedPreferences.h"
#import <AIUtilities/AIDictionaryAdditions.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <Adium/AIAddressBookController.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AILocalizationTextField.h>

@interface NSTokenField (NSTokenFieldAdditions)
- (void)updateDisplay;
@end

@implementation NSTokenField (NSTokenFieldAdditions)
- (void)updateDisplay
{
	NSRange selectionRange = if (!representedObject) return nil;

	NSString *fullName = [self tokenField:tokenField
		displayStringForRepresentedObject:[representedObject stringByReplacingOccurrencesOfString:@"INITIAL"
																					   withString:@"FULL"]];
	[menu addItemWithTitle:fullName
					target:self
					action:@selector(changeFormatToFullName:)
			 keyEquivalent:@""
		 representedObject:representedObject];

	NSString *initialCharacter = [self tokenField:tokenField
				displayStringForRepresentedObject:[representedObject stringByReplacingOccurrencesOfString:@"FULL"
																							   withString:@"INITIAL"]];
	[menu addItemWithTitle:initialCharacter
					target:self
					action:@selector(changeFormatToInitialCharacter:)
			 keyEquivalent:@""
		 representedObject:representedObject];

	return menu;
}

- (void)changeFormatToInitialCharacter:(id)sender
{
	[[sender representedObject] replaceOccurrencesOfString:FORMAT_FULL
												withString:FORMAT_INITIAL
												   options:NSLiteralSearch
													 range:NSMakeRange(0, [[sender representedObject] length])];

	[tokenField_format updateDisplay];
	[self changeFormat:tokenField_format];
}

- (void)changeFormatToFullName:(id)sender
{
	[[sender representedObject] replaceOccurrencesOfString:FORMAT_INITIAL
												withString:FORMAT_FULL
												   options:NSLiteralSearch
													 range:NSMakeRange(0, [[sender representedObject] length])];

	[tokenField_format updateDisplay];
	[self changeFormat:tokenField_format];
}

- (NSArray *)separateStringIntoTokens:(NSString *)string
{
	NSMutableArray *tokens = [NSMutableArray array];

	int i = 0;
	while (i < [string length]) {
		unsigned int start = i;

		// Search for end of current token
		if ([[string substringFromIndex:i] hasPrefix:@"%["]) {
			for (; i < [string length]; i++) {
				if ([[string substringFromIndex:i] hasPrefix:@"]"]) {
					i++;
					break;
				}
			}

			// Search for start of next token
		} else {
			for (; i < [string length]; i++) {
				if ([[string substringFromIndex:(i + 1)] hasPrefix:@"%["]) {
					i++;
					break;
				}
			}
		}

		[tokens addObject:[[string substringWithRange:NSMakeRange(start, i - start)] mutableCopy]];
	}

	return tokens;
}

@end
