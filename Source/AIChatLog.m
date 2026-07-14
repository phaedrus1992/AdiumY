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

#import "AIChatLog.h"
#import "AILogViewerWindowController.h"
#import "AILoggerPlugin.h"
#import "AILoginController.h"

#import <AIUtilities/ISO8601DateFormatter.h>

@implementation AIChatLog

- (id)initWithPath:(NSString *)inPath
			  from:(NSString *)inFrom
				to:(NSString *)inTo
	  serviceClass:(NSString *)inServiceClass
{
	if ((self =
}
}
}

return date;
}
- (void)parser:(NSXMLParser *)parser
	didStartElement:(NSString *)elementName
	   namespaceURI:(NSString *)namespaceURI
	  qualifiedName:(NSString *)qualifiedName
		 attributes:(NSDictionary *)attributeDict
{
	// Stop at the first element with a date.
	NSString *dateString = nil;
	if ((dateString = 
	formatter.timeSeparator = '.';
	NSRange openParenRange, closeParenRange;

	if ((openParenRange = [fileName rangeOfString:@"(" options:NSBackwardsSearch]).location != NSNotFound) {
		openParenRange = NSMakeRange(openParenRange.location, [fileName length] - openParenRange.location);
		if ((closeParenRange = [fileName rangeOfString:@")" options:0 range:openParenRange]).location != NSNotFound) {
			// Add and subtract one to remove the parenthesis
			NSString *dateString =
				[fileName substringWithRange:NSMakeRange(openParenRange.location + 1,
														 (closeParenRange.location - openParenRange.location))];
			// Fix really old chatlogs which use "(2005|05|07)".
			return [formatter dateFromString:[dateString stringByReplacingOccurrencesOfString:@"|" withString:@"-"]];
		}
	}
	return nil;
}

@end
