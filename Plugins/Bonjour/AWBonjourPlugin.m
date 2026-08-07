/*
 * Project:     Adium Rendezvous Plugin
 * File:        AWRendezvousPlugin.m
 * Author:      Andrew Wellington <proton[at]wiretapped.net>
 *
 * License:
 * Copyright (C) 2004-2005 Andrew Wellington.
 * All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

// clang-format off
// Import order is load-bearing for the standalone test target (no prefix header):
// AIPlugin must precede AWBonjourPlugin.h, whose interface inherits from it.
// clang-format would sort the quoted own-header first.
#import <AdiumY/AIPlugin.h>
#import "AWBonjourPlugin.h"
// clang-format on

#import "AWBonjourAccount.h"
#import "AWBonjourService.h"

@implementation AWBonjourPlugin

- (void)installPlugin
{
	service = [AWBonjourService registerService];
}

// Uninstall
- (void)uninstallPlugin
{
	// Unregister the service installPlugin registered, so an unloaded plugin leaves no Bonjour service registered
	// (#235). Nil-safe: a second uninstall, after the ivar is already nil, is a no-op.
	if (service != nil) {
		[service unregisterService];
		service = nil;
	}
}

@end
