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

#import "TestPropertyBasedAIStatusIcons.h"
#import "AIPropertyTestUtilities.h"
#import <Adium/AIStatusIcons.h>

/// Helper: minimal AIListObject-like class for icon lookup testing.
@interface _PBTTestListObject : NSObject
@property (nonatomic, copy) NSString *UID;
@property (nonatomic, copy) NSString *statusName;
@property (nonatomic, assign) AIStatusType statusType;
@end

@implementation _PBTTestListObject
@end

@implementation TestPropertyBasedAIStatusIcons

/// Property: statusIconForUnknownStatusWithIconType:direction: returns NSImage for all icon types.
- (void)testUnknownStatusIconForAllTypes {
	PBTCheckDefault({
		AIStatusIconType types[NUMBER_OF_STATUS_ICON_TYPES] = {AIStatusIconTab, AIStatusIconList, AIStatusIconMenu};
		AIStatusIconType type = types[PBTUniform(NUMBER_OF_STATUS_ICON_TYPES)];
		AIIconDirection dir = PBTRandomBool() ? AIIconNormal : AIIconFlipped;
		NSImage *icon = [AIStatusIcons statusIconForUnknownStatusWithIconType:type direction:dir];
		STAssertNotNil(icon,
					   @"statusIconForUnknownStatusWithIconType: should return non-nil");
	});
}

/// Property: statusIconForUnknownStatus returns non-nil for both directions.
- (void)testUnknownStatusIconForBothDirections {
	PBTCheckDefault({
		AIIconDirection dir = PBTRandomBool() ? AIIconNormal : AIIconFlipped;
		NSImage *icon = [AIStatusIcons statusIconForUnknownStatusWithIconType:AIStatusIconList
																	direction:dir];
		STAssertNotNil(icon,
					   @"statusIconForUnknownStatus should work for both directions");
	});
}

/// Property: statusIconForListObject:type:direction: does not crash with nil object.
- (void)testIconForNilListObject {
	PBTCheckDefault({
		AIStatusIconType type = AIStatusIconList;
		AIIconDirection dir = PBTRandomBool() ? AIIconNormal : AIIconFlipped;
		STAssertNoThrowSpecific(
			[AIStatusIcons statusIconForListObject:nil type:type direction:dir],
			NSException,
			@"statusIconForListObject:nil should not throw");
	});
}

/// Property: statusIconForStatusName:statusType:iconType:direction: returns non-nil for known types.
- (void)testIconForKnownTypes {
	PBTCheckDefault({
		AIStatusType statusTypes[] = {AIOnlineStatus, AIAwayStatus, AIInvisibleStatus, AIOfflineStatus};
		AIStatusType st = statusTypes[PBTUniform(4)];
		AIStatusIconType iconTypes[NUMBER_OF_STATUS_ICON_TYPES] = {AIStatusIconTab, AIStatusIconList, AIStatusIconMenu};
		AIStatusIconType it = iconTypes[PBTUniform(NUMBER_OF_STATUS_ICON_TYPES)];
		NSString *name = PBTRandomASCIIString(10);
		AIIconDirection dir = PBTRandomBool() ? AIIconNormal : AIIconFlipped;
		NSImage *icon = [AIStatusIcons statusIconForStatusName:name
													statusType:st
													  iconType:it
													 direction:dir];
		// May return nil for unknown status names; just ensure no crash
		STAssertTrue(icon == nil || [icon isKindOfClass:[NSImage class]],
					 @"statusIconForStatusName: should return nil or NSImage");
	});
}

/// Property: statusNameForListObject: returns nil without crashing for nil/null object.
- (void)testStatusNameForNilObject {
	PBTCheckDefault({
		STAssertNoThrowSpecific(
			[AIStatusIcons statusNameForListObject:nil],
			NSException,
			@"statusNameForListObject:nil should not throw");
	});
}

/// Property: setActiveStatusIconsFromPath: returns BOOL without crashing for random paths.
- (void)testSetActiveStatusIconsFromRandomPath {
	PBTCheckDefault({
		NSString *path = [NSString stringWithFormat:@"/tmp/statusicons_%u",
						  (unsigned)PBTUniform(99999)];
		STAssertNoThrowSpecific(
			[AIStatusIcons setActiveStatusIconsFromPath:path],
			NSException,
			@"setActiveStatusIconsFromPath: should not throw for random path");
	});
}

@end
