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

#import "RAFBlockEditorWindowController.h"
#import <AIUtilities/AICompletingTextField.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIPopUpButtonAdditions.h>
#import <Adium/AIAccount.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIListContact.h>
#import <Adium/AIListGroup.h>
#import <Adium/AIMetaContact.h>
#import <Adium/AIService.h>

@interface RAFBlockEditorWindowController ()
- (NSMenu *)privacyOptionsMenu;
- (AIAccount<AIAccount_Privacy> *)selectedAccount;
- (void)configureTextField;
- (NSSet *)contactsFromTextField;
- (AIPrivacyOption)selectedPrivacyOption;
- (void)privacySettingsChangedExternally:(NSNotification *)inNotification;
- (void)runBlockSheet;
- (void)removeSelection;
@end

@implementation RAFBlockEditorWindowController

static RAFBlockEditorWindowController *sharedInstance = nil;

+ (void)showWindow
{
	if (!sharedInstance) {
		sharedInstance = dragItems = inArray;
	}

	return YES;
}

- (BOOL)tableView:(NSTableView *)tv writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard
{
	NSMutableArray *itemArray = [NSMutableArray array];
	NSNumber *rowNumber;
	for (rowNumber in rows) {
		[itemArray addObject:[listContents objectAtIndex:[rowNumber integerValue]]];
	}

	return [self writeListObjects:itemArray toPasteboard:pboard];
}

- (BOOL)tableView:(NSTableView *)aTableView
	writeRowsWithIndexes:(NSIndexSet *)rowIndexes
			toPasteboard:(NSPasteboard *)pboard
{
	NSMutableArray *itemArray = [NSMutableArray array];
	id item;

	NSUInteger bufSize = [rowIndexes count];
	NSUInteger *buf = malloc(bufSize * sizeof(NSUInteger));
	NSUInteger i;

	NSRange range = NSMakeRange([rowIndexes firstIndex], ([rowIndexes lastIndex] - [rowIndexes firstIndex]) + 1);
	[rowIndexes getIndexes:buf maxCount:bufSize inIndexRange:&range];

	for (i = 0; i != bufSize; i++) {
		if ((item = [listContents objectAtIndex:buf[i]])) {
			[itemArray addObject:item];
		}
	}

	free(buf);

	return [self writeListObjects:itemArray toPasteboard:pboard];
}

- (void)pasteboard:(NSPasteboard *)sender provideDataForType:(NSString *)type
{
	// Provide an array of internalObjectIDs which can be used to reference all the dragged contacts
	if ([type isEqualToString:@"AIListObjectUniqueIDs"]) {

		if (dragItems) {
			NSMutableArray *dragItemsArray = [NSMutableArray array];
			AIListObject *listObject;

			for (listObject in dragItems) {
				[dragItemsArray addObject:listObject.internalObjectID];
			}

			[sender setPropertyList:dragItemsArray forType:@"AIListObjectUniqueIDs"];
		}
	}
}

- (NSDragOperation)tableView:(NSTableView *)tv
				validateDrop:(id<NSDraggingInfo>)info
				 proposedRow:(NSInteger)row
	   proposedDropOperation:(NSTableViewDropOperation)op
{

	NSDragOperation dragOp = NSDragOperationCopy;

	if ([info draggingSource] == table) {
		dragOp = NSDragOperationMove;
	}
	[tv setDropRow:row dropOperation:NSTableViewDropAbove];

	return dragOp;
}

- (void)addListObjectToList:(AIListObject *)listObject
{
	AIListObject *containedObject;
	NSEnumerator *enumerator;

	if ([listObject isKindOfClass:[AIListGroup class]]) {
		enumerator = [[(AIListGroup *)listObject uniqueContainedObjects] objectEnumerator];
		while ((containedObject = [enumerator nextObject])) {
			[self addListObjectToList:containedObject];
		}

	} else if ([listObject isKindOfClass:[AIMetaContact class]]) {
		enumerator = [[(AIMetaContact *)listObject uniqueContainedObjects] objectEnumerator];
		while ((containedObject = [enumerator nextObject])) {
			[self addListObjectToList:containedObject];
		}

	} else if ([listObject isKindOfClass:[AIListContact class]]) {
		// if the account for this contact is connected...
		if ([(AIListContact *)listObject account].online) {
			[self addObject:(AIListContact *)listObject];
		}
	}
}

- (BOOL)tableView:(NSTableView *)tv
	   acceptDrop:(id<NSDraggingInfo>)info
			  row:(NSInteger)row
	dropOperation:(NSTableViewDropOperation)op
{
	BOOL accept = NO;

	if ([info.draggingPasteboard.types containsObject:@"AIListObjectUniqueIDs"]) {
		for (NSString *uniqueUID in [info.draggingPasteboard propertyListForType:@"AIListObjectUniqueIDs"])
			[self addListObjectToList:[adium.contactController existingListObjectWithUniqueID:uniqueUID]];
		accept = YES;
	}

	return accept;
}

@end
