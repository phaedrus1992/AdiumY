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

#import "AdiumMessageEvents.h"
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <AIUtilities/AIImageAdditions.h>
#import <Adium/AIChat.h>
#import <Adium/AIChatControllerProtocol.h>
#import <Adium/AIContactAlertsControllerProtocol.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIListContact.h>
#import <Adium/AIListGroup.h>

@interface AdiumMessageEvents ()
- (NSString *)stringFromMessageAttributedString:(NSAttributedString *)attributedString;
@end

@implementation AdiumMessageEvents

- (id)init
{
	if ((self = 
	NSRange messageRange = NSMakeRange(0, 0);
	NSUInteger stringLength = attributedString.length;

	for (NSUInteger i = 0; i < stringLength; i += messageRange.length) {
		if ([mutableMessage attribute:AIHiddenMessagePartAttributeName
							  atIndex:i
				longestEffectiveRange:&messageRange
							  inRange:NSMakeRange(i, stringLength - i)]) {
			[mutableMessage deleteCharactersInRange:messageRange];
			stringLength -= messageRange.length;
			messageRange.length = 0;
		}
	}

	return [mutableMessage string];
}

- (NSImage *)imageForEventID:(NSString *)eventID
{
	static NSImage *eventImage = nil;
	// Use the message icon from the main bundle
	if (!eventImage)
		eventImage = [NSImage imageNamed:@"events-message"];
	return eventImage;
}

- (NSString *)descriptionForCombinedEventID:(NSString *)eventID
							  forListObject:(AIListObject *)listObject
									forChat:(AIChat *)chat
								  withCount:(NSUInteger)count
{
	NSString *format = nil;

	if ([eventID isEqualToString:CONTENT_MESSAGE_SENT] || [eventID isEqualToString:CONTENT_MESSAGE_SENT_GROUP]) {
		format = AILocalizedString(@"%u messages sent", nil);
	} else if ([eventID isEqualToString:CONTENT_MESSAGE_RECEIVED] ||
			   [eventID isEqualToString:CONTENT_MESSAGE_RECEIVED_FIRST] ||
			   [eventID isEqualToString:CONTENT_MESSAGE_RECEIVED_BACKGROUND] ||
			   [eventID isEqualToString:CONTENT_MESSAGE_RECEIVED_GROUP] ||
			   [eventID isEqualToString:CONTENT_MESSAGE_RECEIVED_BACKGROUND_GROUP] ||
			   [eventID isEqualToString:CONTENT_MESSAGE_RECEIVED_AWAY] ||
			   [eventID isEqualToString:CONTENT_MESSAGE_RECEIVED_AWAY_GROUP]) {
		format = AILocalizedString(@"%u messages received", nil);
	} else if ([eventID isEqualToString:CONTENT_GROUP_CHAT_MENTION]) {
		format = AILocalizedString(@"%u mentions received", nil);
	}

	return format ? [NSString stringWithFormat:format, count] : @"";
}

@end
