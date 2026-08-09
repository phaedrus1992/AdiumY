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

/*
 * The real @implementation for AdiumServices is wired into this bundle; the relaxed @interface
 * declares only the surface these tests need. The registry keeps services keyed by serviceCodeUniqueID;
 * registerService: (the sibling of the new unregisterService:) is covered so the unregister assertions
 * start from known state.
 */
@interface AdiumServices : NSObject
- (void)registerService:(id)inService;
- (void)unregisterService:(id)inService;
- (NSArray *)services;
- (id)serviceWithUniqueID:(NSString *)uniqueID;
@end

/*
 * Bare @interface only — the real AIService.m is wired into this bundle (it provides the class
 * symbol plus +registerService/-init/-unregisterService), so declaring the class here satisfies
 * the TestAdiumService subclass reference without emitting a second _OBJC_CLASS_ definition.
 */
@interface AIService : NSObject
@end

/*
 * A minimal service for exercising the registry: it needs nothing but a stable serviceCodeUniqueID.
 */
@interface TestAdiumService : AIService {
	NSString *_serviceCodeUniqueID;
}

- (instancetype)initWithUniqueID:(NSString *)uniqueID;
- (NSString *)serviceCodeUniqueID;

@end

@implementation TestAdiumService

- (instancetype)initWithUniqueID:(NSString *)uniqueID
{
	if ((self = [super init])) {
		_serviceCodeUniqueID = [uniqueID copy];
	}
	return self;
}

- (NSString *)serviceCodeUniqueID
{
	return _serviceCodeUniqueID;
}

@end

@interface AdiumServicesUnregisterTest : XCTestCase
@end

@implementation AdiumServicesUnregisterTest

// registerService: adds a service to the registry, retrievable by unique ID. Baseline for the
// unregister assertions.
- (void)testRegisterAddsServiceRetrievableByUniqueID
{
	AdiumServices *registry = [[AdiumServices alloc] init];
	TestAdiumService *service = [[TestAdiumService alloc] initWithUniqueID:@"test-uid"];

	@try {
		XCTAssertEqual([[registry services] count], (NSUInteger)0, @"sanity: registry starts empty");

		[registry registerService:service];

		XCTAssertEqual([[registry services] count], (NSUInteger)1, @"registerService adds the service");
		XCTAssertEqual([registry serviceWithUniqueID:@"test-uid"], service,
					   @"registered service is retrievable by its unique ID");
	} @finally {
		[registry unregisterService:service];
	}
}

// unregisterService: removes exactly the named service; a sibling service stays registered.
- (void)testUnregisterRemovesExactlyTheNamedService
{
	AdiumServices *registry = [[AdiumServices alloc] init];
	TestAdiumService *serviceA = [[TestAdiumService alloc] initWithUniqueID:@"test-uid-a"];
	TestAdiumService *serviceB = [[TestAdiumService alloc] initWithUniqueID:@"test-uid-b"];

	[registry registerService:serviceA];
	[registry registerService:serviceB];
	@try {
		XCTAssertEqual([[registry services] count], (NSUInteger)2, @"sanity: both services registered");

		[registry unregisterService:serviceA];

		XCTAssertEqual([[registry services] count], (NSUInteger)1,
					   @"unregister removes exactly the unregistered service");
		XCTAssertNil([registry serviceWithUniqueID:@"test-uid-a"], @"unregistered service is gone from the registry");
		XCTAssertEqual([registry serviceWithUniqueID:@"test-uid-b"], serviceB, @"sibling service remains registered");
	} @finally {
		[registry unregisterService:serviceA];
		[registry unregisterService:serviceB];
	}
}

// The plugin unload path must tolerate a nil service (already unregistered / never registered):
// removeObjectForKey:nil raises NSInvalidArgumentException, so unregisterService: must guard.
- (void)testUnregisterNilIsNoop
{
	AdiumServices *registry = [[AdiumServices alloc] init];
	TestAdiumService *service = [[TestAdiumService alloc] initWithUniqueID:@"test-uid"];

	[registry registerService:service];
	@try {
		[registry unregisterService:nil];

		XCTAssertEqual([[registry services] count], (NSUInteger)1,
					   @"unregisterService:nil must neither crash nor disturb the registry");
		XCTAssertEqual([registry serviceWithUniqueID:@"test-uid"], service,
					   @"registered service remains intact after unregisterService:nil");
	} @finally {
		[registry unregisterService:service];
	}
}

@end
