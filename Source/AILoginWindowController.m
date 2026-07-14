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

#import "AILoginWindowController.h"
#import <AIUtilities/AIDictionaryAdditions.h>
#import <Adium/AILoginControllerProtocol.h>

// Preference Keys
#define NEW_USER_NAME @"New User"       // Default name of a new user
#define LOGIN_WINDOW_NIB @"LoginSelect" // Filename of the login window nib

#define LOGIN_TIMEOUT 10.0

@interface AILoginWindowController ()
- (id)initWithOwner:(id)inOwner windowNibName:(NSString *)windowNibName;
- (void)dealloc;
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
- (IBAction)login:(id)sender;
- (IBAction)editUsers:(id)sender;
- (IBAction)doneEditing:(id)sender;
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)updateUserList;
- (IBAction)newUser:(id)sender;
- (void)tableView:(NSTableView *)tableView
	setObjectValue:(id)object
	forTableColumn:(NSTableColumn *)tableColumn
			   row:(NSInteger)row;
- (IBAction)deleteUser:(id)sender;
- (void)windowDidLoad;
- (void)disableLoginTimeout;
@end

@implementation AILoginWindowController
// return an instance of AILoginController
+ (AILoginWindowController *)loginWindowControllerWithOwner:(id)inOwner
{
	/* Release self in windowWillClose: */
	return loginTimer = nil;
}
}

@end
