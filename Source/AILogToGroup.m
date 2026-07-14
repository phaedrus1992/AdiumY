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

#import "AILogToGroup.h"
#import "AIChatLog.h"
#import "AILogViewerWindowController.h"
#import "AILoggerPlugin.h"
#import <AIUtilities/AIFileManagerAdditions.h>

@interface AILogToGroup ()
- (NSDictionary *)logDict;
@end

@implementation AILogToGroup

// A group of logs to an specific user
- (id)initWithPath:(NSString *)inPath
			  from:(NSString *)inFrom
				to:(NSString *)inTo
	  serviceClass:(NSString *)inServiceClass
{
	if ((self =
}

if (!theLog)
	AILog(@"%@ couldn't find %@ in its partialLogDict", self, inPath);
}
}
return theLog;
}

/*!
 * @brief Trash an AIChatLog within this AILogToGroup
 *
 * @param aLog The AIChatLog to move to the trash
 *
 * @result YES if the AIChatLog was successfully trashed
 */
- (BOOL)trashLog:(AIChatLog *)aLog
{
	NSString *logPath = [[AILoggerPlugin logBasePath] stringByAppendingPathComponent:[aLog relativePath]];
	BOOL success;
	success = [[NSFileManager defaultManager] trashFileAtPath:logPath];

	// Remove from our dictionaries so we don't reference the removed log
	[logDict removeObjectForKey:[aLog relativePath]];
	[partialLogDict removeObjectForKey:[aLog relativePath]];

	return success;
}

/*!
 * @brief Partial isEqual implementation
 *
 * 'Partial' in the sense that it doesn't actually test equality.  If two AILogToGroup objects are for the same
 * service/contact pair, they are considered equal by this function.  They may (and probably do) have different source
 * accounts and therefore different contained logs.
 *
 * This is useful because all To groups for a service/contact pair are presented as a single To group in the Contacts
 * source list.
 */
- (BOOL)isEqual:(id)inObject
{
	return ([inObject isMemberOfClass:[self class]] &&
			([[(AILogToGroup *)inObject to] isEqualToString:[self to]] &&
			 [[(AILogToGroup *)inObject serviceClass] isEqualToString:[self serviceClass]]));
}
- (NSUInteger)hash
{
	return [[self to] hash];
}
@end
