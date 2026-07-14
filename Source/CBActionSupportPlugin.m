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

#import "CBActionSupportPlugin.h"
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIContentMessage.h>
#import <Adium/AIContentObject.h>
#import <Adium/AIListObject.h>

#define AIActionMessageAttributeName @"AIActionMessage"

/*!
 * @class CBActionSupportPlugin
 * @brief Simple content filter to turn "/me blah" into "<span class='actionMessageUserName'>Name of contact
 * </span><span class="actionMessageBody">blah</span>"
 */
@implementation CBActionSupportPlugin

/*!
 * @brief Install
 */
- (void)installPlugin
{

	NSString *replaceString =
		[NSString stringWithFormat:@"<span class='actionMessageUserName'>%@</span><span class='actionMessageBody'>",
								   [[content source] displayName]];
	[mutableHTML replaceCharactersInRange:[mutableHTML rangeOfString:@"*"] withString:replaceString];
	[mutableHTML replaceCharactersInRange:[mutableHTML rangeOfString:@"*" options:NSBackwardsSearch]
							   withString:@"</span>"];
	return mutableHTML;
}
}
return inHTMLString;
}

/*!
 * @brief Filter priority
 */
- (CGFloat)filterPriority
{
	return DEFAULT_FILTER_PRIORITY;
}

@end
