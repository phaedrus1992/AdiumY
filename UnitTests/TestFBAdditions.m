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
#import "TestFBAdditions.h"
#import "AIUnitTestUtilities.h"

#import <Adium/NSString-FBAdditions.h>

@implementation TestFBAdditions

// RTL script (Arabic) should return RightToLeft
- (void)testBaseWritingDirectionRTL
{
	NSString *str = @"مرحبا"; // "مرحبا" (Arabic)
	STAssertEquals([str baseWritingDirection], NSWritingDirectionRightToLeft, @"Arabic string should be RTL");
}

// LTR script (Latin) should return LeftToRight
- (void)testBaseWritingDirectionLTR
{
	NSString *str = @"Hello, world!";
	STAssertEquals([str baseWritingDirection], NSWritingDirectionLeftToRight, @"Latin string should be LTR");
}

// Empty string should return Natural
- (void)testBaseWritingDirectionEmpty
{
	NSString *str = @"";
	STAssertEquals([str baseWritingDirection], NSWritingDirectionNatural, @"Empty string should be Natural");
}

// Neutral-only characters (spaces, digits, punctuation) should return Natural
- (void)testBaseWritingDirectionNeutral
{
	NSString *str = @"  123 456  ";
	STAssertEquals([str baseWritingDirection], NSWritingDirectionNatural, @"Neutral-only string should be Natural");
}

// Mixed content should resolve to the first strong directional character
- (void)testBaseWritingDirectionMixed
{
	// "abc مرحبا def" — first strong char is RTL Arabic
	NSString *str = @"abc مرحبا def";
	STAssertEquals([str baseWritingDirection], NSWritingDirectionRightToLeft,
				   @"Mixed string with RTL first strong char should be RTL");
}

@end
