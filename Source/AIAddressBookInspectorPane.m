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

#import "AIAddressBookInspectorPane.h"
#import <AIUtilities/AIDelayedTextField.h>
#import <AIUtilities/AIStringAdditions.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIListContact.h>
#import <Adium/AIListObject.h>

#define ADDRESS_BOOK_NIB_NAME (@"AIAddressBookInspectorPane")

@interface AIAddressBookInspectorPane ()
- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
@end

@implementation AIAddressBookInspectorPane

- (id)init
{
	if ((self = 
	displayedObject =
		([inObject isKindOfClass:[AIListContact class]] ? [(AIListContact *)inObject parentContact] : inObject);
	displayedObject;

	// Current note
	if ((currentNotes = [displayedObject notes])) {
		[contactNotes setStringValue:currentNotes];
	} else {
		[contactNotes setStringValue:@""];
	}
}

- (IBAction)setNotes:(id)sender
{
	if (!displayedObject)
		return;

	NSString *currentNote = [contactNotes stringValue];
	[displayedObject setNotes:currentNote];
}

// Address Book Panel methods.
- (IBAction)runABPanel:(id)sender
{
	[NSApp beginSheet:addressBookPanel
		modalForWindow:[inspectorContentView window]
		 modalDelegate:self
		didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
		   contextInfo:nil];
}

- (IBAction)cardSelected:(id)sender
{
	// This method will be different during Adium integration, until then we simply print out some details about the
	// ABPerson that has been selected. Pretty simple.
	NSArray *selectedCards = [addressBookPicker selectedRecords];

	if ([selectedCards count]) {
		[(AIListContact *)displayedObject setAddressBookPerson:[selectedCards objectAtIndex:0]];
	}

	[NSApp endSheet:addressBookPanel];
}

- (IBAction)cancelABPanel:(id)sender
{
	// This method simply ends the panel when the user clicks cancel.
	[NSApp endSheet:addressBookPanel];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[addressBookPanel orderOut:self];
}

@end
