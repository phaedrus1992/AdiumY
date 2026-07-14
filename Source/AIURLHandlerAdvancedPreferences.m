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

#import "AIURLHandlerAdvancedPreferences.h"
#import "AIPreferenceWindowController.h"

#import <AIUtilities/AIArrayAdditions.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIImageDrawingAdditions.h>
#import <AIUtilities/AIImageTextCell.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIService.h>
#import <Adium/AIServiceIcons.h>

@interface AIURLHandlerAdvancedPreferences ()
- (void)configureTableView;

- (void)initializeServiceInformationForSchemes:(NSArray *)schemes;
- (NSMenu *)applicationMenuForScheme:(NSString *)scheme;
- (NSArray *)applicationDictionaryArrayForScheme:(NSString *)scheme;
- (NSImage *)serviceImageForScheme:(NSString *)scheme;
- (NSString *)serviceNameForScheme:(NSString *)scheme;
@end

@implementation AIURLHandlerAdvancedPreferences
#pragma mark Preference pane settings
- (AIPreferenceCategory)category
{
	return AIPref_Advanced;
}
- (NSString *)label
{
	return AILocalizedString(@"Default Client", nil);
}
- (NSString *)nibName
{
	return @"AIURLHandlerPreferences";
}
- (NSImage *)image
{
	return
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return servicesList.count;
}

- (void)tableView:(NSTableView *)tableView
	willDisplayCell:(id)cell
	 forTableColumn:(NSTableColumn *)tableColumn
				row:(NSInteger)row
{
	NSString *identifier = tableColumn.identifier;
	NSString *scheme = [servicesList objectAtIndex:row];

	if ([identifier isEqualToString:@"service"]) {
		// Configure to display the service icon and service name.
		[cell setImage:[self serviceImageForScheme:scheme]];
	} else if ([identifier isEqualToString:@"applications"]) {
		NSMenu *menu = [self applicationMenuForScheme:scheme];
		NSString *defaultApplication = [plugin defaultApplicationBundleIDForScheme:scheme];

		// Letting the NSPopupButtonCell handle state causes some buggy results. Do it ourself.
		for (NSMenuItem *menuItem in menu.itemArray) {
			[menuItem setState:[menuItem.representedObject isEqualToString:defaultApplication]];
		}

		[cell setMenu:menu];
		[cell setAltersStateOfSelectedItem:NO];
		[cell selectItemAtIndex:[cell indexOfItemWithRepresentedObject:defaultApplication]];
	}
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSString *identifier = tableColumn.identifier;
	NSString *scheme = [servicesList objectAtIndex:row];

	if ([identifier isEqualToString:@"service"]) {
		return [self serviceNameForScheme:scheme];
	}

	return nil;
}

- (void)tableView:(NSTableView *)aTableView
	setObjectValue:(id)object
	forTableColumn:(NSTableColumn *)tableColumn
			   row:(NSInteger)row
{
	NSString *identifier = tableColumn.identifier;
	NSString *scheme = [servicesList objectAtIndex:row];

	if ([identifier isEqualToString:@"applications"]) {
		[plugin setDefaultForScheme:scheme
						 toBundleID:[[[self applicationMenuForScheme:scheme] itemAtIndex:[object integerValue]]
										representedObject]];
	}
}

@end
