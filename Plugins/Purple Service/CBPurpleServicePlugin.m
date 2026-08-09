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

// clang-format off
// Import order is load-bearing for the standalone test target (no prefix header):
// AIPlugin must precede CBPurpleServicePlugin.h and the AIIRCServicesPasswordPlugin.h /
// AIAnnoyingIRCMessagesHiderPlugin.h headers, whose interfaces inherit from it. clang-format
// would sort the quoted own-headers first.
#import <AdiumY/AIPlugin.h>
#import "CBPurpleServicePlugin.h"
#import "AIAnnoyingIRCMessagesHiderPlugin.h"
#import "AIIRCServicesPasswordPlugin.h"
// clang-format on
#import "AMPurpleTuneTooltip.h"
#import "PurpleServices.h"
// The standalone test target has no Adium.pch, which provides AIAccount.h and
// AIPreferenceControllerProtocol.h app-wide; import them before SLPurpleCocoaAdapter.h (whose
// interface references AIAccount) and before registerDefaults:forGroup: is used below.
#import <AdiumY/AIAccount.h>
// clang-format off
#import <AdiumY/AIPreferenceControllerProtocol.h>
// clang-format on
#import "SLPurpleCocoaAdapter.h"
#import <AIUtilities/AIDictionaryAdditions.h>
#import <AdiumYLibpurple/SLPurpleCocoaAdapter.h>

@implementation CBPurpleServicePlugin

#pragma mark Plugin Installation
//  Plugin Installation ------------------------------------------------------------------------------------------------

#define PURPLE_DEFAULTS @"PurpleServiceDefaults"

- (void)installPlugin
{
	// Register our defaults
	[adium.preferenceController registerDefaults:[NSDictionary dictionaryNamed:PURPLE_DEFAULTS forClass:[self class]]
										forGroup:GROUP_ACCOUNT_STATUS];

	// Install the services; keep the instances so uninstallPlugin can unregister them (#241).
	ircService = [ESIRCService registerService];
	simpleService = [ESSimpleService registerService];
	jabberService = [ESJabberService registerService];

	[SLPurpleCocoaAdapter pluginDidLoad];

	// tooltip for tunes
	tunetooltip = [[AMPurpleTuneTooltip alloc] init];
	[adium.interfaceController registerContactListTooltipEntry:tunetooltip secondaryEntry:YES];

	ircPasswordPlugin = [[AIIRCServicesPasswordPlugin alloc] init];
	[ircPasswordPlugin installPlugin];

	messageHiderPlugin = [[AIAnnoyingIRCMessagesHiderPlugin alloc] init];
	[messageHiderPlugin installPlugin];
}

- (void)uninstallPlugin
{
	[adium.interfaceController unregisterContactListTooltipEntry:tunetooltip secondaryEntry:YES];
	tunetooltip = nil;

	[ircPasswordPlugin uninstallPlugin];

	[messageHiderPlugin uninstallPlugin];

	// Unregister the services we registered at install, or they stay in the account/status registries (#241).
	[ircService unregisterService];
	[simpleService unregisterService];
	[jabberService unregisterService];
}

@end
