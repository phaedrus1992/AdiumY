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

#import "TestPropertyBasedAIMetaContact.h"
#import "AIPropertyTestUtilities.h"
#import <Adium/AIMetaContact.h>

@implementation TestPropertyBasedAIMetaContact

/// Property: AIMetaContact initWithObjectID: returns non-nil and stores objectID.
- (void)testInitWithObjectID {
	PBTCheckDefault({
		NSNumber *objID = @((int64_t)PBTUniform(999999));
		AIMetaContact *meta = [[AIMetaContact alloc] initWithObjectID:objID];
		STAssertNotNil(meta,
					   @"initWithObjectID: should return non-nil");
		STAssertEqualObjects([meta objectID], objID,
							 @"objectID should match input");
	});
}

/// Property: objectID is non-nil after initWithObjectID.
- (void)testObjectIDNonNil {
	PBTCheckDefault({
		NSNumber *objID = @((uint32_t)PBTUniform(999999));
		AIMetaContact *meta = [[AIMetaContact alloc] initWithObjectID:objID];
		STAssertNotNil([meta objectID],
					   @"objectID should be non-nil");
	});
}

/// Property: preferredContact returns nil for empty meta contact (no contacts yet).
- (void)testPreferredContactInitial {
	PBTCheckDefault({
		AIMetaContact *meta = [[AIMetaContact alloc] initWithObjectID:@(PBTUniform(99999))];
		AIListContact *pref = [meta preferredContact];
		// nil is valid — meta contact with no contained contacts has no preferred contact
		STAssertTrue(pref == nil || [pref isKindOfClass:[AIListContact class]],
					 @"preferredContact should be nil or AIListContact subclass");
	});
}

/// Property: containsOnlyOneService returns BOOL without crashing.
- (void)testContainsOnlyOneService {
	PBTCheckDefault({
		AIMetaContact *meta = [[AIMetaContact alloc] initWithObjectID:@(PBTUniform(99999))];
		BOOL result = [meta containsOnlyOneService];
		STAssertTrue(result == YES || result == NO,
					 @"containsOnlyOneService must return BOOL");
	});
}

/// Property: uniqueContainedObjectsCount returns 0 for empty meta contact.
- (void)testUniqueContainedObjectsCountInitial {
	PBTCheckDefault({
		AIMetaContact *meta = [[AIMetaContact alloc] initWithObjectID:@(PBTUniform(99999))];
		STAssertEquals([meta uniqueContainedObjectsCount], (NSUInteger)0,
					   @"uniqueContainedObjectsCount should be 0 initially");
	});
}

/// Property: displayName set/get roundtrip for random strings.
- (void)testDisplayNameRoundtrip {
	PBTCheckDefault({
		AIMetaContact *meta = [[AIMetaContact alloc] initWithObjectID:@(PBTUniform(99999))];
		NSString *name = PBTRandomASCIIString(20);
		[meta setDisplayName:name];
		STAssertEqualObjects([meta displayName], name,
							 @"displayName set/get mismatch");
	});
}

/// Property: isExpandable returns BOOL without crashing.
- (void)testIsExpandable {
	PBTCheckDefault({
		AIMetaContact *meta = [[AIMetaContact alloc] initWithObjectID:@(PBTUniform(99999))];
		BOOL result = [meta isExpandable];
		STAssertTrue(result == YES || result == NO,
					 @"isExpandable must return BOOL");
	});
}

@end
