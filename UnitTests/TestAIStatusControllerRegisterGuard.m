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

// clang-format off
#import <AdiumY/AIStatusController.h>
#import <AdiumY/AIStatusDefines.h>
#import <AdiumY/AIService.h>
// clang-format on

/*
 * A minimal concrete service for the valid-range path. registerStatus:withDescription:ofType:forService:
 * only reads serviceCodeUniqueID, so a bare AIService subclass suffices; AIService.m is compiled into
 * this bundle by the harness. Named uniquely per bundle (TestStatusService is defined by
 * TestAIServiceUnregister.m in the same bundle).
 */
@interface RegisterGuardMockService : AIService
@end

@implementation RegisterGuardMockService

- (NSString *)serviceCodeUniqueID
{
	return @"test-service-245";
}

@end

/*
 * #245: registerStatus:withDescription:ofType:forService: indexes statusDictsByServiceCodeUniqueID — a
 * C array of STATUS_TYPES_COUNT pointers — by the caller-supplied status type. A plugin passing an
 * out-of-range type writes past the array. The method must NSParameterAssert the bounds before the
 * write. Asserts are enabled in the Debug configuration this bundle builds under (CI runs Debug).
 */
@interface AIStatusControllerRegisterGuardTest : XCTestCase
@end

@implementation AIStatusControllerRegisterGuardTest

- (void)testRegisterStatusTypeAtUpperBoundRaises
{
	AIStatusController *controller = [[AIStatusController alloc] init];

	XCTAssertThrowsSpecific([controller registerStatus:@"away-245"
									   withDescription:@"Unique Test Status - 245"
												ofType:(AIStatusType)STATUS_TYPES_COUNT
											forService:[[RegisterGuardMockService alloc] init]],
							NSException, @"registering a status with type == STATUS_TYPES_COUNT must raise");
}

- (void)testRegisterStatusNegativeTypeRaises
{
	AIStatusController *controller = [[AIStatusController alloc] init];

	XCTAssertThrowsSpecific([controller registerStatus:@"away-245"
									   withDescription:@"Unique Test Status - 245"
												ofType:(AIStatusType)-1
											forService:[[RegisterGuardMockService alloc] init]],
							NSException, @"registering a status with a negative type must raise");
}

- (void)testRegisterStatusAllValidTypesDoNotRaise
{
	AIStatusController *controller = [[AIStatusController alloc] init];
	RegisterGuardMockService *service = [[RegisterGuardMockService alloc] init];

	for (AIStatusType type = AIAvailableStatusType; type < STATUS_TYPES_COUNT; type++) {
		XCTAssertNoThrow([controller registerStatus:@"away-245"
									withDescription:@"Unique Test Status - 245"
											 ofType:type
										 forService:service],
						 @"registering a status with type %d must not raise", type);
	}
}

@end
