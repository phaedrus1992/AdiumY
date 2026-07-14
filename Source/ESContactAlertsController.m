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

#import "ESContactAlertsController.h"
#import "AIDoNothingContactAlertPlugin.h"
#import <AIUtilities/AIImageDrawingAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <Adium/AIListObject.h>

@interface ESContactAlertsController ()
- (NSArray *)arrayOfMenuItemsForEventsWithTarget:(id)target forGlobalMenu:(BOOL)global;

- (NSMutableArray *)appendEventsForObject:(AIListObject *)listObject
								  eventID:(NSString *)eventID
								  toArray:(NSMutableArray *)events;
- (void)addMenuItemsForEventHandlers:(NSDictionary *)inEventHandlers
							 toArray:(NSMutableArray *)menuItemArray
						  withTarget:(id)target
					   forGlobalMenu:(BOOL)global;
- (void)removeAllAlertsFromListObject:(AIListObject *)listObject;
@end

@implementation ESContactAlertsController

static NSMutableDictionary *eventHandlersByGroup [adium.preferenceController delayPreferenceChangedNotifications:NO];
}

/*!
 * @brief Move all contact alerts from oldObject to newObject
 *
 * This is useful when adding oldObject to the metaContact newObject so that any existing contact alerts for oldObject
 * are applied at the contact-general level, displayed and handled properly for the new, combined contact.
 *
 * @param oldObject The object from which to move contact alerts
 * @param newObject The object to which to we want to add the moved contact alerts
 */
- (void)mergeAndMoveContactAlertsFromListObject:(AIListObject *)oldObject intoListObject:(AIListObject *)newObject
{
	NSArray *oldAlerts = [self alertsForListObject:oldObject];
	NSDictionary *alertDict;

	[adium.preferenceController delayPreferenceChangedNotifications:YES];

	// Add each alert to the target (addAlert:toListObject:setAsNewDefaults: will ensure identical alerts aren't added
	// more than once)
	for (alertDict in oldAlerts) {
		[self addAlert:alertDict toListObject:newObject setAsNewDefaults:NO];
	}

	// Remove the alerts from the originating list object
	[self removeAllAlertsFromListObject:oldObject];

	[adium.preferenceController delayPreferenceChangedNotifications:NO];
}

#pragma mark -
/*!
 * @brief Is the passed event a message event?
 *
 * Examples of messages events are "message sent" and "message received."
 *
 * @result YES if it is a message event
 */
- (BOOL)isMessageEvent:(NSString *)eventID
{
	return ([eventHandlersByGroup[AIMessageEventHandlerGroup] objectForKey:eventID] != nil ||
			([globalOnlyEventHandlersByGroup[AIMessageEventHandlerGroup] objectForKey:eventID] != nil));
}

/*!
 * @brief Is the passed event a contact status event?
 *
 * Examples of messages events are "contact signed on" and "contact went away."
 *
 * @result YES if it is a contact status event
 */
- (BOOL)isContactStatusEvent:(NSString *)eventID
{
	return ([eventHandlersByGroup[AIContactsEventHandlerGroup] objectForKey:eventID] != nil ||
			([globalOnlyEventHandlersByGroup[AIContactsEventHandlerGroup] objectForKey:eventID] != nil));
}

@end
