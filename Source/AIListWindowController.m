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

#import "AIListWindowController.h"

#import "AISCLViewPlugin.h"
#import <AIUtilities/AIDockingWindow.h>
#import <AIUtilities/AIEventAdditions.h>
#import <AIUtilities/AIFunctions.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIOSCompatibility.h>
#import <AIUtilities/AIOutlineViewAdditions.h>
#import <AIUtilities/AIWindowAdditions.h>
#import <AIUtilities/AIWindowControllerAdditions.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIChatControllerProtocol.h>
#import <Adium/AIContactHidingController.h>
#import <Adium/AIContactList.h>
#import <Adium/AIDockControllerProtocol.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIListBookmark.h>
#import <Adium/AIListContact.h>
#import <Adium/AIListGroup.h>
#import <Adium/AIListObject.h>
#import <Adium/AIListOutlineView.h>
#import <Adium/AIProxyListObject.h>
#import <Adium/AIUserIcons.h>

#import "AISearchFieldCell.h"

#define KEY_HIDE_CONTACT_LIST_GROUPS @"Hide Contact List Groups"

#define SLIDE_ALLOWED_RECT_EDGE_MASK (AIMinXEdgeMask | AIMaxXEdgeMask) /* Screen edges on which sliding is allowde */
#define DOCK_HIDING_MOUSE_POLL_INTERVAL 0.1f /* Interval at which to check the mouse position for sliding */
#define WINDOW_SLIDING_DELAY 0.2f /* Time after the mouse is in the right place before the window slides on screen */
#define WINDOW_ALIGNMENT_TOLERANCE 2.0f   /* Threshold distance far the window from an edge to be considered on it */
#define MOUSE_EDGE_SLIDE_ON_DISTANCE 1.1f /* ??? */
#define WINDOW_SLIDING_MOUSE_DISTANCE_TOLERANCE                                                                        \
	3.0f /* Distance the mouse must be from the window's frame to be considered outside it */

#define SNAP_DISTANCE 15.0f /* Distance beween one window's edge and another's at which they should snap together */

@interface AIListWindowController ()
- (id)initWithContactList:(id<AIContainingObject>)contactList;
+ (NSString *)nibName;
+ (void)updateScreenSlideBoundaryRect:(id)sender;
- (BOOL)shouldSlideWindowOffScreen_mousePositionStrategy;
- (void)slideWindowIfNeeded:(id)sender;
- (BOOL)shouldSlideWindowOnScreen_mousePositionStrategy;
- (void)delayWindowSlidingForInterval:(NSTimeInterval)inDelayTime;

- (void)showFilterBarWithAnimation:(BOOL)flag;
- (void)hideFilterBarWithAnimation:(BOOL)flag;
- (void)animateFilterBarWithDuration:(CGFloat)duration;

- (void)screenParametersChanged:(NSNotification *)notification;
@end

@implementation AIListWindowController

@synthesize windowAnimation, filterBarAnimation;

static NSMutableDictionary *screenSlideBoundaryRectDictionary = nil;

+ (void)initialize
{
	if (
		windowLastScreen = nil;
}
}

- (void)slideWindowOnScreen
{

	[filterBarAnimation setDuration:duration];
	[filterBarAnimation setAnimationBlockingMode:NSAnimationBlocking];
	[filterBarAnimation setDelegate:self];

	// Start the animation
	[filterBarAnimation startAnimation];
}

/*!
 * @brief Called when the window loses focus
 */
- (void)windowDidResignMain:(NSNotification *)sender
{
	/* If the filter bar was shown by type-to-find (but not by command-F), and the window is no longer main,
	 * assume the user is done and hide the filter bar.
	 */
	if (filterBarIsVisible && filterBarShownAutomatically)
		[self hideFilterBarWithAnimation:NO];
}

/*!
 * @brief Forward typing events from the contact list to the filter bar
 */
