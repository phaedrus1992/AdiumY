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

#import "AdiumOTREncryption.h"
#import "AIHTMLDecoder.h"
#import <Adium/AIAccount.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIChat.h>
#import <Adium/AIChatControllerProtocol.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIContentMessage.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIListContact.h>
#import <Adium/AIListObject.h>
#import <Adium/AILoginControllerProtocol.h>
#import <Adium/AIService.h>

#import <AIUtilities/AIStringAdditions.h>

#import "ESOTRPreferences.h"
#import "ESOTRPrivateKeyGenerationWindowController.h"
#import "ESOTRUnknownFingerprintController.h"
#import "OTRCommon.h"

#import <stdlib.h>

#define PRIVKEY_PATH

[adium.preferenceController setPreference:[NSNumber numberWithBool:YES]
								   forKey:@"Libgaim_to_Libpurple_Update"
									group:@"OTR"];
}
}

@end
