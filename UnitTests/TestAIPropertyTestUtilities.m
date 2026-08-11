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

#import "AIPropertyTestUtilities.h"
#import <XCTest/XCTest.h>

@interface AIPropertyTestUtilitiesTest : XCTestCase
@end

@implementation AIPropertyTestUtilitiesTest

// Property: PBTUniformUInt64(2^33) emits both even and odd values. The old composed-draws
// generator locked results to a single parity for maxes past UINT32_MAX (issue #281): the low
// draw only ever produced 0 or odd values and the high draw's lowest bit folded into the
// residue, so even results were essentially unreachable (only a zero low draw produced one,
// probability 2^-31 per draw). The fixed generator's low bits are uniform, so both parities
// appear.
- (void)testUniformGeneratorReachesBothParities
{
	PBTCheckDefault({
		uint64_t const max = ((uint64_t)UINT32_MAX << 1) + 2; /* 2^33 */
		BOOL sawEven = NO;
		BOOL sawOdd = NO;
		for (NSUInteger i = 0; i < 512; i++) {
			uint64_t value = PBTUniformUInt64(max);
			if (value % 2 == 0) {
				sawEven = YES;
			} else {
				sawOdd = YES;
			}
			if (sawEven && sawOdd) {
				break;
			}
		}
		XCTAssertTrue(sawEven, @"no even value in 512 draws of PBTUniformUInt64(2^33)");
		XCTAssertTrue(sawOdd, @"no odd value in 512 draws of PBTUniformUInt64(2^33)");
	});
}

// Property: PBTUniformUInt64(64) reaches every value in [0, 64) across enough draws — including
// 0 and max - 1, the top of the range. Locks the near-uniform coverage the rejection-sampled
// rewrite must preserve across the whole domain; the parity test above is the discriminator
// that catches a regression in the generator itself.
- (void)testUniformGeneratorCoversEveryValueInSmallDomain
{
	PBTCheckDefault({
		uint64_t const max = 64;
		BOOL seen[64] = {NO};
		for (NSUInteger i = 0; i < 64 * 64; i++) {
			seen[(NSUInteger)PBTUniformUInt64(max)] = YES;
		}
		for (uint64_t value = 0; value < max; value++) {
			XCTAssertTrue(seen[value], @"value %llu never drawn in 4096 draws of PBTUniformUInt64(64)", value);
		}
	});
}

@end
