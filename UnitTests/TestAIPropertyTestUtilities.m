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

// Property: PBTUniformUInt64 stays in [0, max) for the maxes that force the rejection-sampling
// redraw path — the values past UINT32_MAX the parity test above can't reach (issue #281). For
// 2^62, 2^63, and 2^63+1 a quarter to half of all draws fall in the partial top block and are
// redrawn, so the redraw loop runs thousands of times per 4096-draw sweep; UINT64_MAX and
// UINT64_MAX-1 pin the limit arithmetic at the top of the range (only 1-2 values are rejected,
// but the modulo boundary must still hold). Both parities must appear — the discriminator that
// catches a redraw biased toward one residue class.
- (void)testUniformGeneratorRedrawsForLargeMaxes
{
	uint64_t const maxes[] = {
		(uint64_t)1 << 62,
		(uint64_t)1 << 63,
		((uint64_t)1 << 63) + 1,
		UINT64_MAX,
		UINT64_MAX - 1,
	};

	for (size_t m = 0; m < sizeof(maxes) / sizeof(maxes[0]); m++) {
		uint64_t const max = maxes[m];
		BOOL sawEven = NO;
		BOOL sawOdd = NO;
		for (NSUInteger i = 0; i < 4096; i++) {
			uint64_t value = PBTUniformUInt64(max);
			XCTAssertLessThan(value, max, @"PBTUniformUInt64(%llu) drew %llu", max, value);
			if (value % 2 == 0) {
				sawEven = YES;
			} else {
				sawOdd = YES;
			}
			if (sawEven && sawOdd) {
				break;
			}
		}
		XCTAssertTrue(sawEven, @"no even value in 4096 draws of PBTUniformUInt64(%llu)", max);
		XCTAssertTrue(sawOdd, @"no odd value in 4096 draws of PBTUniformUInt64(%llu)", max);
	}
}

@end
