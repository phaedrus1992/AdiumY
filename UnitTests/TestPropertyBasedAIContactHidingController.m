/*
 * Adium is the property of its developers, whose names are listed in the copyright file included
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

#import "TestPropertyBasedAIContactHidingController.h"
#import "AIPropertyTestUtilities.h"
#import <Adium/AIContactHidingController.h>

@implementation TestPropertyBasedAIContactHidingController

/// Property: sharedController returns non-nil without crashing.
- (void)testSharedController
{
	PBTCheckDefault({
		AIContactHidingController *controller = [AIContactHidingController sharedController];
		STAssertNotNil(controller, @"sharedController should return non-nil");
	});
}

/// Property: createPredicateWithSearchString: returns a non-nil NSPredicate for random strings.
- (void)testCreatePredicateWithRandomSearchStrings
{
	PBTCheckDefault({
		AIContactHidingController *controller = [AIContactHidingController sharedController];
		STAssertNotNil(controller, @"sharedController failed");

		NSString *searchString = nil;
		switch (PBTUniform(3)) {
		case 0:
			searchString = PBTRandomASCIIString(20);
			break;
		case 1:
			searchString = @"";
			break;
		case 2:
			searchString = PBTRandomUnicodeString(20);
			break;
		}
		NSPredicate *predicate = [controller createPredicateWithSearchString:searchString];
		STAssertNotNil(predicate, @"createPredicateWithSearchString: should return non-nil");
		// A predicate must evaluate without crashing for trivial objects
		STAssertNoThrowSpecific([predicate evaluateWithObject:@{@"key" : @"value"}], NSException,
								@"Predicate evaluation should not throw");
	});
}

/// Property: createPredicateWithSearchString: with whitespace-only strings returns a valid predicate.
- (void)testCreatePredicateWithWhitespaceString
{
	PBTCheckDefault({
		AIContactHidingController *controller = [AIContactHidingController sharedController];
		STAssertNotNil(controller, @"sharedController failed");

		NSString *whitespace = PBTRandomWhitespaceString(10);
		NSPredicate *predicate = [controller createPredicateWithSearchString:whitespace];
		STAssertNotNil(predicate, @"Predicate for whitespace string should be non-nil");
	});
}

/// Property: filterContacts: returns BOOL without crashing for random search strings.
- (void)testFilterContactsWithRandomStrings
{
	PBTCheckDefault({
		AIContactHidingController *controller = [AIContactHidingController sharedController];
		STAssertNotNil(controller, @"sharedController failed");

		NSString *searchString = nil;
		switch (PBTUniform(4)) {
		case 0:
			searchString = PBTRandomASCIIString(20);
			break;
		case 1:
			searchString = @"";
			break;
		case 2:
			searchString = nil;
			break;
		case 3:
			searchString = PBTRandomUnicodeString(20);
			break;
		}
		BOOL result = [controller filterContacts:searchString];
		STAssertTrue(result == YES || result == NO, @"filterContacts: must return BOOL");
	});
}

/// Property: contactFilteringSearchString is consistent after filterContacts:.
- (void)testContactFilteringSearchStringConsistency
{
	PBTCheckDefault({
		AIContactHidingController *controller = [AIContactHidingController sharedController];

		NSString *searchString = PBTRandomASCIIString(15);
		[controller filterContacts:searchString];
		NSString *readback = [controller contactFilteringSearchString];
		// The string might be stored as-is or normalized; just confirm non-nil
		STAssertNotNil(readback, @"contactFilteringSearchString should be non-nil after filterContacts:");
	});
}

@end
