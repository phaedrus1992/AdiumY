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

#import "AISortController.h"
#import <XCTest/XCTest.h>

/*
 * Link shim for the standalone test target. AISortController.m references AIListGroup by class name
 * (isKindOfClass: in its sorting code), which emits an _OBJC_CLASS_$ symbol no linked framework
 * provides, so it gets an empty implementation here. The shared `adium` global and the AIPlugin,
 * AIListContact classes are provided by TestESUserIconHandlingPluginObserverRemoval.m in the same
 * bundle — not redefined here.
 */
@interface AIListGroup : NSObject
@end

@implementation AIListGroup
@end

/*
 * Regression tests for the unregisterSortController: teardown API added for #204. A plugin that
 * registered sort controllers at install time must be able to drop them at uninstall time — and if
 * the controller being dropped is the active one, the active-controller slot must clear so nothing
 * later messages a deallocated controller. Each test restores the class's static registry in a
 * @finally so one failing test can't leak state into the next.
 */
@interface AISortControllerUnregisterTest : XCTestCase
@end

@implementation AISortControllerUnregisterTest

- (void)testUnregisterRemovesControllerFromAvailableSortControllers
{
	AISortController *controllerA = [[AISortController alloc] init];
	AISortController *controllerB = [[AISortController alloc] init];

	[AISortController registerSortController:controllerA];
	[AISortController registerSortController:controllerB];
	@try {
		XCTAssertEqual([[AISortController availableSortControllers] count], (NSUInteger)2,
					   @"sanity: both controllers registered");
		XCTAssertTrue([[AISortController availableSortControllers] containsObject:controllerA],
					  @"sanity: controllerA registered");
		XCTAssertTrue([[AISortController availableSortControllers] containsObject:controllerB],
					  @"sanity: controllerB registered");

		[AISortController unregisterSortController:controllerA];

		XCTAssertEqual([[AISortController availableSortControllers] count], (NSUInteger)1,
					   @"unregister removes exactly the unregistered controller");
		XCTAssertFalse([[AISortController availableSortControllers] containsObject:controllerA],
					   @"unregistered controller is gone from the list");
		XCTAssertTrue([[AISortController availableSortControllers] containsObject:controllerB],
					  @"sibling controller remains registered");
	} @finally {
		[AISortController unregisterSortController:controllerA];
		[AISortController unregisterSortController:controllerB];
	}
}

- (void)testUnregisterActiveControllerClearsActiveSortController
{
	AISortController *controller = [[AISortController alloc] init];
	AISortController *savedActive = [AISortController activeSortController];

	[AISortController registerSortController:controller];
	[AISortController setActiveSortController:controller];
	@try {
		XCTAssertEqual([AISortController activeSortController], controller,
					   @"sanity: controller is the active sort controller");

		[AISortController unregisterSortController:controller];

		XCTAssertNil([AISortController activeSortController],
					 @"unregistering the active controller clears the active slot");
	} @finally {
		[AISortController unregisterSortController:controller];
		[AISortController setActiveSortController:savedActive];
	}
}

- (void)testUnregisterNeverRegisteredControllerIsNoop
{
	AISortController *registeredController = [[AISortController alloc] init];
	AISortController *strangerController = [[AISortController alloc] init];

	[AISortController registerSortController:registeredController];
	@try {
		// Unregistering a controller this plugin never registered (and nil) must neither crash nor
		// disturb the registry of a sibling controller.
		[AISortController unregisterSortController:strangerController];
		[AISortController unregisterSortController:nil];

		XCTAssertEqual([[AISortController availableSortControllers] count], (NSUInteger)1,
					   @"unregistering a stranger or nil leaves the registry untouched");
		XCTAssertTrue([[AISortController availableSortControllers] containsObject:registeredController],
					  @"sibling controller remains registered");
	} @finally {
		[AISortController unregisterSortController:registeredController];
	}
}

@end
