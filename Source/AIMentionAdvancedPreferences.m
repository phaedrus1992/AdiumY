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

#import "AIMentionAdvancedPreferences.h"
#import "AIPreferenceWindowController.h"

#import <AIUtilities/AIArrayAdditions.h>
#import <AIUtilities/AIImageAdditions.h>

@interface AIMentionAdvancedPreferences ()
- (void)saveTerms;
@end

@implementation AIMentionAdvancedPreferences

#pragma mark Preference pane settings
- (AIPreferenceCategory)category
{
	return AIPref_Advanced;
}
- (NSString *)label
{
	return AILocalizedString(@"Mention", nil);
}
- (NSString *)nibName
{
	return @"AIMentionAdvancedPreferences";
}
- (NSImage *)image
{
	return mentionTerms = nil;

	[super viewWillClose];
}

#pragma mark Table view Delegate
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return mentionTerms.count;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	NSString *identifier = tableColumn.identifier;

	if ([identifier isEqualToString:@"text"]) {
		return [mentionTerms objectAtIndex:rowIndex];
	}

	return nil;
}

- (void)tableView:(NSTableView *)aTableView
	setObjectValue:(id)object
	forTableColumn:(NSTableColumn *)tableColumn
			   row:(NSInteger)row
{
	NSString *identifier = tableColumn.identifier;

	if ([identifier isEqualToString:@"text"]) {
		[mentionTerms replaceObjectAtIndex:row withObject:object];
		[self saveTerms];
	}
}

- (void)tableViewDeleteSelectedRows:(NSTableView *)tableView
{
	[self remove:nil];
}

@end