- (BOOL)forwardKeyEventToFindPanel:(NSEvent *)theEvent;
{
	if (!typeToFindEnabled)
		return NO;

	// if we were not searching something before, we need to show the filter bar first without animation
	NSString *charString = [theEvent charactersIgnoringModifiers];
	unichar pressedChar = 0;

	// Get the pressed character
	if ([charString length] == 1)
		pressedChar = [charString characterAtIndex:0];

#define NSEscapeFunctionKey 27
	/* Hitting escape once should clear any existing selection. Keys with functional modifiers pressed should not be
	 * passed. Home and End should be passed to the find panel only  if it is already visible.
	 */
	if (((pressedChar == NSEscapeFunctionKey) && ([contactListView selectedRow] != -1 || !filterBarIsVisible)) ||
		(([theEvent modifierFlags] & NSCommandKeyMask) || ([theEvent modifierFlags] & NSAlternateKeyMask) ||
		 ([theEvent modifierFlags] & NSControlKeyMask)) ||
		((pressedChar == NSPageUpFunctionKey) || (pressedChar == NSPageDownFunctionKey) ||
		 (pressedChar == NSMenuFunctionKey)) ||
		(!filterBarIsVisible && ((pressedChar == NSHomeFunctionKey) || (pressedChar == NSEndFunctionKey)))) {
		return NO;

	} else {
		if (!filterBarIsVisible) {
			[self toggleFindPanel:nil];
			filterBarShownAutomatically = YES;
		}

		[[self window] makeFirstResponder:searchField];
		[[[self window] fieldEditor:YES forObject:searchField] keyDown:theEvent];

		return YES;
	}
}

/*!
 * @brief Process text commands while on the search field
 */
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	// Only process commands when we're in the search field.
	if (control != searchField)
		return NO;

	if (command == @selector(insertNewline:)) {
		// If we have a search term, open a chat with the first contact
		if (![[textView string] isEqualToString:@""])
			[self performDefaultActionOnSelectedObject:[contactListView firstVisibleListContact]
												sender:contactListView];
		// Hide the filter bar
		[self hideFilterBarWithAnimation:YES];
	} else if (command == @selector(moveDown:)) {
		// The down arrow functions to move into the contact list view
		[[self window] makeFirstResponder:contactListView];
	} else if (command == @selector(cancelOperation:)) {
		// Escape hides the filter bar.
		[self hideFilterBarWithAnimation:YES];
	} else {
		// If we didn't process a command, return NO.
		return NO;
	}

	// We processed a command, return YES.
	return YES;
}

/*!
 * @brief Filter contacts from the search field
 *
 * This method will expand or contract groups as necessary, as well as handle forwarding the search term to
 * the contact hiding controller.
 */
- (IBAction)filterContacts:(id)sender;
{
	if (![sender isKindOfClass:[NSSearchField class]])
		return;

	if (!filterBarExpandedGroups && ![[sender stringValue] isEqualToString:@""]) {
		BOOL modified = NO;
		for (AIListObject *listObject in [self.contactList containedObjects]) {
			if ([listObject isKindOfClass:[AIListGroup class]] && [(AIListGroup *)listObject isExpanded] == NO) {
				[listObject setValue:[NSNumber numberWithBool:YES]
						 forProperty:@"ExpandedByFiltering"
							  notify:NotifyNever];
				modified = YES;
			}
		}

		filterBarExpandedGroups = YES;

		if (modified) {
			[contactListView reloadData];
		}
	} else if (filterBarExpandedGroups && [[sender stringValue] isEqualToString:@""]) {
		BOOL modified = NO;
		for (AIListObject *listObject in [self.contactList containedObjects]) {
			if ([listObject isKindOfClass:[AIListGroup class]] &&
				[listObject boolValueForProperty:@"ExpandedByFiltering"]) {
				[listObject setValue:[NSNumber numberWithBool:NO]
						 forProperty:@"ExpandedByFiltering"
							  notify:NotifyNever];
				modified = YES;
			}
		}

		filterBarExpandedGroups = NO;

		if (modified) {
			[contactListView reloadData];
		}
	}

	if ([[AIContactHidingController sharedController] filterContacts:[sender stringValue]]) {
		// Select the first contact; we're guaranteed at least one visible contact.
		[contactListView
				selectRowIndexes:[NSIndexSet indexSetWithIndex:[contactListView indexOfFirstVisibleListContact]]
			byExtendingSelection:NO];

		// Since this wasn't a user-initiated selection change, we need to post a notification for it.
		[[NSNotificationCenter defaultCenter] postNotificationName:Interface_ContactSelectionChanged object:nil];

		[[searchField cell] setTextColor:nil backgroundColor:nil];

	} else {
		// White on light red (like Firefox!)
		[[searchField cell] setTextColor:[NSColor whiteColor]
						 backgroundColor:[NSColor colorWithCalibratedHue:0.983f
															  saturation:0.43f
															  brightness:0.99f
																   alpha:1.0f]];
	}
}

/*!
 * @brief Delegate method for the search field's close button
 */
- (void)rolloverButton:(AIRolloverButton *)inButton mouseChangedToInsideButton:(BOOL)isInside
{
	[button_cancelFilterBar
		setImage:[NSImage imageNamed:(isInside ? @"FTProgressStopRollover" : @"FTProgressStop") forClass:[self class]]];
}

@end
