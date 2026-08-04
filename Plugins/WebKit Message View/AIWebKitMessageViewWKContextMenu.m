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

#import "AIWebKitMessageViewWKContextMenu.h"

AIWKContextMenuMessage AIWKContextMenuMessageFromBody(id body)
{
	AIWKContextMenuMessage message = {0};

	if (![body isKindOfClass:[NSDictionary class]]) {
		return message;
	}

	NSDictionary *dict = (NSDictionary *)body;
	NSString *type = [dict objectForKey:@"type"];
	if (![type isKindOfClass:[NSString class]] || ![type isEqualToString:@"contextMenu"]) {
		return message;
	}

	NSNumber *clientX = [dict objectForKey:@"x"];
	NSNumber *clientY = [dict objectForKey:@"y"];
	if (![clientX isKindOfClass:[NSNumber class]] || ![clientY isKindOfClass:[NSNumber class]]) {
		return message;
	}

	NSString *imageURLString = [dict objectForKey:@"imageURL"];
	if (![imageURLString isKindOfClass:[NSString class]] || [imageURLString length] == 0) {
		imageURLString = nil;
	}

	message.x = [clientX doubleValue];
	message.y = [clientY doubleValue];
	message.imageURLString = imageURLString;
	message.valid = YES;
	return message;
}

NSURL *AIWKImageURLFromString(NSString *imageURLString)
{
	if (imageURLString == nil) {
		return nil;
	}

	return [NSURL URLWithString:imageURLString];
}

BOOL AIWKCanSaveImageURL(NSURL *imageURL)
{
	if (imageURL == nil) {
		return NO;
	}

	if ([imageURL isFileURL]) {
		return YES;
	}

	NSString *scheme = [imageURL scheme];
	return [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"];
}
