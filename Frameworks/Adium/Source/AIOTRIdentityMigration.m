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

#import "AIOTRIdentityMigration.h"

@implementation AIOTRIdentityMigration

@synthesize legacyAccountName, currentAccountName, legacyProtocol, currentProtocol;

- (instancetype)initWithLegacyAccountName:(NSString *)inLegacyAccountName
					   currentAccountName:(NSString *)inCurrentAccountName
						   legacyProtocol:(NSString *)inLegacyProtocol
						  currentProtocol:(NSString *)inCurrentProtocol
{
	if ((self = [super init])) {
		legacyAccountName = [inLegacyAccountName copy];
		currentAccountName = [inCurrentAccountName copy];
		legacyProtocol = [inLegacyProtocol copy];
		currentProtocol = [inCurrentProtocol copy];
	}

	return self;
}

@end

static NSString *MigratedFingerprintStoreLine(NSString *line, NSArray<AIOTRIdentityMigration *> *migrations,
											  NSUInteger *changedLineCount)
{
	NSArray<NSString *> *fields = [line componentsSeparatedByString:@"\t"];
	if ([fields count] < 4) {
		return line;
	}

	for (AIOTRIdentityMigration *migration in migrations) {
		if (![fields[1] isEqualToString:migration.legacyAccountName]) {
			continue;
		}

		NSMutableArray<NSString *> *rewritten = [fields mutableCopy];
		rewritten[1] = migration.currentAccountName;
		if ([fields[2] isEqualToString:migration.legacyProtocol]) {
			rewritten[2] = migration.currentProtocol;
		}

		(*changedLineCount)++;
		return [rewritten componentsJoinedByString:@"\t"];
	}

	return line;
}

NSString *AIOTRMigratedFingerprintStoreText(NSString *storeText, NSArray<AIOTRIdentityMigration *> *migrations,
											NSUInteger *changedLineCount)
{
	NSUInteger changed = 0;
	NSMutableArray<NSString *> *rewrittenLines = [NSMutableArray array];

	for (NSString *line in [storeText componentsSeparatedByString:@"\n"]) {
		[rewrittenLines addObject:MigratedFingerprintStoreLine(line, migrations, &changed)];
	}

	if (changedLineCount != NULL) {
		*changedLineCount = changed;
	}

	return [rewrittenLines componentsJoinedByString:@"\n"];
}
