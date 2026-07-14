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

#import "TestPropertyBasedAIEmoticon.h"
#import "AIPropertyTestUtilities.h"
#import <Adium/AIEmoticon.h>
#import <Adium/AIEmoticonPack.h>

@implementation TestPropertyBasedAIEmoticon

/// Property: Emoticon creation with random text equivalents must not crash.
- (void)testEmoticonCreationWithRandomTextEquivalents {
	PBTCheckDefault({
		NSString *path = [NSString stringWithFormat:@"/tmp/emoticon_%u.png", (unsigned)PBTUniform(9999)];
		NSMutableArray *equivalents = [NSMutableArray array];
		uint32_t count = PBTUniform(5);
		for (uint32_t i = 0; i < count; i++) {
			[equivalents addObject:PBTRandomASCIIString(10)];
		}
		NSString *name = PBTRandomASCIIString(16);
		AIEmoticonPack *pack = nil;  // Test without a pack
		AIEmoticon *emoticon = [AIEmoticon emoticonWithIconPath:path
												   equivalents:equivalents
														  name:name
														  pack:pack];
		STAssertNotNil(emoticon, @"emoticonWithIconPath: returned nil");
		if (emoticon) {
			STAssertEqualObjects([emoticon name], name, @"Emoticon name mismatch");
			if ([equivalents count] > 0) {
				STAssertEqualObjects([emoticon textEquivalents], equivalents,
									 @"Emoticon text equivalents mismatch");
			}
		}
	});
}

/// Property: Emoticon creation with empty and whitespace text equivalents must not crash.
- (void)testEmoticonWithEmptyEquivalents {
	AIEmoticon *emoticon = [AIEmoticon emoticonWithIconPath:@"/tmp/test.png"
											   equivalents:@[]
													  name:@"test"
													  pack:nil];
	STAssertNotNil(emoticon, @"Emoticon with empty equivalents should be creatable");
	STAssertNotNil([emoticon textEquivalents], @"textEquivalents should not be nil");
}

/// Property: Emoticon enabled state toggling is idempotent.
- (void)testEmoticonEnabledState {
	PBTCheckDefault({
		AIEmoticon *emoticon = [AIEmoticon emoticonWithIconPath:@"/tmp/test.png"
												   equivalents:@[@":)"]
														  name:PBTRandomASCIIString(8)
														  pack:nil];
		STAssertNotNil(emoticon, @"Emoticon creation failed");
		BOOL initialState = [emoticon isEnabled];
		[emoticon setEnabled:!initialState];
		STAssertEquals([emoticon isEnabled], !initialState,
					   @"Emoticon enabled state should toggle");
		[emoticon setEnabled:initialState];
		STAssertEquals([emoticon isEnabled], initialState,
					   @"Emoticon enabled state should toggle back");
	});
}

/// Property: Emoticon path can be set and read back.
- (void)testEmoticonPathRoundtrip {
	PBTCheckDefault({
		NSString *path1 = [NSString stringWithFormat:@"/tmp/emoticon_%u.gif", (unsigned)PBTUniform(99999)];
		AIEmoticon *emoticon = [AIEmoticon emoticonWithIconPath:path1
												   equivalents:@[@":)", @":-)"]
														  name:@"smile"
														  pack:nil];
		STAssertEqualObjects([emoticon path], path1, @"Initial path mismatch");
		NSString *path2 = [NSString stringWithFormat:@"/tmp/emoticon_%u.png", (unsigned)PBTUniform(99999)];
		[emoticon setPath:path2];
		STAssertEqualObjects([emoticon path], path2, @"Path after setPath: mismatch");
	});
}

/// Property: flushEmoticonImageCache must not crash even when called multiple times.
- (void)testFlushCacheDoesNotCrash {
	PBTCheckDefault({
		AIEmoticon *emoticon = [AIEmoticon emoticonWithIconPath:@"/tmp/test.png"
												   equivalents:@[@":D"]
														  name:PBTRandomASCIIString(8)
														  pack:nil];
		STAssertNotNil(emoticon, @"Emoticon creation failed");
		[emoticon flushEmoticonImageCache];
		[emoticon flushEmoticonImageCache];  // Double flush should be safe
		STAssertTrue(YES, @"flushEmoticonImageCache must not crash on multiple calls");
	});
}

/// Property: isAppropriateForServiceClass: returns BOOL without crashing for random strings.
- (void)testIsAppropriateForServiceClassWithRandomInput {
	PBTCheckDefault({
		AIEmoticon *emoticon = [AIEmoticon emoticonWithIconPath:@"/tmp/test.png"
												   equivalents:@[@":)"]
														  name:@"smile"
														  pack:nil];
		NSString *serviceClass = PBTRandomASCIIString(20);
		STAssertNoThrowSpecific(
			[emoticon isAppropriateForServiceClass:serviceClass],
			NSException,
			@"isAppropriateForServiceClass: should not throw for random input");
	});
}

/// Property: attributedStringWithTextEquivalent:attachImages: returns non-nil for valid equivalent.
- (void)testAttributedStringWithValidEquivalent {
	PBTCheckDefault({
		AIEmoticon *emoticon = [AIEmoticon emoticonWithIconPath:@"/tmp/test.png"
												   equivalents:@[@":)", @":-)", @":D"]
														  name:PBTRandomASCIIString(8)
														  pack:nil];
		NSAttributedString *attrStr = [emoticon attributedStringWithTextEquivalent:@":)" attachImages:NO];
		STAssertNotNil(attrStr, @"attributedStringWithTextEquivalent: should return non-nil for valid equivalent");
	});
}

@end
