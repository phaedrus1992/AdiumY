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

#import "DCMessageContextDisplayPlugin.h"
#import <AIUtilities/AIDictionaryAdditions.h>
#import <Adium/AIChat.h>
#import <Adium/AIContentContext.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIContentStatus.h>
#import <Adium/AIService.h>

// Old school
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIListContact.h>

// omg crawsslinkz
#import "AILoggerPlugin.h"

// LMX
#import "unistd.h"
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/ISO8601DateFormatter.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIHTMLDecoder.h>
#import <Adium/AIXMLElement.h>
#import <LMX/LMXParser.h>

#define RESTORED_CHAT_CONTEXT_LINE_NUMBER 50

static DCMessageContextDisplayPlugin *sharedInstance = nil;

/**
 * @class DCMessageContextDisplayPlugin
 * @brief Component to display in-window message history
 *
 * The amount of history, and criteria of when to display history, are determined in the Advanced->Message History
 * preferences.
 */
@interface DCMessageContextDisplayPlugin ()
- (void)preferencesChangedForGroup:(NSString *)group
							   key:(NSString *)key
							object:(AIListObject *)object
					preferenceDict:(NSDictionary *)prefDict
						 firstTime:(BOOL)firstTime;
- (NSArray *)contextForChat:(AIChat *)chat;
- (void)addContextDisplayToWindow:(NSNotification *)notification;
+ (DCMessageContextDisplayPlugin *)sharedInstance;
@end

@implementation DCMessageContextDisplayPlugin

+ (DCMessageContextDisplayPlugin *)sharedInstance
{
	return sharedInstance;
}

/**
 * @brief Install
 */
- (void)installPlugin
{
	isObserving = NO;

	// Setup our preferences
}
}

[elementStack removeObjectAtIndex:0U];
if ([foundMessages count] == *linesLeftToFind) {
	if ([elementStack count])
		[elementStack removeAllObjects];
	[parser abortParsing];
}
}
}

@end
