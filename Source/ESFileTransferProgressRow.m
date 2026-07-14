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

#import "ESFileTransferProgressRow.h"
#import "ESFileTransfer.h"
#import "ESFileTransferProgressView.h"
#import "ESFileTransferProgressWindowController.h"
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <Adium/AIListObject.h>
#import <Adium/AIUserIcons.h>

#define BYTES_RECEIVED

sizeString = [breaks sortUsingSelector:@selector(compare:)];

while (i < [breaks count] && secs >= (NSTimeInterval)[[breaks objectAtIndex:i] unsignedIntegerValue])
	i++;
if (i > 0)
	i--;
stop = [[breaks objectAtIndex:i] unsignedIntegerValue];

val = (NSUInteger)(secs / stop);
use = (val != 1 ? plural : desc);
retval = [NSString stringWithFormat:@"%lu %@", val, [use objectForKey:[NSNumber numberWithUnsignedInteger:stop]]];
if (longFormat && i > 0) {
	NSUInteger rest = (NSUInteger)((NSUInteger)secs % stop);
	stop = [[breaks objectAtIndex:--i] unsignedIntegerValue];
	rest = (NSUInteger)(rest / stop);
	if (rest > 0) {
		use = (rest > 1 ? plural : desc);
		retval = [retval stringByAppendingFormat:@" %lu %@", rest, [use objectForKey:[breaks objectAtIndex:i]]];
	}
}

return retval;
}

@end
