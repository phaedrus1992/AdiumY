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

#import "AIExceptionController.h"
#import "AICrashReporter.h"
#import <AIUtilities/AIFileManagerAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <ExceptionHandling/NSExceptionHandler.h>
#include <unistd.h>

/*!
 * @class AIExceptionController
 * @brief Catches application exceptions and forwards them to the crash reporter application
 *
 * Once configured, sets itself as the NSExceptionHandler delegate to decode the stack traces
 * generated via NSExceptionHandler, write them to a file, and launch the crash reporter.
 */
@implementation AIExceptionController

// Enable exception catching for the crash reporter
static BOOL catchExceptions = NO;

// These exceptions can be safely ignored.
static NSSet *safeExceptionReasons = nil, *safeExceptionNames = nil;

+ (void)enableExceptionCatching
{
	// Log and Handle all exceptions
	NSExceptionHandler *exceptionHandler =
		// Clear out a useless string inserted into some stack traces as of 10.4 to improve crashlog readability
		[processedStackTrace
			replaceOccurrencesOfString:@"task_start_peeking: can't suspend failed  (ipc/send) invalid destination port"
							withString:@""
							   options:NSLiteralSearch
								 range:NSMakeRange(0, [processedStackTrace length])];

	return processedStackTrace;
}

// If we are unable to decode the stack trace, return the best we have
return stackTrace;
}

@end
