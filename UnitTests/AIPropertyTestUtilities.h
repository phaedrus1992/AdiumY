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

#import <Foundation/Foundation.h>

/// Lightweight property-based testing utilities for ObjC.
///
/// Generators produce random values seeded by a 64-bit integer. On failure the seed is
/// logged so the exact case can be reproduced (override PBTFixedSeed in the test method to
/// lock the seed while debugging).

// MARK: - Seed management

/// Set this before PBTCheck/PBTCheckN to lock the seed for deterministic reproduction.
extern int64_t PBTFixedSeed;

/// The seed used by the current iteration. Valid inside a PBTCheck/PBTCheckN block.
extern int64_t PBTCurrentSeed;

/// Logs the failing seed to stderr so it can be reproduced.
void PBTLogSeed(int64_t seed);

// MARK: - Property check macros

/// Run `block` for `count` iterations. Each iteration gets a unique seed derived from
/// the base seed + iteration index. If any iteration fails (STFail/STAssert failure),
/// the seed is logged and remaining iterations are skipped.
#define PBTCheck(block, count) \
	do { \
		int64_t _pbtBaseSeed = (PBTFixedSeed != 0) ? PBTFixedSeed : (int64_t)[[NSDate date] timeIntervalSinceReferenceDate]; \
		BOOL _pbtFailed = NO; \
		for (uint32_t _pbtIter = 0; _pbtIter < (uint32_t)(count); _pbtIter++) { \
			PBTCurrentSeed = _pbtBaseSeed + _pbtIter; \
			srandom((unsigned int)(PBTCurrentSeed ^ (PBTCurrentSeed >> 32))); \
			@try { block; } \
			@catch (NSException *_pbtE) { \
				PBTLogSeed(PBTCurrentSeed); \
				STFail(@"Property failed at iteration %u: %@", _pbtIter, [_pbtE reason]); \
				_pbtFailed = YES; \
				break; \
			} \
			if (_pbtFailed) break; \
		} \
	} while (0)

/// Convenience: run `block` with 100 iterations.
#define PBTCheckDefault(block) PBTCheck(block, 100)

// MARK: - String generators

/// Returns a random ASCII string of length 0..maxLen.
NSString *PBTRandomASCIIString(uint32_t maxLen);

/// Returns a random Unicode string (including multi-byte, combining marks, etc.) of
/// length 0..maxLen.
NSString *PBTRandomUnicodeString(uint32_t maxLen);

/// Returns a random string containing only whitespace and newlines of length 0..maxLen.
NSString *PBTRandomWhitespaceString(uint32_t maxLen);

/// Returns a random HTML fragment (opening/closing tags, plain text, entities).
NSString *PBTRandomHTMLFragment(uint32_t maxLen);

// MARK: - Attributed string generators

/// Returns an NSAttributedString with random text and random attributes applied to each
/// character run. Attributes include font, color, underline, strikethrough, and link.
NSAttributedString *PBTRandomAttributedString(uint32_t maxLen);

/// Returns an NSAttributedString with no attributes (plain text).
NSAttributedString *PBTRandomPlainAttributedString(uint32_t maxLen);

// MARK: - Number generators

/// Returns a random NSUInteger in [0, max).
NSUInteger PBTUniform(uint32_t max);

/// Returns a random BOOL.
BOOL PBTRandomBool(void);

// MARK: - Dictionary generators

/// Returns a dictionary with 0..n random string keys and values. Suitable for simulating
/// AIStatus statusDict content.
NSDictionary *PBTRandomStringDictionary(uint32_t maxPairs);

/// Returns a dictionary with random keys from `keyPool` and random values (strings or
/// numbers, matching the key). Simulates the kind of dictionary AIStatus uses.
NSDictionary *PBTRandomStatusDictionary(void);

// MARK: - Shrinking helper

/// Given a seed that produced a failure, try simpler seeds nearby to find a minimal
/// repro. Returns the seed of the first simpler seed that also fails, or the original
/// seed if none found. Does NOT assert — returns the candidate.
int64_t PBTShrinkSeed(int64_t failingSeed, BOOL (^testBlock)(int64_t seed));
