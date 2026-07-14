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
#import "ESDebugController.h"
#import "ESDebugWindowController.h"

#import <AIUtilities/AIMenuAdditions.h>
#import <Adium/AIMenuControllerProtocol.h>

#import <errno.h>  //errno
#import <fcntl.h>  //open(2)
#import <string.h> //strerror(3)
#import <unistd.h> //close(2)

#import <objc/objc-runtime.h>

#import <ExceptionHandling/NSExceptionHandler.h>

#define CACHED_DEBUG_LOGS 100 // Number of logs to keep at any given time
#define KEY_DEBUG_WINDOW_OPEN @"Debug Window Open"

@interface ESDebugController ()
- (void)start:(NSNotification *)dummy;
- (void)showDebugWindow:(id)sender;
@end

@implementation ESDebugController

// Throwing an exception isn't enough, we need to die completely.
void AIExplodeOnEnumerationMutation(id dummy)
{
	NSLog(@"Attempted to mutate collection %@ of class %@ while enumerating", dummy, 
			debugLogFile = nil;
}
}
}

- (NSArray *)debugLogArray
{
	return debugLogArray;
}
- (void)clearDebugLogArray
{
	[debugLogArray removeAllObjects];
}

- (NSFileHandle *)debugLogFile
{
	if (!debugLogFile) {
		NSFileManager *mgr = [NSFileManager defaultManager];
		NSDate *date = [NSDate date];
		NSString *folder, *dateString, *filename, *pathname;
		NSUInteger counter = 0;
		int fd;

		// make sure the containing folder for debug logs exists.
		folder = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, /*expandTilde*/ YES)
			objectAtIndex:0];
		folder = [folder stringByAppendingPathComponent:@"Logs"];
		folder = [folder stringByAppendingPathComponent:@"Adium Debug"];
		BOOL success = [mgr createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
		if ((!success) && (errno != EEXIST)) {
			/*raise an exception if the folder could not be created,
			 *	but not if that was because it already exists.
			 */
			NSAssert2(success, @"Could not create folder %@: %s", folder, strerror(errno));
		}

		/*get today's date, for the filename.
		 *the date is in YYYY-MM-DD format. duplicates are disambiguated with
		 *' 1', ' 2', ' 3', etc. appendages.
		 */
		filename = dateString = [date descriptionWithCalendarFormat:@"%Y-%m-%d" timeZone:nil locale:nil];
		while ([mgr
			fileExistsAtPath:(pathname = [folder
								  stringByAppendingPathComponent:[filename stringByAppendingPathExtension:@"log"]])]) {
			filename = [dateString stringByAppendingFormat:@" %lu", ++counter];
		}

		// create (if necessary) and open the file as writable, in append mode.
		fd = open([pathname fileSystemRepresentation], O_CREAT | O_WRONLY | O_APPEND, 0644);
		NSAssert2(fd > -1, @"could not create %@ nor open it for writing: %s", pathname, strerror(errno));

		// note: the file handle takes ownership of fd.
		/*
		 * From the docs:  "The object creating an NSFileHandle using this method owns fileDescriptor and is responsible
		 * for its disposition." which seems to indicate that the file handle does not take ownership of fd. Just for
		 * the record. -eds
		 */
		debugLogFile = [[NSFileHandle alloc] initWithFileDescriptor:fd];
		if (!debugLogFile)
			close(fd);
		NSAssert1(debugLogFile != nil, @"could not create file handle for %@", pathname);

		// write header (separates this session from previous sessions).
		[debugLogFile writeData:[[NSString stringWithFormat:@"Opened debug log at %@\n", date]
									dataUsingEncoding:NSUTF8StringEncoding]];
	}

	return debugLogFile;
}

@end
