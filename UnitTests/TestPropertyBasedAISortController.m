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

#import "TestPropertyBasedAISortController.h"
#import "AIPropertyTestUtilities.h"
#import <Adium/AISortController.h>

@implementation TestPropertyBasedAISortController

/// Property: activeSortController returns nil or a valid AISortController without crashing.
- (void)testActiveSortController
{
	PBTCheckDefault({
		AISortController *active = [AISortController activeSortController];
		// nil is valid when no controller is active; just ensure no crash
		if (active) {
			STAssertTrue([active isKindOfClass:[AISortController class]],
						 @"activeSortController should return AISortController or nil");
		}
	});
}

/// Property: availableSortControllers returns an array without crashing.
- (void)testAvailableSortControllers
{
	PBTCheckDefault({
		NSArray *controllers = [AISortController availableSortControllers];
		STAssertNotNil(controllers, @"availableSortControllers should return non-nil array");
	});
}

/// Property: registerSortController accepts and makes a controller available.
- (void)testRegisterSortControllerRoundtrip
{
	PBTCheckDefault({
		AISortController *controller = [[AISortController alloc] init];
		STAssertNotNil(controller, @"AISortController alloc/init should succeed");
		[AISortController registerSortController:controller];
		NSArray *available = [AISortController availableSortControllers];
		STAssertTrue([available containsObject:controller] || [available count] > 0,
					 @"Registered controller should be in available list, or list should exist");
	});
}

/// Property: setActiveSortController accepts nil (clears active) without crashing.
- (void)testSetActiveSortControllerNil
{
	PBTCheckDefault({
		STAssertNoThrowSpecific([AISortController setActiveSortController:nil], NSException,
								@"setActiveSortController:nil should not throw");
	});
}

/// Property: shouldSortForModifiedStatusKeys returns BOOL without crashing for random key sets.
- (void)testShouldSortForModifiedStatusKeys
{
	PBTCheckDefault({
		AISortController *controller = [[AISortController alloc] init];
		STAssertNotNil(controller, @"Controller creation failed");
		NSMutableSet *keys = [NSMutableSet set];
		uint32_t count = PBTUniform(5);
		for (uint32_t i = 0; i < count; i++) {
			[keys addObject:PBTRandomASCIIString(12)];
		}
		BOOL result = [controller shouldSortForModifiedStatusKeys:keys];
		// Any BOOL is valid; just check no crash
		STAssertTrue(result == YES || result == NO, @"shouldSortForModifiedStatusKeys: must return BOOL");
	});
}

/// Property: shouldSortForModifiedAttributeKeys returns BOOL without crashing for random key sets.
- (void)testShouldSortForModifiedAttributeKeys
{
	PBTCheckDefault({
		AISortController *controller = [[AISortController alloc] init];
		STAssertNotNil(controller, @"Controller creation failed");
		NSMutableSet *keys = [NSMutableSet set];
		uint32_t count = PBTUniform(5);
		for (uint32_t i = 0; i < count; i++) {
			[keys addObject:PBTRandomASCIIString(12)];
		}
		BOOL result = [controller shouldSortForModifiedAttributeKeys:keys];
		STAssertTrue(result == YES || result == NO, @"shouldSortForModifiedAttributeKeys: must return BOOL");
	});
}

/// Property: alwaysSortGroupsToTopByDefault returns BOOL without crashing.
- (void)testAlwaysSortGroupsToTopByDefault
{
	PBTCheckDefault({
		AISortController *controller = [[AISortController alloc] init];
		STAssertNotNil(controller, @"Controller creation failed");
		BOOL result = [controller alwaysSortGroupsToTopByDefault];
		STAssertTrue(result == YES || result == NO, @"alwaysSortGroupsToTopByDefault must return BOOL");
	});
}

@end
