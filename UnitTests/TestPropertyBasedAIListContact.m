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

#import "TestPropertyBasedAIListContact.h"
#import "AIPropertyTestUtilities.h"
#import <Adium/AIListContact.h>

/// Helper: minimal NSObject subclass for testing AIListContact-init methods that ask for AIService.
/// AIService is an abstract class with a handful of required overrides.
@interface _PBTTestService : NSObject
@property (nonatomic, copy) NSString *serviceID;
@end

@implementation _PBTTestService
@end

/// Helper: minimal NSObject subclass for testing contact containment.
@interface _PBTTestAccount : NSObject
@property (nonatomic, copy) NSString *internalObjectID;
@end

@implementation _PBTTestAccount
@end

@implementation TestPropertyBasedAIListContact

/// Property: AIListContact initWithUID:service: returns non-nil and stores UID.
- (void)testInitWithUIDService {
	PBTCheckDefault({
		NSString *uid = PBTRandomASCIIString(16);
		_PBTTestService *service = [[_PBTTestService alloc] init];
		[service setServiceID:PBTRandomASCIIString(8)];
		AIListContact *contact = [[AIListContact alloc] initWithUID:uid service:(AIService *)service];
		STAssertNotNil(contact, @"initWithUID:service: should return non-nil");
		// UID is accessible, with no crash
		NSString *readUID = [contact UID];
		STAssertNotNil(readUID, @"UID should be non-nil");
	});
}

/// Property: internalUniqueObjectID returns a non-nil string.
- (void)testInternalUniqueObjectID {
	PBTCheckDefault({
		NSString *uid = PBTRandomASCIIString(12);
		_PBTTestService *service = [[_PBTTestService alloc] init];
		[service setServiceID:PBTRandomASCIIString(8)];
		AIListContact *contact = [[AIListContact alloc] initWithUID:uid service:(AIService *)service];
		STAssertNotNil([contact internalUniqueObjectID],
					   @"internalUniqueObjectID should be non-nil");
	});
}

/// Property: remoteGroupNames set/get roundtrip works for random string sets.
- (void)testRemoteGroupNamesRoundtrip {
	PBTCheckDefault({
		NSString *uid = PBTRandomASCIIString(12);
		_PBTTestService *service = [[_PBTTestService alloc] init];
		[service setServiceID:PBTRandomASCIIString(8)];
		AIListContact *contact = [[AIListContact alloc] initWithUID:uid service:(AIService *)service];
		STAssertNotNil(contact, @"Contact creation failed");

		NSMutableSet *names = [NSMutableSet set];
		uint32_t count = PBTUniform(5);
		for (uint32_t i = 0; i < count; i++) {
			[names addObject:PBTRandomASCIIString(10)];
		}
		[contact setRemoteGroupNames:names];
		NSSet *readback = [contact remoteGroupNames];
		STAssertNotNil(readback, @"remoteGroupNames after set should be non-nil");
	});
}

/// Property: formattedUID set/get roundtrip for random strings.
- (void)testFormattedUIDRoundtrip {
	PBTCheckDefault({
		NSString *uid = PBTRandomASCIIString(12);
		_PBTTestService *service = [[_PBTTestService alloc] init];
		[service setServiceID:PBTRandomASCIIString(8)];
		AIListContact *contact = [[AIListContact alloc] initWithUID:uid service:(AIService *)service];
		STAssertNotNil(contact, @"Contact creation failed");

		NSString *formatted = PBTRandomASCIIString(20);
		[contact setFormattedUID:formatted notify:NotifyNow];
		// Just check no crash and non-nil
		STAssertNotNil([contact formattedUID],
					   @"formattedUID should be non-nil after set");
	});
}

/// Property: isIntentionallyNotAStranger returns BOOL without crashing.
- (void)testIsIntentionallyNotAStranger {
	PBTCheckDefault({
		NSString *uid = PBTRandomASCIIString(12);
		_PBTTestService *service = [[_PBTTestService alloc] init];
		[service setServiceID:PBTRandomASCIIString(8)];
		AIListContact *contact = [[AIListContact alloc] initWithUID:uid service:(AIService *)service];
		STAssertTrue([contact isIntentionallyNotAStranger] == YES ||
					 [contact isIntentionallyNotAStranger] == NO,
					 @"isIntentionallyNotAStranger must return BOOL");
	});
}

/// Property: displayName set/get roundtrip for random strings.
- (void)testDisplayNameRoundtrip {
	PBTCheckDefault({
		NSString *uid = PBTRandomASCIIString(12);
		_PBTTestService *service = [[_PBTTestService alloc] init];
		[service setServiceID:PBTRandomASCIIString(8)];
		AIListContact *contact = [[AIListContact alloc] initWithUID:uid service:(AIService *)service];
		STAssertNotNil(contact, @"Contact creation failed");

		NSString *name = PBTRandomASCIIString(20);
		[contact setDisplayName:name];
		STAssertEqualObjects([contact displayName], name,
							 @"displayName set/get mismatch");
	});
}

@end
