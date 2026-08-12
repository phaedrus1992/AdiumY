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

#import <XCTest/XCTest.h>

#import "ESContactAlertsController.h"
// clang-format off
#import <AdiumY/AIContactAlertsControllerProtocol.h>
// clang-format on

/*
 * Minimal AIEventHandler conformance for the registration path. registerEventID:withHandler:inGroup:
 * globalOnly: only stores the handler; none of these methods is invoked by the code under test.
 */
@interface RegisterGuardMockEventHandler : NSObject <AIEventHandler>
@end

@implementation RegisterGuardMockEventHandler

- (NSString *)shortDescriptionForEventID:(NSString *)eventID
{
	return @"short";
}

- (NSString *)globalShortDescriptionForEventID:(NSString *)eventID
{
	return @"short";
}

- (NSString *)englishGlobalShortDescriptionForEventID:(NSString *)eventID
{
	return @"short";
}

- (NSString *)longDescriptionForEventID:(NSString *)eventID forListObject:(AIListObject *)listObject
{
	return @"long";
}

- (NSString *)naturalLanguageDescriptionForEventID:(NSString *)eventID
										listObject:(AIListObject *)listObject
										  userInfo:(id)userInfo
									includeSubject:(BOOL)includeSubject
{
	return @"natural";
}

- (NSImage *)imageForEventID:(NSString *)eventID
{
	return nil;
}

- (NSString *)descriptionForCombinedEventID:(NSString *)eventID
							  forListObject:(AIListObject *)listObject
									forChat:(AIChat *)chat
								  withCount:(NSUInteger)count
{
	return @"combined";
}

@end

/*
 * #245: registerEventID:withHandler:inGroup:globalOnly: indexes eventHandlersByGroup and
 * globalOnlyEventHandlersByGroup — C arrays of EVENT_HANDLER_GROUP_COUNT pointers — by the
 * caller-supplied group. An out-of-range group writes past the arrays. The method must
 * NSParameterAssert the bounds before either write.
 */
@interface ESContactAlertsControllerRegisterGuardTest : XCTestCase
@end

@implementation ESContactAlertsControllerRegisterGuardTest

- (void)testRegisterEventGroupAtUpperBoundRaises
{
	ESContactAlertsController *controller = [[ESContactAlertsController alloc] init];
	RegisterGuardMockEventHandler *handler = [[RegisterGuardMockEventHandler alloc] init];

	XCTAssertThrowsSpecific([controller registerEventID:@"test-event-245"
											withHandler:handler
												inGroup:(AIEventHandlerGroupType)(AIOtherEventHandlerGroup + 1)
											 globalOnly:YES],
							NSException, @"registering an event with group one past the last valid group must raise");
}

- (void)testRegisterEventNegativeGroupRaises
{
	ESContactAlertsController *controller = [[ESContactAlertsController alloc] init];
	RegisterGuardMockEventHandler *handler = [[RegisterGuardMockEventHandler alloc] init];

	XCTAssertThrowsSpecific([controller registerEventID:@"test-event-245"
											withHandler:handler
												inGroup:(AIEventHandlerGroupType)-1
											 globalOnly:NO],
							NSException, @"registering an event with a negative group must raise");
}

- (void)testRegisterEventAllValidGroupsDoNotRaise
{
	ESContactAlertsController *controller = [[ESContactAlertsController alloc] init];
	RegisterGuardMockEventHandler *handler = [[RegisterGuardMockEventHandler alloc] init];

	for (AIEventHandlerGroupType group = AIContactsEventHandlerGroup; group <= AIOtherEventHandlerGroup; group++) {
		XCTAssertNoThrow([controller registerEventID:@"test-event-245"
										 withHandler:handler
											 inGroup:group
										  globalOnly:YES],
						 @"registering an event with group %d (global-only) must not raise", group);
		XCTAssertNoThrow([controller registerEventID:@"test-event-245" withHandler:handler inGroup:group globalOnly:NO],
						 @"registering an event with group %d (contact) must not raise", group);
	}
}

@end
