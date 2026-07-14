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

#import "AIXMLChatlogConverter.h"
#import "AIStandardListWindowController.h"
#import <AIUtilities/AIDateFormatterAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/ISO8601DateFormatter.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIHTMLDecoder.h>
#import <Adium/AIListContact.h>
#import <Adium/AIService.h>
#import <Adium/AIStatusControllerProtocol.h>

#define PREF_GROUP_WEBKIT_MESSAGE_DISPLAY @"WebKit Message Display"
#define KEY_WEBKIT_USE_NAME_FORMAT @"Use Custom Name Format"
#define KEY_WEBKIT_NAME_FORMAT @"Name Format"

@interface NSMutableString (XMLMethods)
- (void)stripInvalidCharacters;
@end

@implementation NSMutableString (XMLMethods)

// Strip invalid XML characters
- (void)stripInvalidCharacters
{
	static NSCharacterSet *invalidXMLCharacterSet;

	if (invalidXMLCharacterSet == nil) {
		// First, create a character set containing all valid UTF8 characters.
		NSMutableCharacterSet *xmlCharacterSet =
	}
}

return output;

ohno : if (!reentrancyFlag)
{
	NSMutableString *xmlString = [NSMutableString stringWithUTF8String:[xmlData bytes]];
	[xmlString stripInvalidCharacters];
	return [self readData:[xmlString dataUsingEncoding:NSUTF8StringEncoding] withOptions:options retrying:YES];
}
@throw [NSException exceptionWithName:@"Log File Parsing Error" reason:[err description] userInfo:nil];
}

@end
