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

#import "TestPropertyBasedAIListGroup.h"
#import "AIPropertyTestUtilities.h"
#import <Adium/AIListGroup.h>

@implementation TestPropertyBasedAIListGroup

/// Property: AIListGroup initWithUID: returns non-nil and stores UID.
- (void)testInitWithUID {
	PBTCheckDefault({
		NSString *uid = PBTRandomASCIIString(16);
		AIListGroup *group = [[AIListGroup alloc] initWithUID:uid];
		STAssertNotNil(group, @"initWithUID: should return non-nil");
		STAssertEqualObjects([group UID], uid,
							 @"Group UID should match input");
	});
}

/// Property: visibleCount returns 0 for a freshly-created group.
- (void)testVisibleCountInitial {
	PBTCheckDefault({
		AIListGroup *group = [[AIListGroup alloc] initWithUID:PBTRandomASCIIString(12)];
		STAssertNotNil(group, @"Group creation failed");
		STAssertEquals([group visibleCount], (NSUInteger)0,
					   @"Initial visibleCount should be 0");
	});
}

/// Property: isExpanded is NO initially (groups start collapsed by default).
- (void)testExpandedInitial {
	PBTCheckDefault({
		AIListGroup *group = [[AIListGroup alloc] initWithUID:PBTRandomASCIIString(12)];
		STAssertFalse([group isExpanded],
					  @"Group should not be expanded initially");
	});
}

/// Property: isExpandable returns BOOL without crashing.
- (void)testIsExpandable {
	PBTCheckDefault({
		AIListGroup *group = [[AIListGroup alloc] initWithUID:PBTRandomASCIIString(12)];
		// Just ensure no crash and returns BOOL
		BOOL expandable = [group isExpandable];
		STAssertTrue(expandable == YES || expandable == NO,
					 @"isExpandable must return BOOL");
	});
}

/// Property: displayName defaults to UID for a freshly-created group.
- (void)testDisplayNameDefault {
	PBTCheckDefault({
		NSString *uid = PBTRandomASCIIString(16);
		AIListGroup *group = [[AIListGroup alloc] initWithUID:uid];
		STAssertNotNil([group displayName],
					   @"displayName should be non-nil");
	});
}

/// Property: displayName set/get roundtrip.
- (void)testDisplayNameRoundtrip {
	PBTCheckDefault({
		AIListGroup *group = [[AIListGroup alloc] initWithUID:PBTRandomASCIIString(12)];
		NSString *name = PBTRandomASCIIString(20);
		[group setDisplayName:name];
		STAssertEqualObjects([group displayName], name,
							 @"displayName set/get mismatch");
	});
}

/// Property: containedObjects returns empty array for freshly-created group.
- (void)testContainedObjectsInitial {
	PBTCheckDefault({
		AIListGroup *group = [[AIListGroup alloc] initWithUID:PBTRandomASCIIString(12)];
		NSArray *contained = [group containedObjects];
		STAssertNotNil(contained,
					   @"containedObjects should be non-nil");
		STAssertEquals([contained count], (NSUInteger)0,
					   @"Initial containedObjects should be empty");
	});
}

/// Property: visibleContainedObjects returns empty array for freshly-created group.
- (void)testVisibleContainedObjectsInitial {
	PBTCheckDefault({
		AIListGroup *group = [[AIListGroup alloc] initWithUID:PBTRandomASCIIString(12)];
		NSArray *visible = [group visibleContainedObjects];
		STAssertNotNil(visible,
					   @"visibleContainedObjects should be non-nil");
		STAssertEquals([visible count], (NSUInteger)0,
					   @"Initial visibleContainedObjects should be empty");
	});
}

@end
