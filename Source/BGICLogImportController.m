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

#import "BGICLogImportController.h"
#import "AICoreComponentLoader.h"
#import "AILoggerPlugin.h"
#import "AIXMLAppender.h"
#import <AIUtilities/AIFileManagerAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/ISO8601DateFormatter.h>
#import <Adium/AIHTMLDecoder.h>
#import <Adium/AILoginControllerProtocol.h>
#import <Adium/AIXMLElement.h>

// InstantMessage and other iChat transcript classes are from Spiny Software's Logorrhea, used with permission.
#import "InstantMessage.h"
#import "Presentity.h"

// #define LOG_TO_TEST
#define TEST_LOGGING_LOCATION

[elm addEscapedObject:chatContents];

if ([attributeValues count] == 2) {
	[elm setAttributeNames:attributeKeys values:attributeValues];
}

[appender appendElement:elm];
}

if ([[NSFileManager defaultManager] fileExistsAtPath:documentPath]) {
	[(AILoggerPlugin *)[[adium componentLoader] pluginWithClassName:@"AILoggerPlugin"] markLogDirtyAtPath:documentPath];
	return YES;

} else {
	return NO;
}
}

@end
