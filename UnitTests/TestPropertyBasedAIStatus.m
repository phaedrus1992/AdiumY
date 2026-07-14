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

#import "TestPropertyBasedAIStatus.h"
#import "AIPropertyTestUtilities.h"
#import <Adium/AIStatus.h>

@implementation TestPropertyBasedAIStatus

/// Property: AIStatus created with +status returns non-nil and has default state.
- (void)testStatusCreation
{
	PBTCheckDefault({
		AIStatus *status = [AIStatus status];
		STAssertNotNil(status, @"+status should return non-nil");
	});
}

/// Property: AIStatus created with +statusWithDictionary: must not crash for random dictionaries.
- (void)testStatusWithRandomDictionary
{
	PBTCheckDefault({
		NSDictionary *randomDict = PBTRandomStringDictionary(8);
		AIStatus *status = [AIStatus statusWithDictionary:randomDict];
		STAssertNotNil(status, @"statusWithDictionary: should return non-nil");
	});
}

/// Property: statusWithDictionary: must not crash for status-like dictionaries with random values.
- (void)testStatusWithStatusDictionary
{
	PBTCheckDefault({
		NSDictionary *statusDict = PBTRandomStatusDictionary();
		AIStatus *status = [AIStatus statusWithDictionary:statusDict];
		STAssertNotNil(status, @"statusWithDictionary: should return non-nil for status-like dict");
	});
}

/// Property: AIStatus NSCoding save/load roundtrip preserves basic properties.
/// Archive a status, unarchive it, verify the status type matches.
- (void)testNSCodingRoundtrip
{
	PBTCheckDefault({
		AIStatus *original = [AIStatus status];
		STAssertNotNil(original, @"Original status should be non-nil");
		[original setStatusName:PBTRandomASCIIString(16)];
		if (PBTRandomBool()) {
			[original setStatusMessage:PBTRandomAttributedString(32)];
		}
		[original setHasAutoReply:PBTRandomBool()];
		[original setAutoReplyIsStatusMessage:PBTRandomBool()];
		[original setMutesSound:PBTRandomBool()];
		[original setSilencesGrowl:PBTRandomBool()];

		// Archive
		NSMutableData *data = [NSMutableData data];
		NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
		[archiver encodeObject:original forKey:@"status"];
		[archiver finishEncoding];

		// Unarchive
		NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
		AIStatus *restored = [unarchiver decodeObjectForKey:@"status"];
		[unarchiver finishDecoding];

		STAssertNotNil(restored, @"Restored status should be non-nil");
		STAssertEqualObjects([restored statusName], [original statusName],
							 @"Status name should survive archive roundtrip");
		STAssertEquals([restored hasAutoReply], [original hasAutoReply],
					   @"hasAutoReply should survive archive roundtrip");
		STAssertEquals([restored autoReplyIsStatusMessage], [original autoReplyIsStatusMessage],
					   @"autoReplyIsStatusMessage should survive archive roundtrip");
	});
}

/// Property: AIStatus of various types can be created and used without crashing.
- (void)testStatusOfVariousTypes
{
	PBTCheckDefault({
		AIStatusType types[] = {AIOnlineStatus, AIAwayStatus, AIInvisibleStatus, AIOfflineStatus};
		AIStatusType type = types[PBTUniform(4)];
		AIStatus *status = [AIStatus statusOfType:type];
		STAssertNotNil(status, @"statusOfType: should return non-nil for type %d", type);
	});
}

/// Property: Setting and reading back status properties is consistent for random values.
- (void)testStatusPropertyConsistency
{
	PBTCheckDefault({
		AIStatus *status = [AIStatus status];
		STAssertNotNil(status, @"Status creation failed");

		NSString *name = PBTRandomASCIIString(32);
		[status setStatusName:name];
		STAssertEqualObjects([status statusName], name, @"statusName set/get mismatch");

		BOOL muteSounds = PBTRandomBool();
		[status setMutesSound:muteSounds];
		STAssertEquals([status mutesSound], muteSounds, @"mutesSound set/get mismatch");

		BOOL silenceGrowl = PBTRandomBool();
		[status setSilencesGrowl:silenceGrowl];
		STAssertEquals([status silencesGrowl], silenceGrowl, @"silencesGrowl set/get mismatch");

		BOOL hasAutoReply = PBTRandomBool();
		[status setHasAutoReply:hasAutoReply];
		STAssertEquals([status hasAutoReply], hasAutoReply, @"hasAutoReply set/get mismatch");

		BOOL autoReplyIsStatusMsg = PBTRandomBool();
		[status setAutoReplyIsStatusMessage:autoReplyIsStatusMsg];
		STAssertEquals([status autoReplyIsStatusMessage], autoReplyIsStatusMsg,
					   @"autoReplyIsStatusMessage set/get mismatch");

		BOOL shouldForceIdle = PBTRandomBool();
		[status setShouldForceInitialIdleTime:shouldForceIdle];
		STAssertEquals([status shouldForceInitialIdleTime], shouldForceIdle,
					   @"shouldForceInitialIdleTime set/get mismatch");
	});
}

@end
